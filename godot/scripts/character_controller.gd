class_name NathanCharacterController
extends CharacterBody3D
const ContactModifier = preload("res://scripts/character_contact.gd")
## Collision and action controller for an imported, rigged character.
## This script never creates a visible character or substitutes missing clips.
## World bodies: layer 1. Character bodies: layer 2. Models face local +Z.

signal state_changed(previous: StringName, current: StringName)
signal health_changed(current: float, maximum: float)
signal hit_landed(target: Node3D, amount: float, kind: StringName)
signal knocked_out(character: Node3D)
signal parkour_completed(kind: StringName)
signal environment_hit(station: Node3D, target: Node3D, contact: Vector3)
signal animation_missing(clip: StringName)
signal action_rejected(action: StringName, reason: StringName)

const GROUND_STATES: Array[StringName] = [&"idle", &"walk", &"run", &"crouch"]
const ATTACKS: Dictionary = {
	&"punch_1": {"duration": 0.48, "contact": 0.20, "damage": 17.0, "reach": 1.65},
	&"punch_2": {"duration": 0.50, "contact": 0.22, "damage": 19.0, "reach": 1.70},
	&"punch_3": {"duration": 0.66, "contact": 0.30, "damage": 25.0, "reach": 1.85},
	&"kick": {"duration": 0.76, "contact": 0.33, "damage": 27.0, "reach": 2.15},
	&"fury": {"duration": 1.10, "contact": 0.40, "damage": 65.0, "reach": 3.6}
}

@export var keyboard_enabled: bool = false
@export var team: int = 0
@export var maximum_health: float = 160.0
@export var boss_armor: bool = false
@export var damage_bonus: float = 0.0
@export var damage_multiplier: float = 1.0
@export var ai_time_scale: float = 1.0
@export var walk_speed: float = 2.2
@export var run_speed: float = 5.0
@export var acceleration: float = 18.0
@export var gravity_strength: float = 18.0
@export var jump_speed: float = 7.0
@export var actor_radius: float = 0.34
@export var actor_height: float = 1.8
@export var ledge_hand_height: float = 1.97
@export var animation_aliases: Dictionary = {}
@export var model_path: NodePath

var health: float = 160.0
var state: StringName = &"idle"
var state_time: float = 0.0
var state_duration: float = 0.0
var camera_yaw: float = 0.0
var invulnerable_time: float = 0.0
var pair_phase: float = 0.0
var pair_contact := Vector3.ZERO
var held_prop: RigidBody3D
var _move_input := Vector2.ZERO
var _wants_run: bool = true
var _buffered_action: StringName = &""
var _buffer_lifetime: float = 0.0
var _combo_step: int = 0
var _combo_lifetime: float = 0.0
var _strike_resolved: bool = false
var _hit_targets: Dictionary = {}
var _pair: Dictionary = {}
var _held_by: NathanCharacterController
var _traversal: Dictionary = {}
var _body_shape: CapsuleShape3D
var _collision_shape: CollisionShape3D
var _contact_modifier: SkeletonModifier3D
var _compact_capsule: bool = false
var _animation_player: AnimationPlayer
var _animation_tree: AnimationTree
var _action_node: AnimationNodeAnimation
var _action_blend: float = 0.0
var _missing_clips: Dictionary = {}
var _rig: Skeleton3D
var _right_hand: BoneAttachment3D
var _projectiles: Array[Dictionary] = []
var item_pose: StringName = &""

func begin_item_use(kind: StringName) -> bool:
	if health <= 0 or not state in GROUND_STATES or is_instance_valid(held_prop):
		return false
	if not kind in [&"v20", &"v30", &"weed", &"ozempic", &"shawarma"]:
		return false
	item_pose = kind
	# The body uses the authored idle clip; the existing post-animation
	# two-bone solver creates an explicit short hand-to-item gesture.
	animation_aliases[&"use_item"] = &"idle"
	_change_state(&"use_item", 1.05)
	return true


func _ready() -> void:
	health = maximum_health
	add_to_group("combatants")
	collision_layer = 2
	collision_mask = 3
	floor_snap_length = 0.18
	floor_max_angle = deg_to_rad(48.0)
	_body_shape = CapsuleShape3D.new()
	_body_shape.radius = actor_radius
	_body_shape.height = actor_height
	var collider := CollisionShape3D.new()
	_collision_shape = collider
	collider.name = "CharacterCapsule"
	collider.shape = _body_shape
	collider.position.y = actor_height * 0.5
	add_child(collider)
	if not model_path.is_empty():
		var model: Node = get_node_or_null(model_path)
		if model != null:
			bind_model(model)


