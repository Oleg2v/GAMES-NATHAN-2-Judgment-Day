extends Node
## Spacing, visible wind-up, limited simultaneous attacks and recovery windows.
signal boss_pattern_changed(pattern: StringName)
signal boss_phase_changed(phase: int)

var actor: NathanCharacterController
var target: NathanCharacterController
var arena: Node
var cooldown := 1.5
var windup := 0.0
var intent: StringName = &"punch"
var orbit_side := 1.0
var alert: Label3D
var boss := false
var decision_time := 0.0
var boss_phase: int = 1
var boss_pattern: StringName = &""
var _boss_timer: float = 0.0
var _locked_direction := Vector3.FORWARD
var _rush_origin := Vector3.ZERO
var _rush_cooldown: float = 0.0
var _grab_cooldown: float = 0.0
var _saved_run_speed: float = 0.0
var _speed_overridden: bool = false
var _saved_armor: bool = false
var _armor_overridden: bool = false
var _after_attack_recovery: float = 0.75
var _melee_count: int = 0
var _boss_hud: Node3D
var _boss_name: Label3D
var _boss_health_fill: QuadMesh
var _boss_health_material: StandardMaterial3D

func _ready() -> void:
	actor = get_parent() as NathanCharacterController
	orbit_side = -1.0 if actor.get_index() % 2 == 0 else 1.0
	alert = Label3D.new()
	alert.position.y = 2.25
	alert.text = "!"
	alert.font_size = 70
	alert.pixel_size = 0.006
	alert.modulate = Color(1.0, 0.68, 0.29)
	alert.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert.no_depth_test = true
	alert.visible = false
	actor.add_child(alert)
	if boss:
		_build_boss_hud()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		if is_instance_valid(actor):
			actor.set_move_input(Vector2.ZERO, false)
		_restore_boss_overrides()
		if is_instance_valid(alert):
			alert.visible = false
		boss_pattern = &""
		return
	actor.set_move_input(Vector2.ZERO, false)
	alert.visible = false
	if actor.health <= 0.0 or target.health <= 0.0:
		_restore_boss_overrides()
		boss_pattern = &""
		return
	delta *= clampf(actor.ai_time_scale, 0.05, 2.0)
	cooldown = maxf(0.0, cooldown - delta)
	decision_time += delta
	var offset := target.global_position - actor.global_position
	offset.y = 0.0
	var distance := offset.length()
	actor.camera_yaw = 0.0
	if boss:
		_update_boss(delta, offset.normalized(), distance)
		return
	if distance > 26.0 or distance < 0.001:
		return
	if not actor.state in actor.GROUND_STATES:
		windup = 0.0
		return
	var direction := offset / distance
	if windup > 0.0:
		windup -= delta
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(direction.x, direction.z), delta * 12.0)
		alert.visible = true
		if windup <= 0.0:
			actor.request_action(intent)
			cooldown = 1.9
		return
	if distance > 1.65:
		_approach(direction, distance)
	elif cooldown <= 0.0 and (arena == null or arena.call("reserve_attack", actor)):
		intent = &"punch"
		windup = 0.72
	else:
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(direction.x, direction.z), delta * 6.0)
		if distance < 1.15:
			actor.set_move_input(Vector2(-direction.x, direction.z) * 0.45, false)


