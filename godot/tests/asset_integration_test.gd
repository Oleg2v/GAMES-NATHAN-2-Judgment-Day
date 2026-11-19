extends SceneTree
## Exercises delivered skinned GLBs through the real controller and physics.
## Actor placement creates isolated fixtures; action state/health are not forged.
const Actor = preload("res://scripts/character_controller.gd")
const Materials = preload("res://scripts/character_materials.gd")
var arena: Node3D
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _frames(count: int) -> void:
	for i: int in range(count):
		await physics_frame
		await process_frame

func _box(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	arena.add_child(body)

func _reset() -> void:
	if is_instance_valid(arena):
		arena.queue_free()
		await _frames(2)
	arena = Node3D.new()
	root.add_child(arena)
	_box(Vector3(0,-.1,0),Vector3(40,.2,40))
	await _frames(2)

func _actor(asset: String, at: Vector3, team: int = 0) -> NathanCharacterController:
	var path: String = "res://assets/characters/"+asset+".glb"
	if not FileAccess.file_exists(path):
		_check(false,"Required delivered asset missing: "+path)
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(path,state) != OK:
		_check(false,"GLB import failed: "+path)
		return null
	var model: Node = document.generate_scene(state)
	Materials.apply(model)
	var actor := Actor.new()
	actor.name=asset.capitalize()
	actor.actor_height=1.8 if asset=="thug" else 1.95
	actor.actor_radius=.31 if asset=="thug" else .36
	actor.ledge_hand_height=actor.actor_height+.17
	actor.walk_speed=2.0
	actor.run_speed=3.55
	actor.position=at
	actor.team=team
	actor.add_child(model)
	arena.add_child(actor)
	actor.bind_model(model)
	return actor

func _audit_skin(actor: NathanCharacterController) -> bool:
	var valid: bool=true
	var weighted_meshes: int=0
	for node: Node in actor.find_children("*","MeshInstance3D",true,false):
		var instance := node as MeshInstance3D
		if instance.skin==null:
			continue
		weighted_meshes+=1
		valid=valid and instance.get_node_or_null(instance.skeleton) is Skeleton3D
		var bind_count: int=instance.skin.get_bind_count()
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays: Array=instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.is_empty() or bones.size()!=weights.size():
				valid=false
				continue
			var stride: int=weights.size()/vertices.size()
			valid=valid and stride in [4,8]
			for vertex: int in range(vertices.size()):
				var sum: float=0.0
				valid=valid and vertices[vertex].is_finite()
				for slot: int in range(stride):
					var index: int=vertex*stride+slot
					sum+=weights[index]
					if weights[index]>.00001:
						valid=valid and bones[index]>=0 and bones[index]<bind_count
				valid=valid and absf(sum-1.0)<.015
	return valid and weighted_meshes>=5

func _bone(actor: NathanCharacterController,name: String) -> Vector3:
	return actor.bone_anchor(name)

func _run() -> void:
	for asset: String in ["nathan","oz","thug"]:
		await _reset()
		var actor: NathanCharacterController=_actor(asset,Vector3.ZERO)
		if actor==null:
			continue
		await _frames(6)
		_check(actor._rig!=null and actor._rig.get_bone_count()==53,asset+": real53-bone skeleton binds")
		_check(_audit_skin(actor),asset+": all weighted vertices have valid normalized skin bindings")
		var contract_ok: bool=true
		for clip: StringName in [&"idle",&"walk",&"run",&"punch_1",&"punch_2",&"punch_3",&"kick",&"fury",&"throw",&"held",&"env_attacker",&"env_victim",&"vault",&"climb",&"hang"]:
			contract_ok=contract_ok and actor._animation_player.has_animation(clip)
		_check(contract_ok,asset+": actual action contract is present")
		var loops_ok: bool=true
		for clip: StringName in [&"idle",&"walk",&"run",&"fall",&"hang",&"shimmy"]:
			loops_ok=loops_ok and actor._animation_player.get_animation(clip).loop_mode==Animation.LOOP_LINEAR
		_check(loops_ok,asset+": imported loop flags are enabled")
		var pelvis_before: Vector3=_bone(actor,"pelvis")
		await _frames(50)
		_check(_bone(actor,"pelvis").distance_to(pelvis_before)>.0001,asset+": actual idle skeleton breathes")
		actor.set_move_input(Vector2(0,1),true)
		var minimum_foot: float=100.0
		var maximum_foot: float=-100.0
		for frame: int in range(60):
			await _frames(1)
			var foot: Vector3=actor.to_local(_bone(actor,"foot_l"))
			minimum_foot=minf(minimum_foot,foot.z)
			maximum_foot=maxf(maximum_foot,foot.z)
		_check(actor.state==&"run" and actor.global_position.z < -2.8,asset+": locomotion moves through real physics")
		_check(maximum_foot-minimum_foot>.30,asset+": actual run animation articulates the legs")
		_check(actor._missing_clips.is_empty(),asset+": no animation fallback or missing clip")

	await _reset()
	var a: NathanCharacterController=_actor("nathan",Vector3.ZERO)
	var b: NathanCharacterController=_actor("thug",Vector3(0,0,1.2),1)
	if a!=null and b!=null:
		await _frames(6)
		a.damage_bonus=8.0
		a.damage_multiplier=1.6
		a.ai_time_scale=.5
		var emitted: Array=[]
		a.hit_landed.connect(func(_target: Node3D,amount: float,_kind: StringName) -> void: emitted.append(amount))
		_check(a.request_action(&"punch"),"Buff fixture starts an actual punch")
		await _frames(18)
		_check(is_equal_approx(b.health,160.0),"Slow time delays the actual contact frame")
		_check(is_equal_approx(float(a._animation_tree.get("parameters/RuntimeSpeed/scale")),.5),"Slow time also scales animation playback")
		await _frames(14)
		_check(is_equal_approx(b.health,120.0) and emitted.size()==1 and is_equal_approx(float(emitted[0]),40.0),"Damage bonus/multiplier apply once and emit the real damage")

	await _reset()
	a=_actor("nathan",Vector3(-3,0,5))
	b=_actor("thug",Vector3(3,0,5))
	if a!=null and b!=null:
		await _frames(6)
		b.ai_time_scale=.5
		a.set_move_input(Vector2(0,1));b.set_move_input(Vector2(0,1))
		await _frames(90)
		var ratio: float=(5.0-b.global_position.z)/(5.0-a.global_position.z)
		_check(ratio>.42 and ratio<.56,"Slow time scales physical displacement")

	await _reset()
	_box(Vector3(0,1.8,0),Vector3(4,.2,3))
	a=_actor("nathan",Vector3(0,0,2.7))
	if a!=null:
		await _frames(6)
		var foot_y: float=_bone(a,"foot_l").y
		var pelvis_y: float=_bone(a,"pelvis").y
		_check(a.request_action(&"crouch"),"Crouch starts with actual skeletal pose")
		await _frames(10)
		_check(_bone(a,"pelvis").y<pelvis_y-.25 and absf(_bone(a,"foot_l").y-foot_y)<.05,"Crouch lowers pelvis while feet remain planted")
		a.set_move_input(Vector2(0,1),false)
		await _frames(150)
		a.set_move_input(Vector2.ZERO)
		await _frames(5)
		_check(absf(a.global_position.z)<.5 and a.state==&"crouch","Crouch capsule passes beneath a real low ceiling")
		_check(not a.request_action(&"crouch") and a._compact_capsule,"Standing is rejected beneath the ceiling")
		a.set_move_input(Vector2(0,1),false)
		await _frames(180)
		a.set_move_input(Vector2.ZERO)
		await _frames(5)
		_check(a.request_action(&"crouch"),"Standing succeeds after walking out from the ceiling")
		await _frames(3)
		_check(not a._compact_capsule and is_equal_approx(a._body_shape.height,a.actor_height),"Full standing collision capsule is restored")
	print("ASSET_INTEGRATION_TESTS checks=",checks," failures=",failures)
	quit(1 if failures>0 else 0)