func bind_model(model: Node) -> void:
	_animation_player = _find_animation_player(model)
	_rig = _find_skeleton(model)
	if is_instance_valid(_rig):
		_contact_modifier = ContactModifier.new()
		_contact_modifier.actor = self
		_rig.add_child(_contact_modifier)
		for index: int in range(_rig.get_bone_count()):
			var bone_name: String = _rig.get_bone_name(index).to_lower()
			if ("hand" in bone_name or "wrist" in bone_name) and ("right" in bone_name or bone_name.ends_with(".r") or bone_name.ends_with("_r")):
				_right_hand = BoneAttachment3D.new()
				_right_hand.name = "HeldPropSocket"
				_right_hand.bone_name = _rig.get_bone_name(index)
				_rig.add_child(_right_hand)
				break
	if not is_instance_valid(_animation_player):
		_report_missing(&"AnimationPlayer")
		return
	# glTF does not encode loop playback; exact contract names lack a _Loop suffix.
	for loop_name: StringName in [&"idle", &"walk", &"run", &"fall", &"hang", &"shimmy"]:
		var mapped: StringName = StringName(animation_aliases.get(loop_name, loop_name))
		if _animation_player.has_animation(mapped):
			_animation_player.get_animation(mapped).loop_mode = Animation.LOOP_LINEAR
	if is_instance_valid(_animation_tree):
		_animation_tree.queue_free()
	var idle_clip: StringName = _resolve_clip(&"idle")
	if idle_clip.is_empty():
		return
	var walk_clip: StringName = _resolve_clip(&"walk")
	var run_clip: StringName = _resolve_clip(&"run")
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = run_speed
	locomotion.add_blend_point(_clip_node(idle_clip), 0.0, -1, &"idle")
	if not walk_clip.is_empty():
		locomotion.add_blend_point(_clip_node(walk_clip), walk_speed, -1, &"walk")
	if not run_clip.is_empty():
		locomotion.add_blend_point(_clip_node(run_clip), run_speed, -1, &"run")
	var tree := AnimationNodeBlendTree.new()
	tree.add_node(&"Locomotion", locomotion)
	_action_node = _clip_node(idle_clip)
	tree.add_node(&"Action", _action_node)
	tree.add_node(&"ActionSeek", AnimationNodeTimeSeek.new())
	tree.add_node(&"ActionSpeed", AnimationNodeTimeScale.new())
	tree.add_node(&"ActionBlend", AnimationNodeBlend2.new())
	tree.add_node(&"RuntimeSpeed", AnimationNodeTimeScale.new())
	tree.connect_node(&"ActionSeek", 0, &"Action")
	tree.connect_node(&"ActionSpeed", 0, &"ActionSeek")
	tree.connect_node(&"ActionBlend", 0, &"Locomotion")
	tree.connect_node(&"ActionBlend", 1, &"ActionSpeed")
	tree.connect_node(&"RuntimeSpeed", 0, &"ActionBlend")
	tree.connect_node(&"output", 0, &"RuntimeSpeed")
	_animation_tree = AnimationTree.new()
	_animation_tree.name = "CharacterAnimationTree"
	_animation_tree.tree_root = tree
	add_child(_animation_tree)
	_animation_tree.anim_player = _animation_tree.get_path_to(_animation_player)
	_animation_tree.root_node = _animation_tree.get_path_to(_animation_player.get_node(_animation_player.root_node))
	_animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	_animation_tree.active = true


func set_move_input(direction: Vector2, running: bool = true) -> void:
	_move_input = direction.limit_length()
	_wants_run = running


func facing() -> Vector3:
	return global_basis.z.normalized()


func request_action(action: StringName) -> bool:
	if health <= 0.0:
		return false
	if state in [&"hang", &"shimmy"]:
		if action in [&"parkour", &"jump"]:
			return _pull_up()
		if action in [&"interact", &"drop", &"dodge"]:
			_drop_ledge()
			return true
	if not state in GROUND_STATES:
		if ATTACKS.has(state) and state_time > state_duration * 0.35 and action in [&"punch", &"kick", &"dodge", &"counter"]:
			_buffered_action = action
			_buffer_lifetime = 0.3
			return true
		return false
	if state == &"crouch" and action != &"crouch" and not _capsule_clear(self, global_position):
		return _reject(action, &"standing_space_blocked")
	match action:
		&"crouch":
			if state == &"crouch":
				if not _capsule_clear(self, global_position):
					return _reject(action, &"standing_space_blocked")
				_change_state(&"idle")
			else:
				_change_state(&"crouch")
				var crouch_height: float = maxf(actor_radius * 2.0, actor_height - 0.32)
				_set_capsule_profile({"height": crouch_height, "radius": actor_radius, "center": crouch_height * 0.5})
			return true
		&"punch", &"kick", &"fury":
			var target: NathanCharacterController = nearest_enemy(2.6)
			if target != null:
				_face_point(target.global_position)
			var attack: StringName = action
			if action == &"punch":
				attack = StringName("punch_%d" % (_combo_step + 1))
				_combo_step = (_combo_step + 1) % 3
				_combo_lifetime = 1.4
			_change_state(attack, float(ATTACKS[attack]["duration"]))
			return true
		&"counter":
			_change_state(&"counter", 0.44)
			return true
		&"dodge":
			if _move_input.length() > 0.1:
				_face_direction(_input_direction())
			_change_state(&"dodge", 0.38)
			invulnerable_time = 0.30
			return true
		&"jump", &"parkour":
			if held_prop != null:
				return _reject(action, &"hands_occupied")
			if action == &"parkour" and _try_parkour():
				return true
			velocity.y = jump_speed
			_change_state(&"jump")
			return true
		&"grab", &"throw":
			if is_instance_valid(held_prop):
				_change_state(&"throw_prop", 0.62)
				return true
			return begin_grapple(nearest_enemy(1.8))
		&"interact":
			if is_instance_valid(held_prop):
				_change_state(&"throw_prop", 0.62)
				return true
			var target: NathanCharacterController = nearest_enemy(2.3)
			if target != null:
				for station: Node in get_tree().get_nodes_in_group("environment_stations"):
					if station is Node3D and not bool(station.get_meta("broken", false)) and global_position.distance_to(station.global_position) < 3.2:
						if begin_environment(target, station):
							return true
			return _pickup_prop()
	return false


