extends Node
func _ready() -> void:
	var mode := "game"
	if OS.has_feature("web"):
		var requested: Variant = JavaScriptBridge.eval("new URLSearchParams(location.search).get('view') || 'game'")
		if requested is String: mode = requested
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--view="): mode = arg.trim_prefix("--view=")
	var path := "res://scenes/waterfront_game.tscn"
	if mode == "environment": path = "res://scenes/ashdod_review.tscn"
	if mode in ["character", "oz"]: path = "res://scenes/character_review.tscn"
	if mode in ["forest", "factory"]:
		var environment: Node = load("res://scripts/campaign_environment.gd").new()
		environment.set("chapter", 2 if mode == "forest" else 3)
		environment.set("review_camera_enabled", true)
		get_tree().root.add_child.call_deferred(environment)
		get_tree().set_deferred("current_scene", environment)
		queue_free()
		return
	var scene: Node = (load(path) as PackedScene).instantiate()
	if mode in ["character", "oz"]:
		scene.set("model_path", "res://assets/characters/%s.glb" % ("oz" if mode == "oz" else "nathan"))
	get_tree().root.add_child.call_deferred(scene)
	get_tree().set_deferred("current_scene", scene)
	queue_free()