func _update_boss(delta: float, direction: Vector3, distance: float) -> void:
	_rush_cooldown = maxf(0.0, _rush_cooldown - delta)
	_grab_cooldown = maxf(0.0, _grab_cooldown - delta)
	if boss_pattern == &"recovery":
		_show_cue("...", Color(0.5, 0.8, 1.0))
		_boss_timer -= delta
		if _boss_timer <= 0.0:
			_restore_boss_overrides()
			_set_pattern(&"")
		return
	if boss_pattern == &"attack":
		if actor.state in actor.GROUND_STATES:
			_enter_recovery(_after_attack_recovery)
		elif not actor.state in actor.ATTACKS and actor.state != &"throw":
			_enter_recovery(0.9)
		return
	if not actor.state in actor.GROUND_STATES:
		if not boss_pattern.is_empty():
			_enter_recovery(0.9)
		return
	if boss_pattern == &"phase":
		_show_cue("!!", Color(1.0, 0.25, 0.13))
		_boss_timer -= delta
		if _boss_timer <= 0.0:
			_enter_recovery(0.3)
		return
	if boss_pattern == &"rush":
		_update_rush(delta)
		return
	if boss_pattern == &"windup":
		_show_cue(">>" if intent == &"rush" else ("<>" if intent == &"grab" else "!"), Color(1.0, 0.36, 0.2) if boss_phase == 2 else Color(1.0, 0.68, 0.29))
		# Commit direction at the start of the cue; a sidestep must stay a sidestep.
		actor.rotation.y = atan2(_locked_direction.x, _locked_direction.z)
		_boss_timer -= delta
		if _boss_timer <= 0.0:
			if not _reserve_attack():
				_enter_recovery(0.7)
			elif intent == &"rush":
				_start_rush()
			elif intent == &"grab":
				# The controller's grapple does not reject dodge invulnerability.
				# Only commit while the victim remains grounded in the telegraphed arc.
				var evading: bool = target.state in [&"dodge", &"jump", &"fall", &"vault", &"climb", &"hang", &"shimmy", &"ledge_grab"] or target.invulnerable_time > 0.0
				if not evading and distance <= 1.6 and direction.dot(_locked_direction) > 0.65:
					_commit_attack(&"grab", 1.1)
				else:
					_enter_recovery(1.0)
			else:
				_commit_attack(intent, 0.75)
		return
	if distance > 26.0 or distance < 0.001:
		return
	if boss_phase == 1 and actor.health < actor.maximum_health * 0.5:
		boss_phase = 2
		boss_phase_changed.emit(boss_phase)
		_update_boss_health(actor.health, actor.maximum_health)
		_open_armor_window()
		_boss_timer = 1.0
		_set_pattern(&"phase")
		_show_cue("!!", Color(1.0, 0.25, 0.13))
		return
	if cooldown <= 0.0:
		if distance >= 2.3 and distance <= 6.5 and _rush_cooldown <= 0.0 and _reserve_attack():
			_rush_cooldown = 4.5 if boss_phase == 2 else 5.5
			_begin_windup(&"rush", direction, 0.65 if boss_phase == 2 else 0.85)
			return
		if distance <= 1.65 and _reserve_attack():
			if distance <= 1.5 and _grab_cooldown <= 0.0:
				_grab_cooldown = 5.0
				_begin_windup(&"grab", direction, 0.68 if boss_phase == 2 else 0.82)
			else:
				_melee_count += 1
				_begin_windup(&"kick" if _melee_count % 2 == 0 else &"punch", direction, 0.5 if boss_phase == 2 else 0.65)
			return
	if distance > 1.65:
		_approach(direction, distance)
	else:
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(direction.x, direction.z), minf(1.0, delta * 6.0))


func _begin_windup(action: StringName, direction: Vector3, duration: float) -> void:
	intent = action
	_locked_direction = direction.normalized()
	_boss_timer = duration
	_set_pattern(&"windup")
	_show_cue(">>" if action == &"rush" else ("<>" if action == &"grab" else "!"), Color(1.0, 0.68, 0.29))


func _start_rush() -> void:
	_saved_run_speed = actor.run_speed
	_speed_overridden = true
	actor.run_speed = 6.3 if boss_phase == 2 else 5.7
	_rush_origin = actor.global_position
	_boss_timer = 0.68
	_set_pattern(&"rush")


func _update_rush(delta: float) -> void:
	_boss_timer -= delta
	var offset: Vector3 = target.global_position - actor.global_position
	offset.y = 0.0
	var forward: float = offset.dot(_locked_direction)
	var sideways: float = (offset - _locked_direction * forward).length()
	actor.rotation.y = atan2(_locked_direction.x, _locked_direction.z)
	if forward > 0.25 and forward < 1.8 and sideways < 0.65 and _reserve_attack():
		_restore_speed()
		_commit_attack(&"kick", 1.15)
		return
	if _boss_timer <= 0.0 or actor.global_position.distance_to(_rush_origin) > 3.8 or _obstacle_ahead(_locked_direction, 0.8):
		_enter_recovery(1.15)
		return
	actor.set_move_input(Vector2(_locked_direction.x, -_locked_direction.z), true)


func _commit_attack(action: StringName, recovery: float) -> void:
	actor.set_move_input(Vector2.ZERO, false)
	_restore_speed()
	if actor.request_action(action):
		# request_action auto-faces a nearby enemy; preserve this attack's cue arc.
		# The paired grapple keeps the controller's exact victim alignment.
		if action != &"grab":
			actor.rotation.y = atan2(_locked_direction.x, _locked_direction.z)
		_after_attack_recovery = recovery
		cooldown = 0.9 if boss_phase == 2 else 1.35
		_set_pattern(&"attack")
	else:
		_enter_recovery(recovery)


