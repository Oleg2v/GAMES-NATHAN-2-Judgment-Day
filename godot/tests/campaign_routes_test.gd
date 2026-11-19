extends SceneTree
const Campaign = preload("res://scripts/campaign_environment.gd")
const Actor = preload("res://scripts/character_controller.gd")
const Ashdod = preload("res://scripts/ashdod_environment.gd")
const Game = preload("res://scripts/waterfront_game.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_audit")

func _frames(count: int) -> void:
	for i in range(count):await physics_frame

func _space_press_release(host: Node3D, actor: NathanCharacterController) -> bool:
	var previous: StringName=actor.state
	var down := InputEventKey.new()
	down.physical_keycode=KEY_SPACE
	down.pressed=true
	host._unhandled_input(down)
	var up := InputEventKey.new()
	up.physical_keycode=KEY_SPACE
	up.pressed=false
	host._unhandled_input(up)
	return actor.state!=previous

func _audit() -> void:
	for chapter in [1,2,3]:
		var environment: Node3D = Ashdod.new() if chapter==1 else Campaign.new()
		if chapter>1:environment.set("chapter",chapter)
		root.add_child(environment)
		if chapter==1:
			var builder := Game.new()
			builder.world=environment
			builder._city_route()
			builder.free()
		await _frames(3)
		var actor := Actor.new()
		actor.actor_height=1.95
		actor.actor_radius=0.36
		actor.ledge_hand_height=2.12
		actor.run_speed=3.55
		actor.walk_speed=2.0
		actor.position=Vector3(3,0.04,24) if chapter==1 else environment.get_node("Spawn").position
		actor.rotation.y=PI
		root.add_child(actor)
		# Invoke the actual game's SPACE key-down/key-up handler, with all
		# motion and collision resolved by its real CharacterBody3D controller.
		var input_host := Game.new()
		input_host.player=actor
		var completed: Array[String] = []
		var states: Array[String] = []
		actor.parkour_completed.connect(func(kind: StringName):completed.append(str(kind)))
		actor.state_changed.connect(func(_previous: StringName,current: StringName):
			if current in [&"jump",&"vault",&"climb",&"hang",&"ledge_grab"]:states.append(str(current)))
		await _frames(8)
		var stage := 0
		var trigger_positions := [10.5,8.2,1.6,-6.9,-43.0] if chapter==1 else [26.5,8.2,0.1,-8.9,-47.0]
		var expected := ["jump","vault","climb","hang"]
		var pending := false
		var pulled := false
		var idle_count := 0
		var maximum_vault_root := -INF
		var overlap_frames := 0
		for frame in range(2400):
			if stage<4 and not pending:
				actor.set_move_input(Vector2(0,1))
				if actor.global_position.z<=float(trigger_positions[stage]) and actor.state in [&"idle",&"walk",&"run"]:
					actor.set_move_input(Vector2(0,1) if stage==0 else Vector2.ZERO)
					var accepted: bool=_space_press_release(input_host,actor)
					pending=true
					print(JSON.stringify({"chapter":chapter,"trigger":expected[stage],"accepted":accepted,"state":str(actor.state),"position":[actor.position.x,actor.position.y,actor.position.z]}))
			elif pending:
				if stage==3 and actor.state==&"hang" and not pulled:
					_space_press_release(input_host,actor)
					pulled=true
				if expected[stage] in completed:
					pending=false
					stage+=1
			elif stage==4:
				actor.set_move_input(Vector2(0,1))
				if actor.position.z<=float(trigger_positions[4]):break
			if actor.state==&"vault":
				maximum_vault_root=maxf(maximum_vault_root,actor.position.y)
				var shape_query := PhysicsShapeQueryParameters3D.new()
				shape_query.shape=actor._body_shape
				shape_query.transform=actor._collision_shape.global_transform
				shape_query.collision_mask=1
				shape_query.exclude=[actor.get_rid()]
				var overlaps := actor.get_world_3d().direct_space_state.intersect_shape(shape_query,1)
				if not overlaps.is_empty():
					overlap_frames+=1
					var collider: Node3D=overlaps[0].collider
					print(JSON.stringify({"overlap_chapter":chapter,"time":actor.state_time,"root":str(actor.position),"shape_height":actor._body_shape.height,"shape_center":actor._collision_shape.position.y,"collider":str(collider.get_path()),"collider_at":str(collider.global_position)}))
			if actor.state in [&"idle",&"walk",&"run"] and pending:idle_count+=1
			else:idle_count=0
			if idle_count>90:break
			await physics_frame
		var capsule_restored := absf(actor._body_shape.height-1.95)<0.0001 and absf(actor._body_shape.radius-0.36)<0.0001
		var ok: bool=stage==4 and actor.position.z<=float(trigger_positions[4]) and overlap_frames==0 and maximum_vault_root<0.25 and capsule_restored
		if not ok:failures.append("chapter%d stage%d z%.3f %s"%[chapter,stage,actor.position.z,str(actor.state)])
		print(JSON.stringify({"chapter":chapter,"success":ok,"stage":stage,"end":[actor.position.x,actor.position.y,actor.position.z],"completed":completed,"states":states,"maximum_vault_root":maximum_vault_root,"overlap_frames":overlap_frames,"capsule_height":actor._body_shape.height,"capsule_radius":actor._body_shape.radius}))
		input_host.free()
		actor.queue_free()
		environment.queue_free()
		await _frames(4)
	print(JSON.stringify({"failures":failures}))
	quit(0 if failures.is_empty() else 1)
