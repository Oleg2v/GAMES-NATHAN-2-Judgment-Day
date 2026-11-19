extends Node3D
const Actor = preload("res://scripts/character_controller.gd")
const CameraRig = preload("res://scripts/combat_camera.gd")
const EnvironmentScene = preload("res://scripts/ashdod_environment.gd")
const Brain = preload("res://scripts/enemy_brain.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const ImpactAudio = preload("res://scripts/impact_audio.gd")
const Prop = preload("res://scripts/breakable_prop.gd")
const Station = preload("res://scripts/environment_break.gd")
const Menu = preload("res://scripts/game_menu.gd")
const CharacterMaterials = preload("res://scripts/character_materials.gd")
var player: NathanCharacterController
var camera_rig: NathanCombatCamera
var enemies: Array[NathanCharacterController] = []
var world: Node3D
var controls: Control
var sound: Node
var health_bar: ProgressBar
var hud_root: Control
var identity_label: Label
var objective: Label
var hint: Label
var tally: Label
var panel: PanelContainer
var attack_owner: NathanCharacterController
var attack_reservation := 0.0
var total_defeated := 0
var phase := 0
var step_clock := 0.0
var ui_clock := 0.0
var _restarting := false
var _model_cache: Dictionary = {}
var menu: CanvasLayer
var chapter := 1
var route_done: Dictionary = {}
var exit_position := Vector3(3, 0, -43)
var exit_marker: Node3D
var inventory := {"v20": 2, "v30": 1, "weed": 1, "ozempic": 1, "shawarma": 3}
var buffs := {"power": 0.0, "power_time": 0.0, "weed": 0.0, "slim": 0.0}
var rage := 0.0
var status_line: Label
var model_root: Node3D
var _finished := false
var _hitstop_until := 0
var _combo := 0
var _combo_time := 0.0

func _ready() -> void:
	var save := ConfigFile.new()
	if save.load("user://campaign.cfg") == OK: chapter = clampi(save.get_value("campaign", "chapter", 1), 1, 3)
	menu = Menu.new()
	add_child(menu)
	menu.resumed.connect(_reset_input)
	menu.language_changed.connect(_localize)
	menu.mode_changed.connect(_on_menu_mode_changed)
	menu.settings_changed.connect(_settings)
	menu.item_selected.connect(_use_item)
	menu.next_chapter.connect(func() -> void: _change_chapter(chapter + 1))
	menu.new_campaign.connect(func() -> void: _change_chapter(1))
	menu.retry_chapter.connect(func() -> void: _change_chapter(chapter))
	if chapter > 1 and ResourceLoader.exists("res://scripts/campaign_environment.gd"):
		world = load("res://scripts/campaign_environment.gd").new()
		world.set("chapter", chapter)
	else:
		world = EnvironmentScene.new()
	world.name = "Ashdod"
	add_child(world)
	for station: Node in get_tree().get_nodes_in_group("environment_stations"):
		station.set_script(Station)
	sound = ImpactAudio.new()
	add_child(sound)
	_build_ui()
	var spawn := Vector3(4.0, 0.1, 24.0)
	if chapter > 1 and world.has_node("Spawn"): spawn = (world.get_node("Spawn") as Node3D).global_position + Vector3.UP * 0.1
	player = _spawn_actor("nathan", spawn, 0, 160)
	if player == null:
		_message("Модель Натана ещё готовится", "Файл модели отсутствует. Сцену можно открыть после экспорта персонажа.")
		return
	player.name = "Nathan"
	player.actor_height = 1.95
	player.ledge_hand_height = 2.12
	player.run_speed = 3.55
	player.walk_speed = 2.0
	player.rotation.y = 0.08
	player.hit_landed.connect(_on_hit)
	player.health_changed.connect(_on_health)
	player.knocked_out.connect(_on_player_down)
	player.environment_hit.connect(_on_environment)
	player.state_changed.connect(_on_state)
	player.parkour_completed.connect(func(kind: StringName) -> void:
		route_done[kind] = true
		_update_objective())
	camera_rig = CameraRig.new()
	camera_rig.yaw = 0.08
	camera_rig.distance = 3.7
	add_child(camera_rig)
	camera_rig.set_subject(player)
	controls.action_requested.connect(_action)
	controls.view_dragged.connect(camera_rig.rotate_view)
	controls.bag_requested.connect(func() -> void: menu.show_bag(inventory))
	controls.pause_requested.connect(menu.show_pause)
	for point: Vector3 in [Vector3(9, 0.05, 8), Vector3(11, 0.05, 1), Vector3(4, 0.05, -5), Vector3(9, 0.05, 16)]:
		var prop := Prop.new()
		prop.position = point
		prop.rotation.y = randf_range(-PI, PI)
		add_child(prop)
	_spawn_encounter()
	if chapter == 1: _city_route()
	elif world.has_node("Exit"): exit_position = (world.get_node("Exit") as Node3D).global_position
	_exit_beacon()
	_localize()
	_settings(menu.muted, menu.reduced)
	await get_tree().physics_frame
	await get_tree().physics_frame
	menu.show_main()

func _spawn_actor(asset: String, at: Vector3, team_value: int, hp: float) -> NathanCharacterController:
	var path := "res://assets/characters/" + asset + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("Character asset missing: " + path)
		return null
	if not _model_cache.has(asset):
		_model_cache[asset] = load(path)
	var model: Node3D = (_model_cache[asset] as PackedScene).instantiate()
	CharacterMaterials.apply(model)
	var actor: NathanCharacterController = Actor.new()
	actor.name = asset.capitalize()
	actor.team = team_value
	actor.maximum_health = hp
	actor.actor_height = 1.95 if asset in ["nathan", "oz"] else 1.8
	actor.actor_radius = 0.36 if asset in ["nathan", "oz"] else 0.31
	actor.walk_speed = 2.0
	actor.run_speed = 3.55
	actor.ledge_hand_height = 2.12 if asset in ["nathan", "oz"] else 1.97
	actor.position = at
	actor.add_child(model)
	if asset == "nathan": model_root = model
	add_child(actor)
	actor.bind_model(model)
	return actor

func _spawn_enemy(asset: String, at: Vector3, hp := 85.0, boss := false) -> void:
	var enemy := _spawn_actor(asset, at, 1, hp)
	if enemy == null:
		return
	enemy.boss_armor = boss
	enemy.run_speed = 3.4 if boss else 3.8
	enemy.walk_speed = 1.7
	var brain := Brain.new()
	brain.target = player
	brain.arena = self
	brain.boss = boss
	enemy.add_child(brain)
	enemy.knocked_out.connect(_on_enemy_down)
	enemy.hit_landed.connect(_on_enemy_hit)
	enemies.append(enemy)

func _spawn_encounter() -> void:
	phase = 1
	var first := Vector3(5, 0.1, 17)
	if chapter > 1 and world.has_node("EncounterA"): first = (world.get_node("EncounterA") as Node3D).global_position + Vector3.UP * 0.1
	_spawn_enemy("thug", first)
	_spawn_enemy("thug", first + Vector3(4, 0, -3), 80 + 10 * chapter)
	if enemies.is_empty():
		objective.text = "АШДОД · СВОБОДНЫЙ ОСМОТР"
		hint.text = "WASD — движение · ПКМ — камера · пробел — паркур"
	else:
		objective.text = "НАБЕРЕЖНАЯ · РАЗБЕРИСЬ С ПРЕСЛЕДОВАТЕЛЯМИ"

func reserve_attack(actor: NathanCharacterController) -> bool:
	if attack_reservation > 0.0 and is_instance_valid(attack_owner) and attack_owner.health > 0.0:
		return attack_owner == actor
	attack_owner = actor
	attack_reservation = 1.15
	return true

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera_rig):
		return
	attack_reservation = maxf(0.0, attack_reservation - delta)
	_combo_time = maxf(0, _combo_time - delta)
	if _combo_time <= 0: _combo = 0
	_update_buffs(delta)
	var x := float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var y := float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	var direction: Vector2 = Vector2(x, y) + controls.movement
	player.camera_yaw = camera_rig.yaw
	player.set_move_input(direction, not Input.is_physical_key_pressed(KEY_SHIFT))
	camera_rig.set_running(player.state == &"run")
	step_clock += delta
	var pace := 0.32 if player.state == &"run" else 0.5
	if player.is_on_floor() and player.state in [&"walk", &"run"] and step_clock > pace:
		step_clock = 0.0
		sound.play("step", -21.0)
	if player.global_position.y < -8.0 and not _restarting:
		_on_player_down(player)
	ui_clock += delta
	if ui_clock > 0.25:
		ui_clock = 0.0
		_update_hint()
		_update_objective()
	if phase == 2 and player.global_position.z < -21.0:
		phase = 3
		var second := Vector3(3, 0.1, -31)
		if chapter > 1 and world.has_node("EncounterB"): second = (world.get_node("EncounterB") as Node3D).global_position + Vector3.UP * 0.1
		if chapter == 3: _spawn_enemy("oz", second, 320.0, true)
		else:
			_spawn_enemy("thug", second, 100.0)
			_spawn_enemy("thug", second + Vector3(4, 0, -3), 100.0)
	if phase == 4 and _route_complete() and player.global_position.distance_to(exit_position) < 3.0 and not _finished:
		_finished = true
		menu.show_result(true, chapter == 3)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_J: _action(&"punch")
		KEY_K: _action(&"kick")
		KEY_L: _action(&"grab")
		KEY_Q: _action(&"counter")
		KEY_E: _action(&"interact")
		KEY_SPACE: _action(&"parkour")
		KEY_CTRL: _action(&"dodge")
		KEY_B: menu.show_bag(inventory)
		KEY_C: _action(&"crouch")
		KEY_1: _use_item("v20")
		KEY_2: _use_item("v30")
		KEY_3: _use_item("weed")
		KEY_4: _use_item("ozempic")
		KEY_5: _use_item("shawarma")
		KEY_R:
			if _restarting: _change_chapter(chapter)
			elif rage >= 100.0:
				if player.request_action(&"fury"): rage = 0.0