func _physics_process(delta: float) -> void:
	delta *= clampf(ai_time_scale, 0.05, 2.0)
	if _compact_capsule and not state in [&"vault", &"crouch"]:
		_restore_capsule()
	if is_instance_valid(_held_by):
		_update_animation(delta)
		return
	state_time += delta
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	_combo_lifetime = maxf(0.0, _combo_lifetime - delta)
	if _combo_lifetime == 0.0:
		_combo_step = 0
	_buffer_lifetime = maxf(0.0, _buffer_lifetime - delta)
	if _buffer_lifetime == 0.0:
		_buffered_action = &""
	if keyboard_enabled:
		_poll_keyboard()
	var was_grounded: bool = is_on_floor()
	if not _pair.is_empty():
		_update_pair()
	elif state == &"held":
		velocity = Vector3.ZERO
	elif state in [&"vault", &"climb", &"ledge_grab"]:
		_update_traversal()
	elif state in [&"hang", &"shimmy"]:
		_update_hang(delta)
	else:
		if state in GROUND_STATES:
			_update_locomotion(delta)
		elif state in [&"jump", &"fall"]:
			var direction: Vector3 = _input_direction()
			velocity.x = move_toward(velocity.x, direction.x * run_speed * 0.8, acceleration * 0.35 * delta)
			velocity.z = move_toward(velocity.z, direction.z * run_speed * 0.8, acceleration * 0.35 * delta)
			if velocity.y < 0.0 and state != &"fall":
				_change_state(&"fall")
		elif state == &"dodge":
			velocity.x = facing().x * 7.5
			velocity.z = facing().z * 7.5
		elif state != &"knockdown":
			velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
			velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if not is_on_floor():
			velocity.y -= gravity_strength * delta
		elif velocity.y < 0.0:
			velocity.y = -0.4
		var impact_speed: float = Vector2(velocity.x, velocity.z).length()
		var rate: float = clampf(ai_time_scale, 0.05, 2.0)
		velocity *= rate
		move_and_slide()
		velocity /= rate
		if state == &"knockdown" and impact_speed > 2.0:
			for collision_index: int in range(get_slide_collision_count()):
				var body: Object = get_slide_collision(collision_index).get_collider()
				if body is NathanCharacterController and not _hit_targets.has(body.get_instance_id()):
					_hit_targets[body.get_instance_id()] = true
					body.receive_hit(32.0, self, &"throw")
		if not was_grounded and is_on_floor():
			if state in [&"jump", &"fall"]:
				_change_state(&"land", 0.22)
				parkour_completed.emit(&"jump")
			elif state == &"knockdown":
				velocity = Vector3.ZERO
		if was_grounded and not is_on_floor() and state in GROUND_STATES:
			_change_state(&"fall")
	_resolve_strike()
	if state == &"throw_prop" and not _strike_resolved and state_time >= 0.24:
		_strike_resolved = true
		_release_prop(true)
	if state == &"knockdown" and state_time >= state_duration and is_on_floor() and health > 0.0:
		_change_state(&"getup", 0.75)
	elif state_duration > 0.0 and state_time >= state_duration and not state in [&"held", &"knockdown", &"vault", &"climb", &"ledge_grab"] and _pair.is_empty():
		_change_state(&"idle")
		_consume_buffer()
	elif ATTACKS.has(state) and state_time >= state_duration * 0.72 and not _buffered_action.is_empty():
		_change_state(&"idle")
		_consume_buffer()
	_update_held_prop()
	_update_projectiles(delta)
	_update_animation(delta)


func _update_locomotion(delta: float) -> void:
	var direction: Vector3 = _input_direction()
	var speed: float = run_speed if _wants_run else walk_speed
	if state == &"crouch":
		speed = 1.0
	velocity.x = move_toward(velocity.x, direction.x * speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, acceleration * delta)
	if direction.length() > 0.05:
		var angle: float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, angle, minf(1.0, delta * 12.0))
	var next: StringName = &"idle" if direction.length() < 0.05 else (&"run" if _wants_run else &"walk")
	if state == &"crouch":
		next = &"crouch"
	if next != state:
		_change_state(next)


func _input_direction() -> Vector3:
	return Vector3(_move_input.x, 0.0, -_move_input.y).rotated(Vector3.UP, camera_yaw)


func _change_state(next: StringName, duration: float = 0.0) -> void:
	var previous: StringName = state
	state = next
	state_time = 0.0
	state_duration = duration
	if previous in [&"vault", &"crouch"] and not next in [&"vault", &"crouch"]:
		_restore_capsule()
	_strike_resolved = false
	_hit_targets.clear()
	if not next in GROUND_STATES:
		_play_action_clip(next)
	state_changed.emit(previous, next)


func _consume_buffer() -> void:
	var action: StringName = _buffered_action
	_buffered_action = &""
	if not action.is_empty():
		request_action(action)


func nearest_enemy(reach: float) -> NathanCharacterController:
	var nearest: NathanCharacterController
	var distance: float = reach
	for node: Node in get_tree().get_nodes_in_group("combatants"):
		if node == self or not node is NathanCharacterController:
			continue
		var other := node as NathanCharacterController
		var current: float = global_position.distance_to(other.global_position)
		if other.team != team and other.health > 0.0 and other._held_by == null and current < distance and _line_clear(other):
			nearest = other
			distance = current
	return nearest


func _resolve_strike() -> void:
	if not ATTACKS.has(state) or _strike_resolved:
		return
	var attack: Dictionary = ATTACKS[state]
	var attack_damage: float = (float(attack["damage"]) + damage_bonus) * damage_multiplier
	if state_time < float(attack["contact"]):
		return
	_strike_resolved = true
	for node: Node in get_tree().get_nodes_in_group("combatants"):
		if node == self or not node is NathanCharacterController:
			continue
		var target := node as NathanCharacterController
		var offset: Vector3 = target.global_position - global_position
		if target.team == team or target.health <= 0.0 or absf(offset.y) > 1.1 or offset.length() > float(attack["reach"]):
			continue
		if (state == &"fury" or facing().dot(offset.normalized()) > 0.35) and _line_clear(target):
			if target.receive_hit(attack_damage, self, state):
				hit_landed.emit(target, attack_damage, state)
	for prop: Node in get_tree().get_nodes_in_group("improvised_props"):
		if prop is Node3D and prop.has_method("receive_damage"):
			var offset: Vector3 = prop.global_position - global_position
			if offset.length() < float(attack["reach"]) and facing().dot(offset.normalized()) > 0.3:
				prop.call("receive_damage", attack_damage, self)