func _enter_recovery(duration: float) -> void:
	_restore_speed()
	actor.set_move_input(Vector2.ZERO, false)
	_open_armor_window()
	_boss_timer = duration
	cooldown = maxf(cooldown, duration + 0.25)
	_set_pattern(&"recovery")


func _open_armor_window() -> void:
	if not _armor_overridden:
		_saved_armor = actor.boss_armor
		_armor_overridden = true
	actor.boss_armor = false


func _restore_speed() -> void:
	if _speed_overridden and is_instance_valid(actor):
		actor.run_speed = _saved_run_speed
	_speed_overridden = false


func _restore_boss_overrides() -> void:
	_restore_speed()
	if _armor_overridden and is_instance_valid(actor):
		actor.boss_armor = _saved_armor
	_armor_overridden = false


func _set_pattern(pattern: StringName) -> void:
	if boss_pattern != pattern:
		boss_pattern = pattern
		boss_pattern_changed.emit(pattern)


func _show_cue(text: String, color: Color) -> void:
	alert.text = text
	alert.modulate = color
	alert.visible = true


func _build_boss_hud() -> void:
	_boss_hud = Node3D.new()
	_boss_hud.name = "BossHUD"
	_boss_hud.position.y = 2.53
	actor.add_child(_boss_hud)
	_boss_name = Label3D.new()
	_boss_name.position.y = 0.16
	_boss_name.font_size = 32
	_boss_name.pixel_size = 0.0045
	_boss_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_boss_name.no_depth_test = true
	_boss_name.outline_size = 7
	_boss_hud.add_child(_boss_name)
	var background := MeshInstance3D.new()
	var backdrop := QuadMesh.new()
	backdrop.size = Vector2(1.12, 0.09)
	background.mesh = backdrop
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dark.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dark.no_depth_test = true
	dark.albedo_color = Color(0.035, 0.045, 0.06)
	background.material_override = dark
	_boss_hud.add_child(background)
	var foreground := MeshInstance3D.new()
	_boss_health_fill = QuadMesh.new()
	foreground.mesh = _boss_health_fill
	_boss_health_material = dark.duplicate() as StandardMaterial3D
	_boss_health_material.render_priority = 1
	foreground.material_override = _boss_health_material
	_boss_hud.add_child(foreground)
	actor.health_changed.connect(_update_boss_health)
	_update_boss_health(actor.health, actor.maximum_health)


func _update_boss_health(current: float, maximum: float) -> void:
	if not is_instance_valid(_boss_hud):
		return
	_boss_hud.visible = current > 0.0
	var ratio: float = clampf(current / maxf(1.0, maximum), 0.0, 1.0)
	var width: float = maxf(0.002, 1.06 * ratio)
	_boss_health_fill.size = Vector2(width, 0.045)
	# Offset vertices inside the billboard, so the left edge stays fixed at
	# every camera angle instead of moving along world X when the bar shrinks.
	_boss_health_fill.center_offset = Vector3((width - 1.06) * 0.5, 0.0, 0.005)
	_boss_health_material.albedo_color = Color(1.0, 0.24, 0.16) if boss_phase == 2 else Color(1.0, 0.65, 0.25)
	_boss_name.text = "OZ · %s  %d / %d" % ["II" if boss_phase == 2 else "I", ceili(current), ceili(maximum)]


func _reserve_attack() -> bool:
	return arena == null or bool(arena.call("reserve_attack", actor))


func _obstacle_ahead(direction: Vector3, reach: float) -> bool:
	var start: Vector3 = actor.global_position + Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(start, start + direction * reach, 1)
	return not actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _approach(direction: Vector3, distance: float) -> void:
	var desired := direction
	for other: Node in get_tree().get_nodes_in_group("combatants"):
		if other == actor or other == target or not other is Node3D:
			continue
		var away: Vector3 = actor.global_position - (other as Node3D).global_position
		away.y = 0.0
		if away.length() > 0.02 and away.length() < 1.65:
			desired += away.normalized() * (1.65 - away.length())
	if _obstacle_ahead(desired.normalized(), 1.1):
		desired = Vector3(-direction.z, 0.0, direction.x) * orbit_side
	actor.set_move_input(Vector2(desired.x, -desired.z).normalized(), distance > 7.0)


func _exit_tree() -> void:
	_restore_boss_overrides()