func _action(action: StringName) -> void:
	if not _restarting and is_instance_valid(player) and player.health > 0.0:
		if action == &"fury":
			if rage >= 100.0 and player.request_action(action): rage = 0.0
		else: player.request_action(action)

func _on_state(_old: StringName, current: StringName) -> void:
	if current in [&"punch_1", &"punch_2", &"punch_3", &"kick", &"throw_prop"]:
		sound.play("whoosh", -17.0)
	if current in [&"throw", &"env_attacker"]:
		var target := player.nearest_enemy(3.0)
		if target: camera_rig.begin_pair(target)
	else:
		camera_rig.end_pair()

func _on_hit(_target: Node3D, _amount: float, kind: StringName) -> void:
	rage = minf(100, rage + 9)
	_combo += 1
	_combo_time = 2.0
	var heavy := kind in [&"kick", &"punch_3", &"throw", &"environment"]
	_hitstop_until = Time.get_ticks_msec() + (55 if heavy else 32)
	if not menu.reduced: Engine.time_scale = 0.18
	_impact(_target.global_position + Vector3.UP * 1.25)
	camera_rig.add_impact(0.045 if heavy else 0.022)
	sound.play("heavy" if heavy else "hit", -7.0)

func _on_enemy_hit(_target: Node3D, _amount: float, _kind: StringName) -> void:
	camera_rig.add_impact(0.025)
	sound.play("hit", -10.0)