func receive_hit(amount: float, source: NathanCharacterController, kind: StringName = &"punch", bypass_guard: bool = false) -> bool:
	if health <= 0.0 or (invulnerable_time > 0.0 and not bypass_guard):
		return false
	if state in [&"vault", &"climb", &"ledge_grab"] and not bypass_guard:
		return false
	if state == &"crouch" and String(kind).begins_with("punch") and not bypass_guard:
		return false
	if not bypass_guard and state == &"counter" and state_time <= 0.28 and is_instance_valid(source):
		var direction: Vector3 = source.global_position - global_position
		if facing().dot(direction.normalized()) > -0.15:
			invulnerable_time = 0.35
			source.receive_hit(24.0, self, &"counter", true)
			_play_action_clip(&"counter")
			return false
	_cancel_pairs()
	_release_prop(false)
	_buffered_action = &""
	health = maxf(0.0, health - amount)
	invulnerable_time = 0.24
	health_changed.emit(health, maximum_health)
	var armored: bool = boss_armor and health > 0.0 and not state in [&"hit", &"recover"] and not kind in [&"environment", &"throw", &"prop", &"counter", &"fury"]
	if health <= 0.0:
		var away: Vector3 = (global_position - source.global_position).normalized() if is_instance_valid(source) else -facing()
		launch(away * 2.0 + Vector3.UP * 2.0)
		knocked_out.emit(self)
	elif not armored:
		_change_state(&"hit", 0.43)
		if is_instance_valid(source):
			var away: Vector3 = global_position - source.global_position
			away.y = 0.0
			velocity = away.normalized() * (3.0 if kind == &"kick" else 1.4)
	return true


func launch(impulse: Vector3) -> void:
	_held_by = null
	_traversal.clear()
	_change_state(&"knockdown", 0.95)
	velocity = impulse
	invulnerable_time = maxf(invulnerable_time, 0.18)


func begin_grapple(target: NathanCharacterController) -> bool:
	if not _can_grab(target):
		return false
	_face_point(target.global_position)
	var destination: Vector3 = global_position + facing() * 0.84
	if not _capsule_path_clear(target, target.global_position, destination, self):
		return _reject(&"grab", &"obstructed")
	_pair = {"target": target, "kind": &"throw", "victim_from": target.global_position, "victim_to": destination, "player_from": global_position}
	_change_state(&"throw", 1.12)
	target._held_by = self
	add_collision_exception_with(target)
	target.add_collision_exception_with(self)
	target._change_state(&"held", 1.12)
	target.velocity = Vector3.ZERO
	return true


func begin_environment(target: NathanCharacterController, station: Node3D) -> bool:
	if not _can_grab(target) or bool(station.get_meta("broken", false)):
		return false
	var approach := station.get_node_or_null("Approach") as Node3D
	var contact := station.get_node_or_null("Contact") as Node3D
	if approach == null or contact == null:
		return _reject(&"environment", &"station_markers_missing")
	var basis: Basis = approach.global_basis.orthonormalized()
	# Side-by-side feet permit a human torso/arm reach to the basin. Standing
	# behind a victim more than 1m from it makes hand/head contact unreachable.
	var player_to: Vector3 = approach.global_position + basis.x * 0.74 - basis.z * 0.24
	var victim_to: Vector3 = approach.global_position - basis.z * 0.24
	# Counters have different depths. Find the closest legal feet positions,
	# otherwise the same Approach offset can put a head beyond anatomical reach.
	for advance: float in [0.72, 0.68, 0.64, 0.60, 0.56, 0.52, 0.48, 0.44, 0.40, 0.36, 0.32, 0.28, 0.24]:
		var candidate_victim: Vector3 = approach.global_position - basis.z * advance
		var candidate_player: Vector3 = candidate_victim + basis.x * 0.74
		if _capsule_clear(target, candidate_victim, self) and _capsule_clear(self, candidate_player, target):
			player_to = candidate_player
			victim_to = candidate_victim
			break
	if not _capsule_path_clear(target, target.global_position, victim_to, self):
		return _reject(&"environment", &"obstructed")
	var initial: Vector3 = global_position - target.global_position
	var final: Vector3 = player_to - victim_to
	var start_angle: float = atan2(initial.x, initial.z)
	var delta_angle: float = wrapf(atan2(final.x, final.z) - start_angle, -PI, PI)
	var arc: Dictionary = {}
	for turn: float in [delta_angle, delta_angle + (-TAU if delta_angle > 0.0 else TAU)]:
		var free: bool = true
		for index: int in range(41):
			var t: float = index / 40.0
			var radius: float = lerpf(initial.length(), final.length(), t)
			var angle: float = start_angle + turn * t
			var point: Vector3 = target.global_position.lerp(victim_to, t) + Vector3(sin(angle), 0.0, cos(angle)) * radius
			if radius < actor_radius + target.actor_radius or not _capsule_clear(self, point, target):
				free = false
				break
		if free:
			arc = {"angle": start_angle, "turn": turn, "from_radius": initial.length(), "to_radius": final.length()}
			break
	if arc.is_empty():
		return _reject(&"environment", &"obstructed")
	_pair = {"target": target, "kind": &"environment", "station": station, "contact": contact.global_position, "victim_from": target.global_position, "victim_to": victim_to, "arc": arc, "facing": -basis.z}
	_change_state(&"env_attacker", 1.65)
	target._held_by = self
	add_collision_exception_with(target)
	target.add_collision_exception_with(self)
	target._change_state(&"env_victim", 1.65)
	target.velocity = Vector3.ZERO
	return true


