extends SceneTree
## Run this file by absolute path with --main-pack <export.pck>.
## A successful engine start alone does not prove an exported scene has a script.
var failures: int=0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool,label: String) -> void:
	if not ok:
		failures+=1
		push_error(label)

func _run() -> void:
	var packed: PackedScene=load("res://scenes/waterfront_game.tscn")
	var state: SceneState=packed.get_state()
	var attached_script: bool=false
	for property: int in range(state.get_node_property_count(0)):
		if state.get_node_property_name(0,property)==&"script":
			var value: Variant=state.get_node_property_value(0,property)
			attached_script=value is Script and value.can_instantiate()
	_check(attached_script,"Exported waterfront root must retain its instantiable game script")
	if not attached_script:
		print("PACK_SMOKE failures=",failures," root_script=false")
		quit(1)
		return
	var scene: Node=load("res://scenes/boot.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	for frame: int in range(30):
		await process_frame
		if frame in [4,29]:
			var game: Node=current_scene
			var live: bool=is_instance_valid(game) and game.get_script()!=null and game.get("player")!=null
			_check(live,"Boot must construct a live game by frame"+str(frame+1))
			if live:
				var camera: Camera3D=root.get_camera_3d()
				_check(camera!=null and camera.current,"Boot must provide a current3D camera")
				_check(game.menu.mode=="main" and game.menu.overlay.visible and paused,"Boot must show its interactive main menu")
				_check(game.enemies.size()==2 and game.player._rig.get_bone_count()==53,"Boot must load actual Nathan and encounter enemies")
				print("PACK_SMOKE_FRAME ",JSON.stringify({"frame":frame+1,"nodes":root.find_children("*","",true,false).size(),"camera":str(camera.get_path()) if camera else "NULL","menu":game.menu.mode,"enemies":game.enemies.size()}))
	print("PACK_SMOKE failures=",failures," root_script=",attached_script)
	paused=false
	quit(1 if failures>0 else 0)
