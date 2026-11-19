extends Node3D
class_name NathanCombatCamera
## Third-person framing with world collision and a continuous paired-action shot.

@export var subject: Node3D
@export var distance := 4.8
@export var shoulder := 0.42
@export var follow_height := 1.48
@export var sensitivity := 0.0032
@export var reduced_motion := false

var camera: Camera3D
var yaw := 0.0
var pitch := 0.15
var _dragging := false
var _pivot := Vector3.ZERO
var _initialized := false
var _pair_target: Node3D
var _pair_weight := 0.0
var _pair_requested := false
var _impact := 0.0
var _time := 0.0
var _running := false
var _exclusions: Array[RID] = []


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 57.0
	camera.near = 0.08
	camera.far = 850.0
	add_child(camera)
	camera.current = true
	if subject != null:
		set_subject(subject)


func set_subject(actor: Node3D) -> void:
	subject = actor
	_initialized = false
	_exclusions.clear()
	if actor is CollisionObject3D:
		_exclusions.append((actor as CollisionObject3D).get_rid())


func set_running(value: bool) -> void:
	_running = value


func begin_pair(other: Node3D) -> void:
	_pair_target = other
	_pair_requested = true
	if other is CollisionObject3D:
		var rid := (other as CollisionObject3D).get_rid()
		if not _exclusions.has(rid):
			_exclusions.append(rid)


func end_pair() -> void:
	_pair_requested = false


func add_impact(strength: float) -> void:
	if not reduced_motion:
		_impact = minf(0.11, _impact + strength)


func rotate_view(delta: Vector2) -> void:
	yaw -= delta.x * sensitivity
	pitch = clampf(pitch + delta.y * sensitivity, -0.22, 0.72)


func view_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func view_right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		rotate_view(event.relative)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(subject):
		return
	_time += delta
	var blend := 1.0 - exp(-delta * 8.0)
	var paired := _pair_requested and is_instance_valid(_pair_target)
	_pair_weight = lerpf(_pair_weight, 1.0 if paired else 0.0, blend)
	var wanted_pivot := subject.global_position + Vector3.UP * follow_height
	var first_frame := not _initialized
	if is_instance_valid(_pair_target) and _pair_weight > 0.001:
		var middle := (subject.global_position + _pair_target.global_position) * 0.5
		wanted_pivot = wanted_pivot.lerp(middle + Vector3.UP * 1.1, _pair_weight)
	if not _initialized:
		_pivot = wanted_pivot
		_initialized = true
	else:
		_pivot = _pivot.lerp(wanted_pivot, 1.0 - exp(-delta * 11.0))
	var radius := lerpf(distance, 5.3, _pair_weight)
	var orbit := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var wanted_position := _pivot + orbit * radius + view_right() * shoulder
	var query := PhysicsRayQueryParameters3D.create(_pivot, wanted_position, 1, _exclusions)
	query.hit_from_inside = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		wanted_position = hit.position + hit.normal * 0.22
	# Collision shortening is immediate; widening is damped to avoid wall oscillation.
	if first_frame or camera.global_position.distance_to(_pivot) > wanted_position.distance_to(_pivot):
		camera.global_position = wanted_position
	else:
		camera.global_position = camera.global_position.lerp(wanted_position, 1.0 - exp(-delta * 14.0))
	camera.look_at(_pivot, Vector3.UP)
	var target_fov := 61.0 if _running and not reduced_motion else 57.0
	camera.fov = lerpf(camera.fov, target_fov, blend)
	if _impact > 0.001:
		camera.position += camera.basis.x * sin(_time * 83.0) * _impact
		camera.position += camera.basis.y * cos(_time * 71.0) * _impact * 0.5
		_impact = move_toward(_impact, 0.0, delta * 0.6)