func _can_grab(target: NathanCharacterController) -> bool:
	if target == null or target.health <= 0.0 or not _pair.is_empty() or is_instance_valid(held_prop) or not state in GROUND_STATES:
		return false
	if target.global_position.distance_to(global_position) > 2.35 or not _line_clear(target):
		return false
	if target._held_by != null or target.state in [&"vault", &"climb", &"hang", &"shimmy"]:
		return false
	return not target.boss_armor or target.health <= target.maximum_health * 0.35 or target.state in [&"hit", &"recover"]


func _update_pair() -> void:
	var target: NathanCharacterController = _pair.get("target") as NathanCharacterController
	if not is_instance_valid(target) or health <= 0.0 or target.health <= 0.0:
		_cancel_pairs()
		return
	var phase: float = clampf(state_time / state_duration, 0.0, 1.0)
	pair_phase = phase
	target.pair_phase = phase
	target.state_time = state_time
	if _pair["kind"] == &"environment":
		var u: float = smoothstep(0.0, 0.30, phase)
		var victim: Vector3 = (_pair["victim_from"] as Vector3).lerp(_pair["victim_to"], u)
		var arc: Dictionary = _pair["arc"]
		var angle: float = float(arc["angle"]) + float(arc["turn"]) * u
		var radius: float = lerpf(float(arc["from_radius"]), float(arc["to_radius"]), u)
		var player_to: Vector3 = victim + Vector3(sin(angle), 0.0, cos(angle)) * radius
		if not _move_pair_member(target, victim) or not _move_pair_member(self, player_to):
			_cancel_pairs()
			return
		if global_position.distance_to(target.global_position) < actor_radius + target.actor_radius - 0.01:
			_cancel_pairs()
			return
		_face_direction(_pair["facing"])
		target._face_direction(_pair["facing"])
		pair_contact = _pair["contact"]
		target.pair_contact = pair_contact
		if phase >= 0.62:
			var station: Node3D = _pair["station"] as Node3D
			_pair.clear()
			_clear_pair_collision(target)
			target._held_by = null
			target.receive_hit(95.0, self, &"environment", true)
			if is_instance_valid(station):
				station.set_meta("broken", true)
				if station.has_method("break_station"):
					station.call("break_station")
				environment_hit.emit(station, target, pair_contact)
			target.launch(facing() * 3.2 + Vector3.UP * 3.0)
	else:
		var u: float = smoothstep(0.0, 0.22, phase)
		var destination: Vector3 = (_pair["victim_from"] as Vector3).lerp(_pair["victim_to"], u)
		destination.y += sin(clampf((phase - 0.18) / 0.46, 0.0, 1.0) * PI * 0.65) * 0.72
		if not _move_pair_member(target, destination):
			_cancel_pairs()
			return
		target._face_direction(-facing())
		if phase >= 0.64:
			_pair.clear()
			_clear_pair_collision(target)
			target._held_by = null
			target.receive_hit(38.0, self, &"throw", true)
			target.launch(facing() * 6.5 + Vector3.UP * 4.3)


func _move_pair_member(actor: NathanCharacterController, destination: Vector3) -> bool:
	actor.move_and_collide(destination - actor.global_position)
	return actor.global_position.distance_to(destination) < 0.06


func _clear_pair_collision(target: NathanCharacterController) -> void:
	if is_instance_valid(target):
		remove_collision_exception_with(target)
		target.remove_collision_exception_with(self)


func _cancel_pairs() -> void:
	if not _pair.is_empty():
		var target: NathanCharacterController = _pair.get("target") as NathanCharacterController
		_pair.clear()
		if is_instance_valid(target):
			_clear_pair_collision(target)
			target._held_by = null
			target.launch(Vector3.ZERO)
	if is_instance_valid(_held_by):
		var holder: NathanCharacterController = _held_by
		_clear_pair_collision(holder)
		_held_by = null
		holder._pair.clear()
		holder._change_state(&"recover", 0.35)
	pair_phase = 0.0


func _try_parkour() -> bool:
	var origin: Vector3 = global_position
	var forward: Vector3 = facing()
	var wall: Dictionary = _ray(origin + Vector3.UP * 0.65, origin + Vector3.UP * 0.65 + forward * 1.25)
	if wall.is_empty():
		return false
	var wall_point: Vector3 = wall["position"]
	var top: Dictionary = _ray(Vector3(wall_point.x, origin.y + 2.7, wall_point.z) + forward * 0.15, Vector3(wall_point.x, origin.y + 0.3, wall_point.z) + forward * 0.15)
	if top.is_empty() or (top["normal"] as Vector3).y < 0.85:
		return false
	var top_point: Vector3 = top["position"]
	var height: float = top_point.y - origin.y
	var destination: Vector3 = top_point + forward * 0.50 + Vector3.UP * 0.025
	var kind: StringName = &"climb"
	var duration: float = 1.05
	if height <= 1.0:
		kind = &"vault"
		duration = 0.85
		var found_landing: bool = false
		for step: int in range(3, 14):
			var candidate: Vector3 = wall_point + forward * (step * 0.2)
			var ground: Dictionary = _ray(Vector3(candidate.x, top_point.y + 0.1, candidate.z), Vector3(candidate.x, origin.y - 0.4, candidate.z))
			if not ground.is_empty() and float((ground["position"] as Vector3).y) < top_point.y - 0.15:
				# Keep the full standing radius clear when the compact vault
				# capsule expands; the broad clearance probe has solver margins.
				destination = ground["position"] + forward * 0.04 + Vector3.UP * 0.025
				if _capsule_clear(self, destination):
					found_landing = true
					break
		if not found_landing:
			return false
	elif height > 1.5:
		if height > 2.5:
			return false
		kind = &"ledge_grab"
		duration = 0.58
		destination = Vector3(wall_point.x, top_point.y - ledge_hand_height, wall_point.z) - forward * (actor_radius + 0.055)
	if not _capsule_clear(self, destination):
		return false
	var hand_contact := Vector3(wall_point.x, top_point.y, wall_point.z) + forward * 0.025
	_traversal = {"from": origin, "to": destination, "top": top_point, "hand_contact": hand_contact, "forward": forward, "kind": kind, "collider": wall["collider"]}
	if not _traversal_path_clear(kind):
		_traversal.clear()
		return false
	velocity = Vector3.ZERO
	_change_state(kind, duration)
	return true