func _on_health(value: float, maximum: float) -> void:
	health_bar.value = 100.0 * value / maximum

func _on_environment(_station: Node3D, _target: Node3D, _contact: Vector3) -> void:
	camera_rig.add_impact(0.08)
	sound.play("break", -6.0)

func _on_enemy_down(_actor: Node3D) -> void:
	total_defeated += 1
	tally.text = "%02d" % total_defeated
	var alive := 0
	for enemy: NathanCharacterController in enemies:
		if is_instance_valid(enemy) and enemy.health > 0.0: alive += 1
	if alive == 0:
		if phase == 1:
			phase = 2
		else:
			phase = 4
		_update_objective()

func _on_player_down(_actor: Node3D) -> void:
	if _restarting:
		return
	_restarting = true
	_reset_input()
	# knocked_out is emitted before this physics frame updates the animation.
	# Pausing here would freeze the previous upright pose. Let the actual
	# knockdown animation and ballistic body settle before freezing the scene.
	if player.health > 0.0:
		player.receive_hit(player.health, null, &"fall", true)
	await get_tree().create_timer(1.15, false, true).timeout
	menu.show_result(false)

func _update_hint() -> void:
	if _restarting:
		return
	if player.held_prop != null:
		hint.text = "E / L · " + menu.t("throw")
		return
	if player.state in [&"hang", &"shimmy"]:
		hint.text = "SPACE · " + menu.t("climb") + "    E · " + menu.t("drop")
		return
	for station: Node3D in get_tree().get_nodes_in_group("environment_stations"):
		if not bool(station.get_meta("broken", false)) and player.global_position.distance_to(station.global_position) < 3.2 and player.nearest_enemy(2.3):
			hint.text = "E · " + menu.t("fryer")
			return
	for prop: Node3D in get_tree().get_nodes_in_group("improvised_props"):
		if player.global_position.distance_to(prop.global_position) < 1.8:
			hint.text = "E · " + menu.t("pick")
			return
	hint.text = menu.t("controlsShort") if not controls.active else menu.t("pressure")

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	hud_root = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)
	var hud_back := Panel.new()
	hud_back.position = Vector2(16,14)
	hud_back.size = Vector2(465,112)
	hud_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.035,0.06,0.065,0.78)
	hud_style.set_corner_radius_all(5)
	hud_back.add_theme_stylebox_override("panel",hud_style)
	root.add_child(hud_back)
	identity_label = Label.new()
	var identity := identity_label
	identity.text = "N²   " + menu.t("nathan").to_upper()
	identity.position = Vector2(26, 22)
	identity.add_theme_font_size_override("font_size", 22)
	identity.add_theme_color_override("font_color", Color(0.97, 0.94, 0.85))
	identity.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	identity.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(identity)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(26, 55)
	health_bar.size = Vector2(170, 5)
	health_bar.value = 100
	health_bar.show_percentage = false
	health_bar.add_theme_font_size_override("font_size",1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.94, 0.36, 0.52)
	health_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.10, 0.11, 0.65)
	health_bar.add_theme_stylebox_override("background", bg)
	root.add_child(health_bar)
	objective = Label.new()
	objective.text = "АШДОД · НАБЕРЕЖНАЯ"
	objective.position = Vector2(26, 74)
	objective.add_theme_font_size_override("font_size", 13)
	objective.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	objective.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(objective)
	status_line = Label.new()
	status_line.position = Vector2(26, 98)
	status_line.add_theme_font_size_override("font_size", 12)
	status_line.add_theme_color_override("font_color", Color(0.96, 0.81, 0.62))
	root.add_child(status_line)
	tally = Label.new()
	tally.text = "00"
	tally.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tally.offset_left = -80
	tally.offset_right = -26
	tally.offset_top = 24
	tally.add_theme_font_size_override("font_size", 30)
	root.add_child(tally)
	hint = Label.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_left = 26
	hint.offset_right = -26
	hint.offset_top = -34
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(hint)
	controls = TouchControls.new()
	root.add_child(controls)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -85
	panel.offset_bottom = 85
	panel.visible = false
	root.add_child(panel)
	_on_menu_mode_changed(menu.mode)

