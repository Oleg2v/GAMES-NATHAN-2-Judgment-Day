extends CanvasLayer
signal resumed
signal new_campaign
signal retry_chapter
signal item_selected(item: String)
signal language_changed
signal next_chapter
signal settings_changed(muted: bool, reduced: bool)
signal mode_changed(current: String)
var language := "ru":
	set(value):
		language = value if value in ["ru", "en", "he"] else "ru"
		_sync_browser_state()
var translations: Dictionary = {}
var overlay: Control
var box: VBoxContainer
var mode := "":
	set(value):
		if mode == value: return
		mode = value
		_sync_browser_state()
		mode_changed.emit(mode)
var muted := false
var reduced := false
var orientation_paused := false
var pause_before_rotation := false
var _mode_before_rotation := ""
var inventory: Dictionary = {}
var _rotation_token := 0
var _started := false
var header: Label
var _panel: PanelContainer
var _scroll: ScrollContainer
var _gradient: ColorRect
var _css_size := Vector2(1280,800)
var _ui_scale := 1.0
var _touch := false
const PAPER := Color(0.94,0.92,0.85)
const MUTED_TEXT := Color(0.70,0.76,0.75)
const ACCENT := Color(0.88,0.70,0.45)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	translations = JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/strings.json"))
	var config := ConfigFile.new()
	if config.load("user://preferences.cfg") == OK:
		language = config.get_value("ui", "language", "ru")
		muted = config.get_value("ui", "muted", false)
		reduced = config.get_value("ui", "reduced", false)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	# A local left-edge gradient preserves the character and city on the right.
	_gradient=ColorRect.new()
	_gradient.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code="shader_type canvas_item; void fragment(){float a=pow(1.0-smoothstep(0.12,1.0,UV.x),1.35)*0.72;COLOR=vec4(0.025,0.045,0.052,a);}"
	var shader_material := ShaderMaterial.new()
	shader_material.shader=shader
	_gradient.material=shader_material
	overlay.add_child(_gradient)
	_panel=PanelContainer.new()
	_panel.layout_direction=Control.LAYOUT_DIRECTION_LTR
	var panel_style := _surface(Color(0.045,0.065,0.075,0.78),12,Color(0.70,0.79,0.78,0.20))
	for side in ["left","right","top","bottom"]: panel_style.set("content_margin_"+side,18.0)
	_panel.add_theme_stylebox_override("panel",panel_style)
	overlay.add_child(_panel)
	_scroll=ScrollContainer.new()
	_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	_scroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_scroll.follow_focus=true
	_scroll.scroll_deadzone=8
	_panel.add_child(_scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 9)
	_scroll.add_child(box)
	overlay.hide()
	_sync_browser_state()
	get_viewport().size_changed.connect(_on_viewport_changed)
	call_deferred("_on_viewport_changed")

func _browser_state() -> Dictionary:
	return {"playing": mode.is_empty(), "lang": language}

func _browser_state_script() -> String:
	# Serialize the allowlisted language and boolean as data, never as JS source.
	return """(function(){try{
if(typeof document==='undefined'||!document.body)return;
const state=%s;
document.body.dataset.playing=state.playing?'true':'false';
document.body.dataset.lang=state.lang;
document.documentElement.lang=state.lang;
}catch(_error){}})();""" % JSON.stringify(_browser_state())

func _sync_browser_state() -> void:
	if is_inside_tree() and OS.has_feature("web"):
		JavaScriptBridge.eval(_browser_state_script())

