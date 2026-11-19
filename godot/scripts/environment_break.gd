extends Node3D
## Assigned to the independent fryer station after the environment is assembled.
func break_station() -> void:
	for child: Node in find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.position.y < 0.85:
			continue
		var body := RigidBody3D.new()
		body.mass = 1.0
		body.collision_layer = 8
		body.collision_mask = 1
		get_tree().current_scene.add_child(body)
		body.global_transform = mesh.global_transform
		var detached := MeshInstance3D.new()
		detached.mesh = mesh.mesh
		detached.material_override = mesh.material_override
		body.add_child(detached)
		var collider := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.get_aabb().size.max(Vector3.ONE * 0.03)
		collider.shape = box
		body.add_child(collider)
		body.linear_velocity = global_basis.z * 1.5 + Vector3(randf_range(-2, 2), randf_range(2, 4), randf_range(-1, 1))
		body.angular_velocity = Vector3(randf_range(-4, 4), 3, -2)
		mesh.visible = false
		get_tree().create_timer(8.0).timeout.connect(body.queue_free)
	var smoke := CPUParticles3D.new()
	smoke.amount = 35
	smoke.lifetime = 1.4
	smoke.one_shot = true
	smoke.explosiveness = 0.6
	smoke.direction = Vector3.UP
	smoke.spread = 45.0
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 1.7
	smoke.gravity = Vector3(0, 0.3, 0)
	smoke.scale_amount_min = 0.04
	smoke.scale_amount_max = 0.13
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	smoke.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.87, 0.85, 0.78, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke.material_override = mat
	add_child(smoke)
	smoke.position = Vector3(0, 1.1, 0)
	smoke.emitting = true
	get_tree().create_timer(2.0).timeout.connect(smoke.queue_free)
