extends RigidBody3D
var durability := 38.0
var parts: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("improvised_props")
	collision_layer = 4
	collision_mask = 7
	mass = 4.0
	continuous_cd = true
	linear_damp = 0.45
	angular_damp = 0.6
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.24, 0.14)
	wood.roughness = 0.84
	var texture_path := "res://assets/environment/materials/brown_planks_03/brown_planks_03_diff_1k.jpg"
	if ResourceLoader.exists(texture_path): wood.albedo_texture = load(texture_path)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.16, 0.17)
	metal.metallic = 0.7
	metal.roughness = 0.4
	for x in [-0.23, 0.23]:
		for z in [-0.22, 0.22]:
			_part(Vector3(0.035, 0.47, 0.035), Vector3(x, 0.235, z), metal)
		_part(Vector3(0.035, 0.4, 0.035), Vector3(x, 0.68, -0.22), metal)
	for z in [-0.15, 0.0, 0.15]:
		_part(Vector3(0.53, 0.035, 0.12), Vector3(0, 0.47, z), wood)
	for y in [0.66, 0.82]:
		_part(Vector3(0.53, 0.12, 0.035), Vector3(0, y, -0.22), wood)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.54, 0.88, 0.50)
	collision.shape = shape
	collision.position.y = 0.44
	add_child(collision)

func _part(size_value: Vector3, at: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	part.mesh = mesh
	part.material_override = material
	part.position = at
	add_child(part)
	parts.append(part)

func receive_damage(amount: float, source: Node3D) -> void:
	if bool(get_meta("broken", false)) or bool(get_meta("held", false)):
		return
	durability -= amount
	if durability > 0.0:
		if is_instance_valid(source): apply_central_impulse((global_position - source.global_position).normalized() * 4.0 + Vector3.UP)
		return
	set_meta("broken", true)
	remove_from_group("improvised_props")
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	for part: MeshInstance3D in parts:
		var body := RigidBody3D.new()
		body.mass = 0.25
		body.collision_layer = 8
		body.collision_mask = 1
		get_tree().current_scene.add_child(body)
		body.global_transform = part.global_transform
		var debris := MeshInstance3D.new()
		debris.mesh = part.mesh
		debris.material_override = part.material_override
		body.add_child(debris)
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = (part.mesh as BoxMesh).size
		collider.shape = box
		body.add_child(collider)
		body.linear_velocity = Vector3(randf_range(-2, 2), randf_range(1, 3), randf_range(-2, 2))
		body.angular_velocity = Vector3(randf_range(-4, 4), 2, randf_range(-4, 4))
		get_tree().create_timer(7.0).timeout.connect(body.queue_free)
	queue_free()
