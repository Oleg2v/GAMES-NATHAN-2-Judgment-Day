extends SceneTree
## Actual controller/physics fixtures; no visible substitute models or campaign claims.
const Actor = preload("res://scripts/character_controller.gd")
const Brain = preload("res://scripts/enemy_brain.gd")
var arena: ReservationArena
var oz: NathanCharacterController
var player: NathanCharacterController
var brain: Node
var checks: int = 0
var failures: int = 0
var phase_events: int = 0

class ReservationArena extends Node3D:
	var allow_attack: bool = true
	func reserve_attack(_actor: NathanCharacterController) -> bool:
		return allow_attack


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAILED: " + message)


func _frames(count: int) -> void:
	for index: int in range(count):
		await physics_frame


func _box(at: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.position = at
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	wall.add_child(collider)
	arena.add_child(wall)


func _setup(distance: float, reserve: bool = true) -> void:
	if is_instance_valid(arena):
		arena.queue_free()
		await _frames(2)
	arena = ReservationArena.new()
	arena.allow_attack = reserve
	root.add_child(arena)
	_box(Vector3(0, -0.1, 0), Vector3(40, 0.2, 40))
	oz = Actor.new()
	oz.team = 1
	oz.boss_armor = true
	oz.run_speed = 3.4
	oz.walk_speed = 1.7
	arena.add_child(oz)
	player = Actor.new()
	player.position = Vector3(0, 0, distance)
	player.rotation.y = PI
	arena.add_child(player)
	await _frames(5)
	brain = Brain.new()
	brain.boss = true
	brain.target = player
	brain.arena = arena
	brain.cooldown = 0.0
	oz.add_child(brain)


func _until_pattern(pattern: StringName, limit: int = 180) -> bool:
	for index: int in range(limit):
		if brain.boss_pattern == pattern:
			return true
		await physics_frame
	return false


func _side_dodge() -> void:
	player.camera_yaw = 0.0
	player.set_move_input(Vector2.RIGHT, true)
	_check(player.request_action(&"dodge"), "The real controller accepts a sidestep dodge")
	player.set_move_input(Vector2.ZERO)


func _run() -> void:
	await _setup(4.0)
	await _frames(8)
	_check(oz.has_node("BossHUD") and brain._boss_name.text == "OZ · I  160 / 160", "Only Oz receives a readable name, phase and health display")
	_check(brain.boss_pattern == &"windup" and brain.alert.visible and brain.alert.text == ">>", "Rush has a visible cue before movement")
	_check(oz.position.length() < 0.08 and is_equal_approx(player.health, 160.0), "Windup neither moves into nor damages the target")
	_side_dodge()
	_check(await _until_pattern(&"rush"), "Telegraphed rush commits")
	var rush_speed: float = oz.run_speed
	_check(rush_speed > 5.0, "Rush uses a short accelerated run through the controller")
	_check(await _until_pattern(&"recovery"), "A missed rush has a recovery window")
	_check(absf(oz.position.x) < 0.08 and oz.position.z > 1.0, "Rush stays on the committed line after the player sidesteps")
	_check(is_equal_approx(player.health, 160.0), "A lateral dodge avoids the rushed attack")
	_check(not oz.boss_armor and is_equal_approx(oz.run_speed, 3.4), "Recovery removes armor and restores ordinary speed")
	player.position = oz.position + Vector3(0, 0, 1.2)
	player.rotation.y = PI
	player.velocity = Vector3.ZERO
	_check(player.request_action(&"punch"), "Player can punish the recovery window")
	await _frames(18)
	_check(oz.health < 160.0 and oz.state == &"hit", "Recovery permits actual damage and hit reaction")
	await _frames(75)
	_check(oz.boss_armor, "Temporary vulnerability restores the original armor")

	await _setup(1.2)
	await _frames(8)
	_check(brain.intent == &"grab" and brain.alert.text == "<>", "Close grapple has a distinct readable telegraph")
	_side_dodge()
	_check(await _until_pattern(&"recovery"), "An evaded grab enters recovery")
	_check(player._held_by == null and is_equal_approx(player.health, 160.0), "Dodge avoids the real paired grapple")

	await _setup(1.2)
	var held: bool = false
	for index: int in range(100):
		await physics_frame
		if player.state == &"held":
			held = true
			break
	_check(held and oz.state == &"throw", "Stationary nearby player enters the controller's paired throw")
	await _frames(48)
	_check(is_equal_approx(player.health, 122.0) and player.state == &"knockdown", "Paired throw releases with exactly the controller's 38 damage")
	_check(player._held_by == null and player.position.z > 1.0 and player.velocity.z > 2.0, "Throw releases ownership and uses a physical trajectory")

	await _setup(4.0)
	_check(await _until_pattern(&"attack"), "A rush reaching an undodged target commits a real kick")
	await _frames(25)
	_check(is_equal_approx(player.health, 133.0), "Undodged rush deals the controller's 27 kick damage")
	await _frames(35)
	_check(is_equal_approx(player.health, 133.0), "Rush contact cannot damage repeatedly")

	await _setup(4.0)
	_check(await _until_pattern(&"attack"), "Counter fixture reaches the rushed strike")
	await _frames(8)
	_check(player.request_action(&"counter"), "Player can time a counter during the rushed strike")
	await _frames(16)
	_check(player.health == 160.0 and oz.health == 136.0, "Timed counter defeats the rush and damages Oz")
	_check(brain.boss_pattern == &"recovery" and is_equal_approx(oz.run_speed, 3.4), "Counter interruption gives recovery and restores speed")

	await _setup(4.0)
	brain.boss_phase_changed.connect(func(_phase: int) -> void: phase_events += 1)
	brain.cooldown = 1.0
	oz.receive_hit(81.0, player, &"counter", true)
	_check(brain._boss_name.text.contains("79 / 160") and brain._boss_health_fill.size.x < 0.53, "health_changed immediately updates numeric HP and bar fill")
	_check(await _until_pattern(&"phase"), "Crossing half health triggers the visible phase transition")
	_check(brain.boss_phase == 2 and phase_events == 1 and brain.alert.text == "!!", "Enrage is announced once after half health")
	_check(brain._boss_name.text.contains("OZ · II"), "The health display shows the actual second phase")
	_check(await _until_pattern(&"rush", 240), "Enraged Oz resumes attacks after the transition")
	_check(oz.run_speed > rush_speed, "Phase two strengthens the rush without inventing a clip")
	_check(phase_events == 1, "Low health does not retrigger the transition each frame")

	await _setup(4.0, false)
	await _frames(100)
	_check(brain.boss_pattern == &"" and player.health == 160.0, "Denied arena reservation prevents all boss attacks")

	await _setup(4.0)
	_box(Vector3(0, 1, 1.7), Vector3(4, 2, 0.3))
	_check(await _until_pattern(&"recovery"), "Blocked rush gives a recovery opening")
	_check(oz.position.z < 1.25 and player.health == 160.0, "Rush respects a real wall and cannot damage through it")
	_check(is_equal_approx(oz.run_speed, 3.4), "Wall interruption restores the ordinary speed")

	await _setup(4.0)
	_check(await _until_pattern(&"rush"), "Cleanup fixture enters the temporary rush")
	player.queue_free()
	await _frames(3)
	_check(is_equal_approx(oz.run_speed, 3.4) and oz._move_input == Vector2.ZERO, "Losing the target cancels movement and temporary speed")
	var ordinary := Actor.new()
	arena.add_child(ordinary)
	var ordinary_brain := Brain.new()
	ordinary.add_child(ordinary_brain)
	_check(not ordinary.has_node("BossHUD"), "Ordinary opponents do not receive boss HUD clutter")

	arena.queue_free()
	await _frames(2)
	print("BOSS_BEHAVIOR_TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