func _traversal_point(kind: StringName, phase: float) -> Vector3:
	var origin: Vector3 = _traversal["from"]
	var destination: Vector3 = _traversal["to"]
	if kind == &"climb":
		var lift: float = smoothstep(0.0, 0.58, phase)
		var across: float = smoothstep(0.52, 1.0, phase)
		return Vector3(lerpf(origin.x, destination.x, across), lerpf(origin.y, destination.y + 0.10, lift) - 0.10 * across, lerpf(origin.z, destination.z, across))
	if kind == &"vault":
		var point: Vector3 = origin.lerp(destination, smoothstep(0.18, 0.82, phase))
		point.y += sin(phase * PI) * 0.16
		return point
	return origin.lerp(destination, smoothstep(0.0, 1.0, phase))


func _vault_profile(phase: float, root_point: Vector3) -> Dictionary:
	var amount: float = smoothstep(0.0, 0.18, phase) * (1.0 - smoothstep(0.82, 1.0, phase))
	var height: float = lerpf(actor_height, actor_height * 0.64, amount)
	var radius: float = lerpf(actor_radius, minf(actor_radius, 0.30), amount)
	var lifted_center: float = float((_traversal["top"] as Vector3).y) + 0.04 + height * 0.5 - root_point.y
	return {"height": height, "radius": radius, "center": lerpf(actor_height * 0.5, lifted_center, amount)}


func _set_capsule_profile(profile: Dictionary) -> void:
	_body_shape.height = float(profile["height"])
	_body_shape.radius = float(profile["radius"])
	_collision_shape.position.y = float(profile["center"])
	_compact_capsule = true


func _restore_capsule() -> void:
	if not is_instance_valid(_collision_shape) or not _capsule_clear(self, global_position):
		return
	_body_shape.height = actor_height
	_body_shape.radius = actor_radius
	_collision_shape.position.y = actor_height * 0.5
	_compact_capsule = false


func _traversal_path_clear(kind: StringName) -> bool:
	for index: int in range(1, 41):
		var phase: float = index / 40.0
		var point: Vector3 = _traversal_point(kind, phase)
		var profile: Dictionary = _vault_profile(phase, point) if kind == &"vault" else {}
		if not _capsule_clear(self, point, null, profile):
			return false
	return true


func _update_traversal() -> void:
	if _traversal.is_empty() or not is_instance_valid(_traversal["collider"]):
		_drop_ledge()
		return
	var phase: float = clampf(state_time / state_duration, 0.0, 1.0)
	var destination: Vector3 = _traversal_point(state, phase)
	if state == &"vault":
		_set_capsule_profile(_vault_profile(phase, destination))
	move_and_collide(destination - global_position)
	if global_position.distance_to(destination) > 0.08:
		_drop_ledge()
		return
	if phase >= 1.0:
		if state == &"ledge_grab":
			_change_state(&"hang")
		else:
			parkour_completed.emit(&"hang" if _traversal.get("from_hang", false) else state)
			_traversal.clear()
			_change_state(&"land", 0.2)


func _update_hang(delta: float) -> void:
	if _traversal.is_empty() or not is_instance_valid(_traversal["collider"]):
		_drop_ledge()
		return
	var sideways: Vector3 = global_basis.x * _move_input.x * 1.1 * delta
	var next: Vector3 = global_position + sideways
	var wall: Dictionary = _ray(next + Vector3.UP * 1.4, next + Vector3.UP * 1.4 + facing() * 0.65)
	if not wall.is_empty() and wall["collider"] == _traversal["collider"] and _capsule_clear(self, next):
		move_and_collide(sideways)
	var next_state: StringName = &"shimmy" if absf(_move_input.x) > 0.1 else &"hang"
	if state != next_state:
		_change_state(next_state)


func _pull_up() -> bool:
	if _traversal.is_empty():
		return false
	var top: Vector3 = _traversal["top"]
	_traversal["from"] = global_position
	_traversal["to"] = Vector3(global_position.x, top.y + 0.025, global_position.z) + facing() * 0.75
	_traversal["from_hang"] = true
	if not _traversal_path_clear(&"climb"):
		return false
	_change_state(&"climb", 1.10)
	return true


func _drop_ledge() -> void:
	_traversal.clear()
	velocity = -facing() * 0.65 + Vector3.DOWN * 0.4
	_change_state(&"fall")


func _pickup_prop() -> bool:
	var nearest: RigidBody3D
	var distance: float = 1.8
	for node: Node in get_tree().get_nodes_in_group("improvised_props"):
		if node is RigidBody3D and not bool(node.get_meta("broken", false)) and not bool(node.get_meta("held", false)):
			var current: float = global_position.distance_to(node.global_position)
			if current < distance:
				nearest = node
				distance = current
	if nearest == null:
		return false
	held_prop = nearest
	held_prop.set_meta("held", true)
	held_prop.set_meta("original_layer", held_prop.collision_layer)
	held_prop.set_meta("original_mask", held_prop.collision_mask)
	held_prop.freeze = true
	held_prop.collision_layer = 0
	held_prop.collision_mask = 0
	_change_state(&"grab", 0.45)
	return true


