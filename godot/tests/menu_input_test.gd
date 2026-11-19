extends SceneTree
const Menu = preload("res://scripts/game_menu.gd")
const Touch = preload("res://scripts/touch_controls.gd")
var checks: int=0
var failures: int=0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func _frames(n: int=3) -> void:
	for i: int in range(n):
		await process_frame

func _touch(index: int,point: Vector2,pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index=index
	event.position=point
	event.pressed=pressed
	root.push_input(event,true)

func _drag(index: int,point: Vector2,relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index=index
	event.position=point
	event.relative=relative
	root.push_input(event,true)

func _run() -> void:
	var menu := Menu.new()
	root.add_child(menu)
	await _frames()
	menu.show_main()
	await _frames()
	var button: Button=menu.box.find_children("*","Button",true,false)[0]
	var center: Vector2=button.get_global_rect().get_center()
	_touch(0,center,true)
	await _frames(1)
	_touch(0,center,false)
	await _frames()
	_check(menu.mode.is_empty() and not paused,"Actual ScreenTouch activates Start without mouse emulation")
	menu.resume_game()
	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var controls := Touch.new()
	canvas.add_child(controls)
	controls.active=true
	controls._layout()
	var actions: Array=[]
	var looks: Array=[]
	controls.action_requested.connect(func(action: StringName) -> void: actions.append(action))
	controls.view_dragged.connect(func(delta: Vector2) -> void: looks.append(delta))
	await _frames()
	var stick := Vector2(100,650)
	var look := Vector2(800,240)
	_touch(0,stick,true)
	_drag(0,stick+Vector2(0,-50),Vector2(0,-50))
	_touch(1,look,true)
	_drag(1,look+Vector2(20,0),Vector2(20,0))
	var punch: Button=controls.buttons[&"punch"]
	_touch(2,punch.get_global_rect().get_center(),true)
	await _frames()
	_check(controls.movement.y>.5 and controls.stick_id==0,"Movement touch survives independent action finger")
	_check(looks.size()==1 and controls.look_id==1,"Camera drag works concurrently with movement")
	_check(actions==[&"punch"],"Action touch fires once, without duplicate Button activation")
	_touch(2,punch.get_global_rect().get_center(),false)
	_check(controls.movement.y>.5,"Releasing action finger does not release movement")
	_touch(0,stick,false)
	_check(controls.movement==Vector2.ZERO and controls.look_id==1,"Releasing movement resets only its own touch")
	menu.show_pause()
	await _frames()
	_check(controls.movement==Vector2.ZERO and controls.look_id==-1,"Pause clears held touch inputs")
	menu.resume_game()
	for result: Array in [[true,false,"complete"],[true,true,"victory"],[false,false,"defeat"]]:
		menu.show_result(result[0],result[1])
		menu._touch=true
		menu._css_size=Vector2(390,844)
		menu._orientation()
		_check(menu.mode=="rotate" and paused,"Portrait pauses result screen")
		menu._css_size=Vector2(844,390)
		menu._orientation()
		_check(menu.mode==result[2] and paused,"Landscape restores exact result screen: "+str(result[2]))
	print("MENU_INPUT_TESTS checks=",checks," failures=",failures)
	paused=false
	quit(1 if failures>0 else 0)