func _surface(color: Color, radius: int, border: Color=Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color=color
	style.border_color=border
	style.set_border_width_all(1 if border.a>0 else 0)
	style.set_corner_radius_all(radius)
	return style

func _measure_screen() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var css := Vector2(DisplayServer.window_get_size())
	_touch=DisplayServer.is_touchscreen_available()
	if OS.has_feature("web"):
		var result = JavaScriptBridge.eval("JSON.stringify({w:window.innerWidth,h:window.innerHeight,touch:navigator.maxTouchPoints>0})")
		if result is String:
			var metrics = JSON.parse_string(result)
			if metrics is Dictionary:
				css=Vector2(float(metrics.get("w",viewport_size.x)),float(metrics.get("h",viewport_size.y)))
				_touch=bool(metrics.get("touch",_touch))
	if css.x<1 or css.y<1: css=viewport_size
	return css

func _relayout() -> void:
	_layout_for_metrics(get_viewport().get_visible_rect().size,_measure_screen())

func _layout_for_metrics(viewport_size: Vector2, css_size: Vector2) -> void:
	# Child dimensions are CSS pixels; compensate Godot's stretched viewport.
	_css_size=css_size
	_ui_scale=maxf(0.35,minf(viewport_size.x/maxf(css_size.x,1.0),viewport_size.y/maxf(css_size.y,1.0)))
	var compact := css_size.y<500 or css_size.x<800
	var margin := 8.0 if compact else 26.0
	var panel_width := minf(410.0,maxf(298.0,css_size.x*0.46))
	panel_width=minf(panel_width,css_size.x-margin*2.0)
	var panel_height := minf(720.0,css_size.y-margin*2.0)
	var top := margin if compact else maxf(margin,(css_size.y-panel_height)*0.5)
	_panel.scale=Vector2.ONE*_ui_scale
	_panel.position=Vector2(margin,top)*_ui_scale
	_panel.size=Vector2(panel_width,maxf(120.0,panel_height))
	_gradient.size=Vector2(minf(css_size.x,panel_width+margin+180),css_size.y)*_ui_scale

func _on_viewport_changed() -> void:
	if not is_instance_valid(_panel): return
	_relayout()
	_orientation()
	await get_tree().create_timer(0.12,true).timeout
	if is_instance_valid(_panel): _relayout()

func _text(value: String, font_size: int=14, color: Color=MUTED_TEXT) -> Label:
	var label := Label.new()
	label.text=value
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label

func t(key: String) -> String:
	return str(translations.get(language, {}).get(key, translations.get("ru", {}).get(key, key)))

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("ui", "language", language)
	config.set_value("ui", "muted", muted)
	config.set_value("ui", "reduced", reduced)
	config.save("user://preferences.cfg")

func _clear(title: String, subtitle := "") -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
	box.layout_direction = Control.LAYOUT_DIRECTION_RTL if language == "he" else Control.LAYOUT_DIRECTION_LTR
	_scroll.scroll_vertical=0
	var brand := HBoxContainer.new()
	brand.layout_direction=Control.LAYOUT_DIRECTION_LTR
	brand.add_theme_constant_override("separation",12)
	var monogram := _text("N²",17,ACCENT)
	monogram.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	monogram.custom_minimum_size.x=32
	brand.add_child(monogram)
	var edition := _text(t("campaign"),10,MUTED_TEXT)
	edition.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	brand.add_child(edition)
	box.add_child(brand)
	header=_text(title,32 if mode=="main" else 26,PAPER)
	if mode=="main": header.text_direction=Control.TEXT_DIRECTION_LTR
	box.add_child(header)
	if not subtitle.is_empty():
		box.add_child(_text(subtitle,13,MUTED_TEXT))
	var rule := ColorRect.new()
	rule.color=Color(0.77,0.80,0.76,0.19)
	rule.custom_minimum_size.y=1
	rule.mouse_filter=Control.MOUSE_FILTER_IGNORE
	box.add_child(rule)
	overlay.show()
	get_tree().paused = true
	_relayout()

func _button(label: String, callback: Callable, accent := false) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 48 if accent else 46
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.clip_text=true
	button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color",Color(0.055,0.075,0.084) if accent else PAPER)
	button.add_theme_color_override("font_hover_color",Color(0.055,0.075,0.084) if accent else Color.WHITE)
	button.add_theme_color_override("font_pressed_color",Color(0.055,0.075,0.084) if accent else PAPER)
	var style := _surface(ACCENT if accent else Color(0.16,0.20,0.21,0.65),6,Color(0.75,0.79,0.76,0.20))
	style.content_margin_left = 14
	style.content_margin_right = 14
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = style.bg_color.lightened(0.09)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color=style.bg_color.darkened(0.10)
	button.add_theme_stylebox_override("pressed",pressed)
	var focus := _surface(Color.TRANSPARENT,6,Color(0.94,0.81,0.58))
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus",focus)
	button.add_theme_stylebox_override("disabled",_surface(Color(0.10,0.13,0.14,0.6),6,Color(0.6,0.65,0.64,0.12)))
	button.pressed.connect(callback)
	box.add_child(button)
	return button

func show_main() -> void:
	if orientation_paused:
		return
	mode = "main"
	_clear("NATHAN 2", "JUDGMENT DAY\n" + t("menuSub"))
	_button(t("start") if not _started else t("continue"), resume_game, true)
	_button(t("help"), show_help)
	_button(t("settings"), show_settings)
	_languages()

func show_pause() -> void:
	if mode in ["rotate", "victory", "defeat", "complete"]:
		return
	mode = "pause"
	_clear(t("paused"), t("pausedSub"))
	_button(t("backGame"), resume_game, true)
	_button(t("help"), show_help)
	_button(t("settings"), show_settings)
	_button(t("restart"), func() -> void:
		get_tree().paused = false
		new_campaign.emit())

func resume_game() -> void:
	if orientation_paused:
		return
	mode = ""
	_started = true
	overlay.hide()
	get_tree().paused = false
	resumed.emit()

func show_help() -> void:
	mode = "help"
	_clear(t("help"))
	for pair in [["move","movementHelp"],["fists","combatHelp"],["parkour","parkourHelp"],["bag","itemsHelp"],["mobile","touchHelp"]]:
		var card := PanelContainer.new()
		var style := _surface(Color(0.12,0.16,0.17,0.64),6,Color(0.70,0.77,0.74,0.13))
		for side in ["left","right"]:style.set("content_margin_"+side,12.0)
		for side in ["top","bottom"]:style.set("content_margin_"+side,10.0)
		card.add_theme_stylebox_override("panel",style)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation",5)
		content.add_child(_text(t(pair[0]),13,ACCENT))
		content.add_child(_text(t(pair[1]),13,PAPER))
		card.add_child(content)
		box.add_child(card)
	_button(t("back"), show_pause if _started else show_main)

func _button_content(button: Button) -> VBoxContainer:
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.mouse_filter=Control.MOUSE_FILTER_IGNORE
	for side in ["left","right"]:margins.add_theme_constant_override("margin_"+side,14)
	for side in ["top","bottom"]:margins.add_theme_constant_override("margin_"+side,10)
	button.add_child(margins)
	var content := VBoxContainer.new()
	content.mouse_filter=Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",4)
	margins.add_child(content)
	return content

func _setting_row(title: String, enabled: bool, callback: Callable) -> void:
	var button := _button("",callback)
	button.custom_minimum_size.y=64
	var content := _button_content(button)
	content.add_child(_text(title,14,PAPER))
	content.add_child(_text(t("on" if enabled else "off"),12,ACCENT if enabled else MUTED_TEXT))

func show_settings() -> void:
	mode = "settings"
	_clear(t("settings"))
	_setting_row(t("sound"), not muted, func() -> void:
		muted = not muted
		_save_settings()
		settings_changed.emit(muted, reduced)
		show_settings())
	_setting_row(t("reducedMotion"), reduced, func() -> void:
		reduced = not reduced
		_save_settings()
		settings_changed.emit(muted, reduced)
		show_settings())
	box.add_child(_text(t("language"),12,MUTED_TEXT))
	_languages()
	_button(t("back"), show_pause if _started else show_main)

func _languages() -> void:
	var row := HBoxContainer.new()
	row.layout_direction=Control.LAYOUT_DIRECTION_LTR
	row.add_theme_constant_override("separation", 8)
	for code in ["ru", "en", "he"]:
		var button := Button.new()
		button.text = "עברית" if code == "he" else code.to_upper()
		button.custom_minimum_size = Vector2(64, 44)
		button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",14)
		button.add_theme_color_override("font_color",ACCENT if code==language else PAPER)
		button.add_theme_stylebox_override("normal",_surface(Color(0.29,0.30,0.26,0.86) if code==language else Color(0.12,0.16,0.17,0.7),6,ACCENT if code==language else Color(0.6,0.7,0.68,0.18)))
		button.add_theme_stylebox_override("hover",_surface(Color(0.24,0.29,0.29,0.9),6,ACCENT))
		button.add_theme_stylebox_override("focus",_surface(Color.TRANSPARENT,6,ACCENT))
		button.pressed.connect(func() -> void:
			language = code
			_save_settings()
			language_changed.emit()
			if mode == "settings": show_settings()
			else: show_main())
		row.add_child(button)
	box.add_child(row)

func show_bag(items: Dictionary) -> void:
	if orientation_paused:
		return
	inventory = items
	mode = "bag"
	_clear(t("bagTitle"))
	for key in ["v20", "v30", "weed", "ozempic", "shawarma"]:
		var count := int(items.get(key, 0))
		var button := _button("", func() -> void:
			item_selected.emit(key)
			resume_game())
		button.name="Item_"+key
		button.custom_minimum_size.y=78
		button.disabled = count <= 0
		var content := _button_content(button)
		content.add_child(_text(t(key)+"   ×"+str(count),15,PAPER if count>0 else MUTED_TEXT))
		content.add_child(_text(t(key+"Desc") if count>0 else t("empty")+" · "+t(key+"Desc"),12,MUTED_TEXT))
	box.add_child(_text(t("fictional"),11,MUTED_TEXT))
	_button(t("backGame"), resume_game, true)

func show_bagfull(items: Dictionary) -> void:
	show_bag(items)

func show_result(won: bool, final_chapter := false) -> void:
	mode = "victory" if won and final_chapter else ("complete" if won else "defeat")
	_clear(t("victory" if mode == "victory" else ("levelcomplete" if won else "defeat")), t("victorySub" if mode == "victory" else ("levelcompleteSub" if won else "defeatSub")))
	if won and not final_chapter:
		_button(t("next"), func() -> void:
			get_tree().paused = false
			next_chapter.emit(), true)
	else:
		_button(t("restart" if won else "retry"), func() -> void:
			get_tree().paused = false
			if won: new_campaign.emit()
			else: retry_chapter.emit(), true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if mode.is_empty(): show_pause()
		elif mode in ["pause", "help", "settings", "bag"]: resume_game()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(overlay):
		_rotation_token += 1
		if mode.is_empty() and _started:
			show_pause()
		elif mode == "rotate" and not orientation_paused:
			# A backgrounded tab must never finish the rotation countdown and
			# resume the fight while the player is elsewhere.
			mode = ""
			show_pause() if _started else show_main()

func _orientation() -> void:
	var portrait := _css_size.y > _css_size.x and _touch
	if portrait and not orientation_paused:
		_mode_before_rotation = mode if not mode.is_empty() else ("main" if not _started else "")
		pause_before_rotation = not _mode_before_rotation.is_empty()
		orientation_paused = true
		_rotation_token += 1
		mode = "rotate"
		_clear(t("rotateTitle"), t("rotateSub"))
	elif not portrait and orientation_paused:
		orientation_paused = false
		if pause_before_rotation:
			_restore_rotation_screen()
		else:
			_rotation_token += 1
			var token := _rotation_token
			for number in [3, 2, 1]:
				header.text = str(number)
				await get_tree().create_timer(1.0, true).timeout
				if token != _rotation_token or orientation_paused: return
			resume_game()

func _restore_rotation_screen() -> void:
	# Results contain the only Next/Retry path. Restoring a generic pause screen
	# after rotation loses that path while the game remains finished or dead.
	var previous: String = _mode_before_rotation
	mode = ""
	match previous:
		"complete": show_result(true,false)
		"victory": show_result(true,true)
		"defeat": show_result(false)
		"bag": show_bag(inventory)
		"help": show_help()
		"settings": show_settings()
		"main": show_main()
		_: show_pause() if _started else show_main()
