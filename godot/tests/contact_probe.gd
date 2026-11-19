extends SceneTree
const Actor = preload("res://scripts/character_controller.gd")
var arena: Node3D
var model_file: String = "res://assets/characters/nathan.glb"
var victim_file: String = ""
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		model_file = OS.get_cmdline_user_args()[0]
	if OS.get_cmdline_user_args().size() > 1:
		victim_file = OS.get_cmdline_user_args()[1]
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame

func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	arena.add_child(body)
	return body

func _actor(at: Vector3, team: int) -> NathanCharacterController:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path: String = victim_file if team == 1 and not victim_file.is_empty() else model_file
	assert(document.append_from_file(path, state) == OK)
	var model: Node = document.generate_scene(state)
	var actor := Actor.new()
	actor.team = team
	actor.actor_height = 1.95
	actor.actor_radius = 0.36
	actor.ledge_hand_height = 2.12
	actor.position = at
	actor.add_child(model)
	arena.add_child(actor)
	actor.bind_model(model)
	return actor

func _run() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	_box(Vector3(0,-.1,0),Vector3(30,.2,30))
	_box(Vector3(0,.48,-1.4),Vector3(2,.96,.82))
	var station := Node3D.new()
	var approach := Marker3D.new()
	approach.name="Approach"
	station.add_child(approach)
	var contact := Marker3D.new()
	contact.name="Contact"
	contact.position=Vector3(0,1.08,-1.4)
	station.add_child(contact)
	arena.add_child(station)
	var a: NathanCharacterController = _actor(Vector3(-.45,0,1.1),0)
	var b: NathanCharacterController = _actor(Vector3(.28,0,.8),1)
	await _frames(6)
	a._contact_modifier.capture_pose=true
	b._contact_modifier.capture_pose=true
	assert(a.begin_environment(b,station))
	var samples: Array = []
	var pose_written: bool=false
	var minimum_separation: float=100.0
	var full_contact_frames: int=0
	var maximum_head_error: float=0.0
	var maximum_hand_error: float=0.0
	for i: int in range(70):
		await _frames(1)
		if a.pair_phase > .42 and a.pair_phase < .62 and not a._pair.is_empty():
			minimum_separation=minf(minimum_separation,a.global_position.distance_to(b.global_position))
			samples.append({"phase":a.pair_phase,"attacker":a._contact_modifier.residuals.duplicate(),"victim":b._contact_modifier.residuals.duplicate(),"roots":[a.global_position,b.global_position]})
			if a.pair_phase >= .55:
				full_contact_frames += 1
				maximum_head_error=maxf(maximum_head_error,float(b._contact_modifier.residuals.get("head",100.0)))
				for side: String in ["left_hand","right_hand"]:
					maximum_hand_error=maxf(maximum_hand_error,float(a._contact_modifier.residuals.get(side,100.0)))
			if a.pair_phase>.60 and not pose_written:
				var file := FileAccess.open("user://godot_contact_pose.json",FileAccess.WRITE)
				file.store_string(JSON.stringify({"attacker":a._contact_modifier.captured_pose,"victim":b._contact_modifier.captured_pose}))
				file.close()
				pose_written=true
				print("CONTACT_POSE_FILE ",OS.get_user_data_dir()+"/godot_contact_pose.json")
	_check(full_contact_frames>=5,"Environment maintains contact over several frames")
	_check(maximum_head_error<.015,"Victim forehead reaches the basin within1.5cm")
	_check(maximum_hand_error<.05,"Attacker palms remain within5cm of their head/shoulder targets")
	_check(minimum_separation>=a.actor_radius+b.actor_radius-.01,"Environment capsules stay separated")
	print("CONTACT_ENV ",JSON.stringify({"frames":full_contact_frames,"head_error_m":maximum_head_error,"hand_error_m":maximum_hand_error,"root_separation_m":minimum_separation}))
	arena.queue_free()
	await _frames(3)
	arena=Node3D.new();root.add_child(arena)
	_box(Vector3(0,-.1,0),Vector3(30,.2,30))
	var barrier: StaticBody3D = _box(Vector3(0,.35,.5),Vector3(3,.7,.4))
	a=_actor(Vector3(0,0,1.6),0);a.rotation.y=PI
	await _frames(6)
	assert(a.request_action(&"parkour") and a.state==&"vault")
	samples=[]
	var peak: float=0.0
	var overlap_frames: int=0
	var vault_contact_frames: int=0
	var vault_hand_error: float=0.0
	for i: int in range(60):
		await _frames(1)
		peak=maxf(peak,a.global_position.y)
		if a.state==&"vault":
			var query := PhysicsShapeQueryParameters3D.new()
			var shape: CapsuleShape3D = a._body_shape.duplicate()
			shape.radius-=.001
			shape.height-=.002
			query.shape=shape
			query.transform=a._collision_shape.global_transform
			query.collision_mask=1
			for hit: Dictionary in a.get_world_3d().direct_space_state.intersect_shape(query):
				if hit.collider==barrier:
					overlap_frames+=1
			var phase: float=a.state_time/a.state_duration
			if phase>.24 and phase<.56:
				samples.append({"phase":phase,"hands":a._contact_modifier.residuals.duplicate()})
			if phase>=.24 and phase<=.44:
				vault_contact_frames+=1
				for side: String in ["left_hand","right_hand"]:
					vault_hand_error=maxf(vault_hand_error,float(a._contact_modifier.residuals.get(side,100.0)))
	_check(peak<=.25,"Vault uses a low root trajectory")
	_check(overlap_frames==0,"Actual moving vault capsule never overlaps the obstacle")
	_check(vault_contact_frames>=5 and vault_hand_error<=.05,"Vault palms hold the actual edge while contact weight is full")
	_check(not a._compact_capsule and is_equal_approx(a._body_shape.height,a.actor_height),"Standing capsule is restored after vault")
	_check(a.global_position.z<0.0 and a.is_on_floor(),"Vault lands on the far side")
	print("CONTACT_VAULT ",JSON.stringify({"peak_m":peak,"hand_error_m":vault_hand_error,"contact_frames":vault_contact_frames,"overlap_frames":overlap_frames,"standing":not a._compact_capsule}))
	print("CONTACT_TESTS checks=",checks," failures=",failures)
	quit(1 if failures>0 else 0)