func _update_held_prop() -> void:
	if not is_instance_valid(held_prop):
		return
	if is_instance_valid(_right_hand):
		held_prop.global_transform = _right_hand.global_transform
	else:
		held_prop.global_position = global_position + Vector3.UP * 1.05 + facing() * 0.5


func _release_prop(thrown: bool) -> void:
	if not is_instance_valid(held_prop):
		return
	var prop: RigidBody3D = held_prop
	held_prop = null
	prop.set_meta("held", false)
	prop.freeze = false
	prop.collision_layer = int(prop.get_meta("original_layer", 4))
	prop.collision_mask = int(prop.get_meta("original_mask", 3))
	prop.global_position = global_position + Vector3.UP * 1.15 + facing() * 0.75
	prop.linear_velocity = facing() * (9.0 if thrown else 0.0) + Vector3.UP * (2.8 if thrown else 0.0)
	prop.angular_velocity = global_basis.x * 7.0
	if thrown:
		_projectiles.append({"prop": prop, "remaining": 2.0, "hits": {}})


func _update_projectiles(delta: float) -> void:
	for index: int in range(_projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = _projectiles[index]
		var prop: RigidBody3D = projectile["prop"] as RigidBody3D
		projectile["remaining"] = float(projectile["remaining"]) - delta
		if not is_instance_valid(prop) or float(projectile["remaining"]) <= 0.0:
			_projectiles.remove_at(index)
			continue
		for node: Node in get_tree().get_nodes_in_group("combatants"):
			if node is NathanCharacterController and node != self and node.team != team and not projectile["hits"].has(node.get_instance_id()):
				if prop.global_position.distance_to(node.global_position + Vector3.UP * 0.9) < 0.8 and prop.linear_velocity.length() > 1.2:
					projectile["hits"][node.get_instance_id()] = true
					node.receive_hit(48.0, self, &"prop")


func _capsule_clear(actor: NathanCharacterController, foot: Vector3, excluded_actor: NathanCharacterController = null, profile: Dictionary = {}) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = float(profile.get("radius", actor.actor_radius)) - 0.012
	shape.height = float(profile.get("height", actor.actor_height)) - 0.04
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, foot + Vector3.UP * (float(profile.get("center", actor.actor_height * 0.5)) + 0.015))
	query.collision_mask = 3
	var excluded: Array[RID] = [actor.get_rid()]
	if excluded_actor != null:
		excluded.append(excluded_actor.get_rid())
	query.exclude = excluded
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _capsule_path_clear(actor: NathanCharacterController, from: Vector3, to: Vector3, excluded_actor: NathanCharacterController = null) -> bool:
	var steps: int = maxi(2, int(ceil(from.distance_to(to) / 0.1)))
	for index: int in range(1, steps + 1):
		if not _capsule_clear(actor, from.lerp(to, index / float(steps)), excluded_actor):
			return false
	return true


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query)


func _line_clear(other: Node3D) -> bool:
	return _ray(global_position + Vector3.UP * 0.95, other.global_position + Vector3.UP * 0.95).is_empty()


func _face_point(point: Vector3) -> void:
	_face_direction(point - global_position)