func _on_menu_mode_changed(current: String) -> void:
	if is_instance_valid(hud_root): hud_root.visible = current.is_empty()
	if not current.is_empty() and is_instance_valid(controls): _reset_input()

func _message(title: String, subtitle: String) -> void:
	for child: Node in panel.get_children(): child.queue_free()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 25)
	box.add_child(label)
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	if _restarting:
		var button := Button.new()
		button.text = "ПОПРОБОВАТЬ СНОВА"
		button.pressed.connect(func() -> void: get_tree().reload_current_scene())
		box.add_child(button)
	panel.add_child(box)
	panel.visible = true

func _localize() -> void:
	if is_instance_valid(identity_label): identity_label.text = "N²   " + menu.t("nathan").to_upper()
	if not is_instance_valid(controls): return
	controls.localize(menu)
	_update_objective()
	if is_instance_valid(player): _update_hint()

func _settings(muted: bool, reduced: bool) -> void:
	AudioServer.set_bus_mute(0, muted)
	if is_instance_valid(camera_rig): camera_rig.reduced_motion = reduced

func _reset_input() -> void:
	controls.reset_input()
	if is_instance_valid(player): player.set_move_input(Vector2.ZERO)

func _change_chapter(value: int) -> void:
	var save := ConfigFile.new()
	save.set_value("campaign", "chapter", clampi(value, 1, 3))
	save.save("user://campaign.cfg")
	get_tree().paused = false
	get_tree().reload_current_scene()

func _route_complete() -> bool:
	for key in [&"jump", &"vault", &"climb", &"hang"]:
		if not route_done.has(key): return false
	return true

func _update_objective() -> void:
	if not is_instance_valid(objective): return
	var title: String = menu.t(["city", "forest", "factory"][chapter - 1])
	var task: String = menu.t("clear") if phase in [1, 3] else (menu.t("route") if not _route_complete() else menu.t("readyExit"))
	if chapter == 3 and phase == 3: task = menu.t("boss")
	objective.text = "%02d / %s · %s" % [chapter, title, task]
	status_line.text = "%s %d/4  ·  %s %d%%" % [menu.t("routeProgress"), route_done.size(), menu.t("rage"), int(rage)]
	if _combo > 1: status_line.text += "  ·  %s ×%d" % [menu.t("combo"), _combo]
	if buffs.weed > 0: status_line.text += "  ·  %s %ds" % [menu.t("weed"), int(buffs.weed)]
	if buffs.slim > 0: status_line.text += "  ·  %s %ds" % [menu.t("ozempic"), int(buffs.slim)]
	if buffs.power_time > 0: status_line.text += "  ·  +%d %ds" % [int(buffs.power), int(buffs.power_time)]
	if is_instance_valid(exit_marker): exit_marker.visible = phase == 4 and _route_complete()

