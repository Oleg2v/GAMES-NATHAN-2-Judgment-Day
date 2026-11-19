extends SceneTree
const Menu = preload("res://scripts/game_menu.gd")
const Game = preload("res://scripts/waterfront_game.gd")

# Exercise the production HUD without loading models or any world geometry.
class UIHost extends Game:
	func _ready() -> void:
		menu=Menu.new()
		add_child(menu)
		menu.mode_changed.connect(_on_menu_mode_changed)
		menu.language_changed.connect(_localize)
		menu.resumed.connect(_reset_input)
		_build_ui()
	func _physics_process(_delta: float) -> void:
		pass

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label)

func _run() -> void:
	var game := UIHost.new()
	root.add_child(game)
	await process_frame
	var menu: CanvasLayer=game.menu
	game.controls.active=true
	game.controls._layout()
	for screen in ["main","pause","help","settings","bag","complete","victory","defeat","rotate"]:
		game.controls.movement=Vector2(0,1)
		game.controls.stick_id=2
		menu.mode=screen
		for control in [game.identity_label,game.health_bar,game.objective,game.status_line,game.tally,game.hint,game.controls]:
			_check(not control.is_visible_in_tree(),screen+" hides "+str(control.get_class()))
		_check(game.controls.movement==Vector2.ZERO and game.controls.stick_id==-1,screen+" resets held touches")
		_check(not menu._browser_state().playing,screen+" tells HTML the game is not playing")
	menu.mode=""
	_check(game.hud_root.is_visible_in_tree(),"Gameplay restores the complete HUD")
	_check(menu._browser_state().playing,"Gameplay tells HTML to hide install UI")
	for code in ["ru","en","he"]:
		menu.language=code
		menu.language_changed.emit()
		_check(game.identity_label.text=="N²   "+menu.t("nathan").to_upper(),"Localized identity "+code)
		_check(menu._browser_state().lang==code,"HTML language "+code)
	menu.language="';throw new Error('unsafe')//"
	_check(menu.language=="ru" and not menu._browser_state_script().contains("unsafe"),"Stored language is allowlisted before JS serialization")
	print(JSON.stringify({"suite":"menu_hud","checks":checks,"errors":failures}))
	paused=false
	quit(0 if failures.is_empty() else 1)