func _face_direction(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() > 0.001:
		rotation.y = atan2(direction.x, direction.z)


func bone_anchor(name: String) -> Vector3:
	if is_instance_valid(_contact_modifier) and _contact_modifier.anchors.has(name):
		return _contact_modifier.anchors[name]
	if is_instance_valid(_rig):
		var index: int = _rig.find_bone(name)
		if index >= 0:
			return _rig.global_transform * _rig.get_bone_global_pose(index).origin
	return global_position + Vector3.UP * 1.35


func contact_targets() -> Dictionary:
	if state == &"use_item":
		var phase := clampf(state_time / 1.05,0,1)
		var weight := smoothstep(0.0,0.28,phase)*(1.0-smoothstep(0.74,1.0,phase))
		var to_mouth := item_pose in [&"shawarma", &"weed"]
		var right_goal := Vector3(0.04,1.69,0.38) if to_mouth else Vector3(0.18,1.22,0.57)
		var left_goal := Vector3(0.33,1.15,0.58)
		# Sweep out around the torso before bringing the item in front. Direct
		# rest-to-contact interpolation would cut the forearm through the shirt.
		var reach := smoothstep(0.16,0.42,phase)*(1.0-smoothstep(0.68,0.9,phase))
		right_goal = Vector3(-0.62,1.10,0.30).lerp(right_goal,reach)
		left_goal = Vector3(0.62,1.10,0.30).lerp(left_goal,reach)
		var targets := {"weight":weight,"right_hand":global_transform*right_goal,"torso_lean":0.02,"feet_lock":true,"r_elbow_pole":global_transform*Vector3(-0.70,1.15,0.48),"l_elbow_pole":global_transform*Vector3(0.70,1.10,0.48)}
		if not to_mouth: targets["left_hand"] = global_transform*left_goal
		return targets
	if state == &"crouch":
		return {"weight": 1.0, "pelvis_shift": Vector3.DOWN * 0.32, "torso_lean": 0.20, "feet_lock": true}
	if state == &"env_victim" and is_instance_valid(_held_by):
		var weight: float = smoothstep(0.28, 0.55, pair_phase)
		return {"head": pair_contact, "weight": weight, "pelvis_shift": facing() * 0.28, "feet_lock": true}
	if not _pair.is_empty() and state in [&"env_attacker", &"throw"]:
		var target: NathanCharacterController = _pair["target"] as NathanCharacterController
		if not is_instance_valid(target):
			return {}
		var toward: Vector3 = target.global_position - global_position
		toward.y = 0.0
		var weight: float = smoothstep(0.12, 0.28, pair_phase)
		if state == &"env_attacker":
			var near_hand: Vector3 = target.bone_anchor("head") + Vector3.UP * 0.12 - target.facing() * 0.07
			var contact_hand: Vector3 = pair_contact - target.facing() * 0.18 + Vector3.UP * 0.04
			near_hand = near_hand.lerp(contact_hand, smoothstep(0.28, 0.55, pair_phase))
			var near_shoulder: String = "upperarm_l" if (-toward).dot(target.global_basis.x) > 0.0 else "upperarm_r"
			var far_hand: Vector3 = target.bone_anchor(near_shoulder) - target.facing() * 0.06 - toward.normalized() * 0.03
			var left_near: bool = toward.dot(global_basis.x) > 0.0
			return {"left_hand": near_hand if left_near else far_hand, "right_hand": far_hand if left_near else near_hand, "weight": weight, "pelvis_shift": facing() * 0.24 + toward.normalized() * 0.18, "torso_lean": 0.20, "feet_lock": true}
		var chest: Vector3 = target.bone_anchor("spine_03")
		return {"left_hand": chest + global_basis.x * 0.18, "right_hand": chest - global_basis.x * 0.18, "weight": weight, "pelvis_shift": facing() * 0.12, "torso_lean": 0.15, "feet_lock": true}
	if not _traversal.is_empty() and state in [&"vault", &"climb", &"ledge_grab", &"hang", &"shimmy"]:
		var center: Vector3 = _traversal.get("hand_contact", _traversal["top"])
		center += global_basis.x * (global_position - center).dot(global_basis.x)
		var phase: float = clampf(state_time / maxf(0.01, state_duration), 0.0, 1.0)
		var weight: float = 1.0
		var shift: Vector3 = facing() * 0.08
		var lean: float = 0.0
		if state == &"vault":
			weight = smoothstep(0.10, 0.24, phase) * (1.0 - smoothstep(0.44, 0.53, phase))
			shift = Vector3.DOWN * 0.18 + facing() * 0.04
			lean = 0.65
		elif state == &"climb":
			weight = 1.0 - smoothstep(0.20, 0.38, phase)
		elif state == &"ledge_grab":
			weight = smoothstep(0.15, 0.80, phase)
		return {"left_hand": center + global_basis.x * 0.23, "right_hand": center - global_basis.x * 0.23, "weight": weight, "pelvis_shift": shift, "torso_lean": lean, "feet_lock": state == &"vault"}
	return {}


func _reject(action: StringName, reason: StringName) -> bool:
	action_rejected.emit(action, reason)
	return false


func _clip_node(clip: StringName) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = clip
	return node


func _resolve_clip(requested: StringName) -> StringName:
	var resolved: StringName = StringName(animation_aliases.get(requested, requested))
	if requested == &"fury" and is_instance_valid(_animation_player) and not _animation_player.has_animation(resolved) and _animation_player.has_animation(&"punch_3"):
		resolved = &"punch_3"
	if is_instance_valid(_animation_player) and _animation_player.has_animation(resolved):
		return resolved
	_report_missing(requested)
	return &""


func _report_missing(clip: StringName) -> void:
	if not _missing_clips.has(clip):
		_missing_clips[clip] = true
		animation_missing.emit(clip)
		push_warning("Character requires authored animation: %s" % clip)


func _play_action_clip(action: StringName) -> void:
	if not is_instance_valid(_animation_tree):
		return
	var clip: StringName = _resolve_clip(action)
	if clip.is_empty():
		_action_blend = 0.0
		return
	_action_node.animation = clip
	_animation_tree.set("parameters/ActionSeek/seek_request", 0.0)
	var clip_length: float = _animation_player.get_animation(clip).length
	_animation_tree.set("parameters/ActionSpeed/scale", clip_length / state_duration if state_duration > 0.0 else 1.0)


func _update_animation(delta: float) -> void:
	if not is_instance_valid(_animation_tree):
		return
	var desired: float = 0.0 if state in GROUND_STATES or _missing_clips.has(state) else 1.0
	_action_blend = move_toward(_action_blend, desired, delta * 12.0)
	_animation_tree.set("parameters/ActionBlend/blend_amount", _action_blend)
	_animation_tree.set("parameters/Locomotion/blend_position", Vector2(velocity.x, velocity.z).length())
	var animation_rate: float = _held_by.ai_time_scale if is_instance_valid(_held_by) else ai_time_scale
	_animation_tree.set("parameters/RuntimeSpeed/scale", clampf(animation_rate, 0.05, 2.0))


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child: Node in node.get_children():
		var result: AnimationPlayer = _find_animation_player(child)
		if result != null:
			return result
	return null


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child: Node in node.get_children():
		var result: Skeleton3D = _find_skeleton(child)
		if result != null:
			return result
	return null


func _poll_keyboard() -> void:
	var x: float = float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A))
	var z: float = float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S))
	set_move_input(Vector2(x, z), not Input.is_physical_key_pressed(KEY_SHIFT))


func _unhandled_input(event: InputEvent) -> void:
	if not keyboard_enabled or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_J: request_action(&"punch")
		KEY_K: request_action(&"kick")
		KEY_L: request_action(&"grab")
		KEY_Q: request_action(&"counter")
		KEY_C: request_action(&"crouch")
		KEY_E: request_action(&"interact")
		KEY_SPACE: request_action(&"parkour")
		KEY_CTRL: request_action(&"dodge")