func _use_item(item: String) -> void:
	if not is_instance_valid(player) or player.health <= 0 or inventory.get(item, 0) <= 0: return
	if item == "shawarma" and player.health >= player.maximum_health: return
	if not player.begin_item_use(StringName(item)): return
	var item_visual := preload("res://scripts/item_visual.gd").new()
	item_visual.actor = player
	item_visual.kind = item
	add_child(item_visual)
	inventory[item] -= 1
	match item:
		"v20", "v30":
			buffs.power = maxf(buffs.power, 30.0 if item == "v30" else 20.0)
			buffs.power_time = 120.0
		"weed": buffs.weed = 120.0
		"ozempic": buffs.slim = 120.0
		"shawarma":
			player.health = minf(player.maximum_health, player.health + 45.0)
			_on_health(player.health, player.maximum_health)

func _update_buffs(delta: float) -> void:
	for key in ["power_time", "weed", "slim"]: buffs[key] = maxf(0, float(buffs[key]) - delta)
	if buffs.power_time <= 0: buffs.power = 0.0
	player.damage_bonus = buffs.power
	player.damage_multiplier = 1.25 if buffs.weed > 0 else 1.0
	player.run_speed = 3.55 * (1.7 if buffs.slim > 0 else 1.0)
	player.walk_speed = 2.0 * (1.7 if buffs.slim > 0 else 1.0)
	if is_instance_valid(model_root):
		var width := 0.84 if buffs.slim > 0 else 1.0
		model_root.scale.x = move_toward(model_root.scale.x, width, delta * 0.4)
		model_root.scale.z = move_toward(model_root.scale.z, width, delta * 0.4)
	for enemy: NathanCharacterController in enemies:
		if is_instance_valid(enemy): enemy.ai_time_scale = 0.42 if buffs.weed > 0 else 1.0

func _city_route() -> void:
	# Coastal maintenance terraces: a low rail, a service deck and a high ledge.
	var route := Node3D.new()
	route.name = "PromenadeServiceTerraces"
	world.add_child(route)
	var wood: Material = world.mats.wood
	var stone: Material = world.mats.plaster
	world._box(route, Vector3(4, 0.72, 0.45), Vector3(3, 0.36, 7), wood, true)
	world._box(route, Vector3(4, 1.1, 3), Vector3(3, 0.55, -1), stone, true)
	world._box(route, Vector3(4, 2.15, 4), Vector3(3, 1.075, -10), stone, true)
	for z in [-1.0, -10.0]:
		var top := (1.1 if z == -1.0 else 2.15) - 0.055 * 0.5
		for i in range(8): world._box(route, Vector3(0.47, 0.055, 3.0 if z == -1.0 else 4.0), Vector3(1.25 + i * 0.5, top, z), wood)
	for at: Vector3 in [Vector3(3, 0.04, 10), Vector3(3, 0.04, 2), Vector3(3, 0.04, -6)]:
		world._box(route, Vector3(0.75, 0.035, 0.14), at, world.mats.yellow)

func _exit_beacon() -> void:
	exit_marker = Node3D.new()
	exit_marker.position = exit_position
	add_child(exit_marker)
	var text := Label3D.new()
	text.text = "↗"
	text.font_size = 100
	text.pixel_size = 0.012
	text.position.y = 2.3
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	text.modulate = Color(0.94, 0.61, 0.32)
	exit_marker.add_child(text)
	exit_marker.visible = false

func _process(_delta: float) -> void:
	if _hitstop_until > 0 and Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = 1.0
		_hitstop_until = 0

func _exit_tree() -> void:
	Engine.time_scale = 1.0

func _impact(at: Vector3) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = 9
	particles.lifetime = 0.15
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 80.0
	particles.initial_velocity_min = 0.8
	particles.initial_velocity_max = 2.4
	particles.gravity = Vector3(0, -1.5, 0)
	particles.scale_amount_min = 0.012
	particles.scale_amount_max = 0.025
	var mesh := SphereMesh.new()
	mesh.radius = 1
	mesh.height = 2
	mesh.radial_segments = 6
	mesh.rings = 3
	particles.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.87, 0.66)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particles.material_override = material
	add_child(particles)
	particles.global_position = at
	particles.emitting = true
	get_tree().create_timer(0.5).timeout.connect(particles.queue_free)
