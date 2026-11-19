extends SceneTree
## Headless physics tests; invisible collision fixtures are not character assets.
const Actor = preload("res://scripts/character_controller.gd")
var arena: Node3D
var failures: int = 0
var checks: int = 0

class Station extends Node3D:
	var break_count: int = 0
	func break_station() -> void:
		break_count += 1


func _initialize() -> void:
	_run.call_deferred()


func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAILED: " + message)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame


func _reset() -> void:
	if is_instance_valid(arena):
		arena.queue_free()
		await _frames(2)
	arena = Node3D.new()
	root.add_child(arena)
	_box(Vector3(0.0, -0.1, 0.0), Vector3(50.0, 0.2, 50.0))
	await _frames(2)


func _box(position: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	arena.add_child(body)
	return body


func _actor(position: Vector3, team: int = 0) -> NathanCharacterController:
	var actor := Actor.new()
	actor.position = position
	actor.team = team
	arena.add_child(actor)
	return actor


func _run() -> void:
	await _reset()
	var a: NathanCharacterController = _actor(Vector3.ZERO)
	var b: NathanCharacterController = _actor(Vector3(0.0, 0.0, 1.2), 1)
	await _frames(6)
	_check(a.is_on_floor(), "Actor stands on actual physics floor")
	_check(a.request_action(&"punch"), "Punch starts")
	await _frames(40)
	_check(is_equal_approx(b.health, 143.0), "Single punch damages only once")
	await _frames(20)
	b.global_position = Vector3(0.0, 0.0, 5.0)
	a.request_action(&"kick")
	await _frames(50)
	_check(is_equal_approx(b.health, 143.0), "Out-of-range kick misses")
	a.set_move_input(Vector2(1.0, 1.0))
	var start: Vector3 = a.global_position
	await _frames(60)
	_check(a.global_position.distance_to(start) < 5.1, "Diagonal input cannot exceed run speed")
	_check(a.global_position.z < start.z - 2.5, "Positive input Y moves camera-forward negative Z")

	await _reset()
	a = _actor(Vector3.ZERO)
	b = _actor(Vector3(0.0, 0.0, 1.2), 1)
	b.rotation.y = PI
	await _frames(6)
	b.request_action(&"counter")
	a.request_action(&"punch")
	await _frames(35)
	_check(is_equal_approx(b.health, 160.0), "Timed counter prevents incoming damage")
	_check(is_equal_approx(a.health, 136.0), "Timed counter damages attacker once")

	await _reset()
	a = _actor(Vector3.ZERO)
	b = _actor(Vector3(0.0, 0.0, 1.2), 1)
	await _frames(6)
	a.request_action(&"punch")
	await _frames(15)
	_check(a.request_action(&"punch"), "Combo action buffers during recovery")
	await _frames(28)
	_check(b.health <= 124.0, "Buffered second punch resolves")

	await _reset()
	a = _actor(Vector3.ZERO)
	b = _actor(Vector3(0.0, 0.0, 1.2), 1)
	await _frames(6)
	_check(a.begin_grapple(b), "Grapple starts within reach")
	await _frames(46)
	_check(b.state == &"knockdown", "Throw releases target into physics knockdown")
	_check(b.global_position.y > 0.25 and b.global_position.z > 0.85, "Thrown target follows airborne arc")
	_check(is_equal_approx(b.health, 122.0), "Throw impact damages exactly once")
	await _frames(100)
	_check(b._held_by == null and b.state in [&"idle", &"getup"], "Thrown target eventually recovers")

	await _reset()
	a = _actor(Vector3.ZERO)
	b = _actor(Vector3(0.0, 0.0, 1.2), 1)
	var c: NathanCharacterController = _actor(Vector3(-1.0, 0.0, 0.0), 1)
	await _frames(6)
	a.begin_grapple(b)
	await _frames(8)
	a.receive_hit(10.0, c)
	_check(a._pair.is_empty() and b._held_by == null, "Damage cancels both grapple references")
	_check(b.state == &"knockdown", "Cancelled victim is released")

	await _reset()
	a = _actor(Vector3(0.0, 0.0, 1.9))
	a.rotation.y = PI
	_box(Vector3(0.0, 0.35, 0.5), Vector3(3.0, 0.7, 0.4))
	await _frames(6)
	a.set_move_input(Vector2(0.0, 1.0))
	await _frames(30)
	_check(a.global_position.z > 1.02, "Solid obstacle blocks ordinary movement")
	a.set_move_input(Vector2.ZERO)
	a.global_position = Vector3(0.0, 0.0, 1.6)
	a.velocity = Vector3.ZERO
	await _frames(4)
	a.request_action(&"parkour")
	_check(a.state == &"vault", "Low obstacle selects vault")
	await _frames(65)
	_check(a.global_position.z < 0.0 and a.global_position.y < 0.1, "Vault lands beyond obstacle")

	await _reset()
	a = _actor(Vector3(0.0, 0.0, 1.9))
	a.rotation.y = PI
	_box(Vector3(0.0, 0.6, 0.0), Vector3(3.0, 1.2, 2.0))
	await _frames(6)
	a.request_action(&"parkour")
	_check(a.state == &"climb", "Medium obstacle selects climb")
	await _frames(80)
	_check(a.global_position.y > 1.19 and a.global_position.z < 0.8, "Climb clears edge and stands on platform")

	await _reset()
	a = _actor(Vector3(0.0, 0.0, 1.9))
	a.rotation.y = PI
	_box(Vector3(0.0, 1.15, 0.0), Vector3(4.0, 2.3, 2.0))
	await _frames(6)
	a.request_action(&"parkour")
	_check(a.state == &"ledge_grab", "Tall obstacle selects ledge grab")
	await _frames(40)
	_check(a.state == &"hang", "Ledge grab settles into hang")
	a.set_move_input(Vector2(0.5, 0.0))
	start = a.global_position
	await _frames(20)
	_check(absf(a.global_position.x - start.x) > 0.1, "Hanging character shimmies along wall")
	a.set_move_input(Vector2.ZERO)
	_check(a.request_action(&"parkour"), "Hanging character accepts pull-up")
	await _frames(80)
	_check(a.global_position.y > 2.29 and a.global_position.z < 1.0, "Pull-up reaches tall platform")

	await _reset()
	a = _actor(Vector3(-0.45, 0.0, 1.1))
	b = _actor(Vector3(0.28, 0.0, 0.8), 1)
	var station := Station.new()
	var approach := Marker3D.new()
	approach.name = "Approach"
	station.add_child(approach)
	var contact := Marker3D.new()
	contact.name = "Contact"
	contact.position = Vector3(0.0, 1.18, -1.25)
	station.add_child(contact)
	arena.add_child(station)
	_box(Vector3(1.1, 0.5, -1.25), Vector3(3.8, 1.0, 1.25))
	await _frames(6)
	_check(a.begin_environment(b, station), "Environment pair finds collision-free curved approach")
	var closest: float = 10.0
	for frame: int in range(58):
		await _frames(1)
		closest = minf(closest, a.global_position.distance_to(b.global_position))
	_check(closest >= a.actor_radius + b.actor_radius - 0.025, "Paired roots never interpenetrate")
	await _frames(50)
	_check(station.break_count == 1 and bool(station.get_meta("broken", false)), "Environment station breaks exactly once")
	_check(is_equal_approx(b.health, 65.0) and b._held_by == null, "Environment damage resolves and victim releases")

	await _reset()
	a = _actor(Vector3.ZERO)
	b = _actor(Vector3(0.0, 0.0, 1.5), 1)
	_box(Vector3(0.0, 1.0, 0.75), Vector3(3.0, 2.0, 0.15))
	await _frames(6)
	a.request_action(&"kick")
	await _frames(50)
	_check(is_equal_approx(b.health, 160.0), "Solid wall blocks melee line of sight")

	await _reset()
	a = _actor(Vector3.ZERO)
	var visual := Node3D.new()
	visual.name = "ImportedModelFixture"
	var probe := Node3D.new()
	probe.name = "PoseProbe"
	visual.add_child(probe)
	var player := AnimationPlayer.new()
	visual.add_child(player)
	var library := AnimationLibrary.new()
	for clip_name: String in ["idle", "walk", "run", "punch_1"]:
		var animation := Animation.new()
		animation.length = 0.96 if clip_name == "punch_1" else 1.0
		animation.loop_mode = Animation.LOOP_NONE if clip_name == "punch_1" else Animation.LOOP_LINEAR
		var track: int = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("PoseProbe:position"))
		var pose := Vector3(1.0 if clip_name == "walk" else (2.0 if clip_name == "run" else 0.0), 0.0, 0.0)
		animation.track_insert_key(track, 0.0, pose)
		animation.track_insert_key(track, animation.length, Vector3(0.0, 0.0, 1.0) if clip_name == "punch_1" else pose)
		library.add_animation(StringName(clip_name), animation)
	player.add_animation_library(&"", library)
	a.add_child(visual)
	a.bind_model(visual)
	a.set_move_input(Vector2(1.0, 0.0), false)
	await _frames(30)
	_check(absf(probe.position.x - 1.0) < 0.08, "AnimationTree resolves nested imported model root and blends walk")
	a.set_move_input(Vector2.ZERO)
	a.request_action(&"punch")
	await _frames(15)
	_check(probe.position.z > 0.35, "Action clip is time-scaled to gameplay duration")
	print("CONTROLLER_TESTS checks=", checks, " failures=", failures)
	quit(1 if failures > 0 else 0)
