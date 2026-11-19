extends Control
signal action_requested(action: StringName)
signal view_dragged(motion: Vector2)
signal bag_requested
signal pause_requested
var movement := Vector2.ZERO
var stick_id := -1
var look_id := -1
var stick_origin := Vector2.ZERO
var stick_point := Vector2.ZERO
var active := false
var buttons: Dictionary = {}
var touch_actions: Dictionary = {}
var ui_scale := 1.0
const ACTIONS := [["□ РУКА", &"punch"], ["○ НОГА", &"kick"], ["△ БРОСОК", &"grab"], ["× РЫВОК", &"dodge"], ["КОНТР", &"counter"], ["ПАРКУР", &"parkour"], ["ПРЕДМЕТ", &"interact"], ["СУМКА", &"bag"], ["Ⅱ", &"pause"], ["ЯРОСТЬ", &"fury"], ["ПРИСЕСТЬ", &"crouch"]]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for entry: Array in ACTIONS:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 12)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.035, 0.055, 0.07, 0.65)
		style.border_color = Color(0.92, 0.88, 0.77, 0.35)
		style.set_border_width_all(1)
		style.set_corner_radius_all(30)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		var pressed_style := style.duplicate() as StyleBoxFlat
		pressed_style.bg_color = Color(0.91, 0.35, 0.51, 0.8)
		button.add_theme_stylebox_override("pressed", pressed_style)
		button.button_down.connect(func() -> void: _activate(entry[1]))
		add_child(button)
		buttons[entry[1]] = button
	active = DisplayServer.is_touchscreen_available()
	_layout()
	get_viewport().size_changed.connect(_layout)

func _layout() -> void:
	var viewport := get_viewport_rect().size
	var pixels := float(DisplayServer.window_get_size().y)
	if OS.has_feature("web"):
		pixels = float(JavaScriptBridge.eval("window.innerHeight"))
	if pixels < 2.0:
		pixels = viewport.y
	ui_scale = viewport.y / maxf(1.0, pixels)
	for index in range(ACTIONS.size()):
		var button: Button = buttons[ACTIONS[index][1]]
		button.visible = active
		button.size = Vector2(64, 60) * ui_scale
		button.add_theme_font_size_override("font_size", int(11 * ui_scale))
		var positions := [Vector2(222, 140), Vector2(74, 140), Vector2(148, 211), Vector2(148, 69), Vector2(318, 69), Vector2(318, 140), Vector2(318, 211), Vector2(100, viewport.y - 24), Vector2(180, viewport.y - 24), Vector2(238, 278), Vector2(318, 278)]
		button.position = viewport - positions[index] * ui_scale
		if index in [7, 8]:
			button.position.y = 20 * ui_scale
			button.size = Vector2(64, 44) * ui_scale
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if not active:
			active = true
			_layout()
		if event.pressed:
			var button_action := _button_at(event.position)
			if not button_action.is_empty():
				touch_actions[event.index] = button_action
				# BaseButton also handles native ScreenTouch. Consume this event
				# after our multi-finger routing so one tap emits one action.
				get_viewport().set_input_as_handled()
				_activate(button_action)
				return
			var area := get_viewport_rect().size
			if event.position.x < area.x * 0.42 and event.position.y > area.y * 0.35 and stick_id < 0:
				stick_id = event.index
				stick_origin = event.position
				stick_point = stick_origin
			elif event.position.x > area.x * 0.42 and event.position.y < area.y - 180 and look_id < 0:
				look_id = event.index
		else:
			if touch_actions.has(event.index):
				get_viewport().set_input_as_handled()
			touch_actions.erase(event.index)
			if event.index == stick_id:
				stick_id = -1
				movement = Vector2.ZERO
			if event.index == look_id:
				look_id = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		if touch_actions.has(event.index):
			get_viewport().set_input_as_handled()
			var next_action := _button_at(event.position)
			if not next_action.is_empty() and next_action != touch_actions[event.index]:
				touch_actions[event.index] = next_action
				_activate(next_action)
		elif event.index == stick_id:
			var offset: Vector2 = (event.position - stick_origin).limit_length(58 * ui_scale)
			stick_point = stick_origin + offset
			var magnitude := offset.length() / (58.0 * ui_scale)
			movement = Vector2(offset.x, -offset.y).normalized() * maxf(0, (magnitude - 0.12) / 0.88)
			queue_redraw()
		elif event.index == look_id:
			view_dragged.emit(event.relative)

func _button_at(point: Vector2) -> StringName:
	for key: StringName in buttons:
		var button: Button = buttons[key]
		if button.visible and button.get_global_rect().has_point(point): return key
	return &""

func _activate(action: StringName) -> void:
	if action == &"bag": bag_requested.emit()
	elif action == &"pause": pause_requested.emit()
	else: action_requested.emit(action)

func reset_input() -> void:
	stick_id = -1
	look_id = -1
	movement = Vector2.ZERO
	touch_actions.clear()
	queue_redraw()

func localize(menu: Node) -> void:
	for key: StringName in buttons:
		var symbols := {&"punch": "□ ", &"kick": "○ ", &"grab": "△ ", &"dodge": "× "}
		var label_key := "throw" if key == &"grab" else ("rage" if key == &"fury" else str(key))
		buttons[key].text = "Ⅱ" if key == &"pause" else symbols.get(key, "") + menu.t(label_key)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		reset_input()

func _draw() -> void:
	if not active:
		return
	var origin := stick_origin if stick_id >= 0 else Vector2(100 * ui_scale, get_viewport_rect().size.y - 108 * ui_scale)
	draw_circle(origin, 62 * ui_scale, Color(0.08, 0.11, 0.13, 0.25))
	draw_arc(origin, 62 * ui_scale, 0, TAU, 48, Color(0.93, 0.9, 0.8, 0.35), 1.5 * ui_scale, true)
	draw_circle(stick_point if stick_id >= 0 else origin, 22 * ui_scale, Color(0.96, 0.92, 0.84, 0.65))
