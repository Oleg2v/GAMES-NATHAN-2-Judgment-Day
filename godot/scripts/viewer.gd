extends Node3D
const CharacterMaterials = preload("res://scripts/character_materials.gd")
## Review a real glTF/GLB character without replacing its geometry or materials.
## Launch: godot --path game-godot -- --model="C:/assets/nathan.glb"

@export_file("*.glb", "*.gltf") var model_path: String = ""

var _camera: Camera3D
var _model_origin: Node3D
var _file_dialog: FileDialog
var _status: Label
var _asset_name: Label
var _empty_panel: CenterContainer
var _animation_menu: OptionButton
var _animation_players: Array[AnimationPlayer] = []
var _animation_entries: Array[Dictionary] = []
var _body_target := Vector3(0.0, 1.0, 0.0)
var _head_target := Vector3(0.0, 1.8, 0.0)
var _target := Vector3(0.0, 1.0, 0.0)
var _distance: float = 4.5
var _yaw: float = 0.0
var _pitch: float = 0.05
var _orbiting: bool = false
var _panning: bool = false
var _turntable: bool = false
var _has_model: bool = false
var _active_animation: AnimationPlayer


func _ready() -> void:
	_build_stage()
	_build_ui()
	get_viewport().files_dropped.connect(_files_dropped)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(args.size()):
		if args[index].begins_with("--model="):
			model_path = args[index].trim_prefix("--model=")
		elif args[index] == "--model" and index + 1 < args.size():
			model_path = args[index + 1]
		elif not args[index].begins_with("-") and args[index].get_extension().to_lower() in ["glb", "gltf"]:
			model_path = args[index]
	if not model_path.is_empty():
		load_model(model_path)
	_update_camera()


func _build_stage() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.075, 0.085)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.88, 0.90, 0.94)
	environment.ambient_light_energy = 0.28
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	_add_light(Vector3(-42.0, -30.0, 0.0), Color(1.0, 0.97, 0.93), 0.75, true)
	_add_light(Vector3(-18.0, 125.0, 0.0), Color(0.84, 0.90, 1.0), 0.12, false)
	_add_light(Vector3(-32.0, 180.0, 0.0), Color(1.0, 1.0, 1.0), 0.18, false)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "NeutralFloor"
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.005
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.07, 0.09, 0.10)
	floor_material.roughness = 0.85
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	_camera = Camera3D.new()
	_camera.name = "ReviewCamera"
	_camera.fov = 35.0
	_camera.near = 0.015
	_camera.far = 250.0
	add_child(_camera)
	_camera.make_current()


func _add_light(angles: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = angles
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadows
	add_child(light)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root_control)
	var top_panel := PanelContainer.new()
	top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_panel.offset_left = 20.0
	top_panel.offset_top = 20.0
	top_panel.offset_right = -20.0
	top_panel.add_theme_stylebox_override("panel", _panel_style())
	root_control.add_child(top_panel)
	var top_column := VBoxContainer.new()
	top_column.add_theme_constant_override("separation", 10)
	top_panel.add_child(top_column)
	var heading := HBoxContainer.new()
	top_column.add_child(heading)
	_asset_name = Label.new()
	_asset_name.text = "NATHAN / CHARACTER REVIEW"
	_asset_name.add_theme_font_size_override("font_size", 20)
	_asset_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_asset_name)
	var import_button := Button.new()
	import_button.text = "Import GLB…"
	import_button.pressed.connect(_open_dialog)
	heading.add_child(import_button)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	top_column.add_child(toolbar)
	for item: Array in [["1  Body", 1], ["2  Face", 2], ["3  Side", 3], ["4  Back", 4]]:
		var view_button := Button.new()
		view_button.text = item[0]
		view_button.pressed.connect(_set_view.bind(item[1]))
		toolbar.add_child(view_button)
	var turn_button := Button.new()
	turn_button.text = "Turntable [Space]"
	turn_button.toggle_mode = true
	turn_button.toggled.connect(func(enabled: bool) -> void: _turntable = enabled)
	toolbar.add_child(turn_button)
	_animation_menu = OptionButton.new()
	_animation_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_animation_menu.add_item("No animation loaded")
	_animation_menu.disabled = true
	_animation_menu.item_selected.connect(_select_animation)
	toolbar.add_child(_animation_menu)
	_empty_panel = CenterContainer.new()
	_empty_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_empty_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(_empty_panel)
	var empty_column := VBoxContainer.new()
	empty_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	empty_column.add_theme_constant_override("separation", 12)
	_empty_panel.add_child(empty_column)
	var empty_title := Label.new()
	empty_title.text = "Import Nathan GLB"
	empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_title.add_theme_font_size_override("font_size", 32)
	empty_column.add_child(empty_title)
	var empty_detail := Label.new()
	empty_detail.text = "No character asset has been imported.\nDrop a .glb / .gltf file here, or choose Import GLB."
	empty_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_detail.add_theme_font_size_override("font_size", 16)
	empty_column.add_child(empty_detail)
	var bottom_panel := PanelContainer.new()
	bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_panel.offset_left = 20.0
	bottom_panel.offset_right = -20.0
	bottom_panel.offset_top = -82.0
	bottom_panel.offset_bottom = -20.0
	bottom_panel.add_theme_stylebox_override("panel", _panel_style())
	root_control.add_child(bottom_panel)
	var bottom_column := VBoxContainer.new()
	bottom_panel.add_child(bottom_column)
	_status = Label.new()
	_status.text = "Empty review scene • Original GLB geometry, rig and materials will be preserved."
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bottom_column.add_child(_status)
	var help := Label.new()
	help.text = "Drag: orbit   Right-drag: pan   Wheel: zoom   1–4: views   Space: turntable   R: reset   O: import"
	help.add_theme_font_size_override("font_size", 13)
	help.modulate = Color(0.77, 0.80, 0.83)
	bottom_column.add_child(help)
	_file_dialog = FileDialog.new()
	_file_dialog.title = "Import Nathan GLB"
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.filters = PackedStringArray(["*.glb ; Binary glTF character", "*.gltf ; glTF character"])
	_file_dialog.size = Vector2i(900, 600)
	_file_dialog.file_selected.connect(load_model)
	add_child(_file_dialog)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.06, 0.065, 0.9)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	style.set_corner_radius_all(8)
	return style


func _open_dialog() -> void:
	_file_dialog.popup_centered_ratio(0.8)


func _files_dropped(paths: PackedStringArray) -> void:
	for path: String in paths:
		if path.get_extension().to_lower() in ["glb", "gltf"]:
			load_model(path)
			return
	_status.text = "Import failed: choose a .glb or .gltf file."


func load_model(path: String) -> void:
	if path.get_extension().to_lower() not in ["glb", "gltf"]:
		_status.text = "Import failed: choose a .glb or .gltf file."
		return
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		_status.text = "Import failed: file does not exist — " + path.get_file()
		return
	var imported_scene: Node
	if path.begins_with("res://") and ResourceLoader.exists(path):
		var resource := load(path) as PackedScene
		if resource != null:
			imported_scene = resource.instantiate()
	else:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error: Error = document.append_from_file(path, state)
		if error != OK:
			_status.text = "Import failed: %s (%s)" % [path.get_file(), error_string(error)]
			return
		imported_scene = document.generate_scene(state)
	if imported_scene == null:
		_status.text = "Import failed: glTF did not contain a scene."
		return
	var candidate := Node3D.new()
	CharacterMaterials.apply(imported_scene)
	candidate.name = "ImportedCharacter"
	candidate.add_child(imported_scene)
	add_child(candidate)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(candidate, meshes)
	if meshes.is_empty():
		candidate.queue_free()
		_status.text = "Import failed: glTF contains no mesh geometry."
		return
	var bounds: AABB = _mesh_bounds(meshes)
	if bounds.size.y < 0.00001:
		candidate.queue_free()
		_status.text = "Import failed: mesh has no measurable height."
		return
	if is_instance_valid(_model_origin):
		_model_origin.queue_free()
	_model_origin = candidate
	var original_height: float = bounds.size.y
	var review_scale: float = 2.0 / original_height
	_model_origin.scale = Vector3.ONE * review_scale
	_model_origin.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * review_scale
	bounds = _mesh_bounds(meshes)
	_body_target = bounds.get_center()
	_head_target = Vector3(_body_target.x, bounds.end.y - bounds.size.y * 0.09, _body_target.z)
	var skeletons: Array[Skeleton3D] = []
	_collect_skeletons(candidate, skeletons)
	var bones: int = 0
	var found_head: bool = false
	for skeleton: Skeleton3D in skeletons:
		bones += skeleton.get_bone_count()
		for bone_index: int in range(skeleton.get_bone_count()):
			var bone_name: String = skeleton.get_bone_name(bone_index).to_lower()
			if not found_head and "head" in bone_name and not "end" in bone_name:
				_head_target = skeleton.global_transform * skeleton.get_bone_global_pose(bone_index).origin + Vector3.UP * 0.08
				found_head = true
	_animation_players.clear()
	_collect_animation_players(candidate, _animation_players)
	_populate_animations()
	var triangles: int = 0
	for mesh_instance: MeshInstance3D in meshes:
		for surface: int in range(mesh_instance.mesh.get_surface_count()):
			var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
			if arrays.size() <= Mesh.ARRAY_INDEX:
				continue
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
			if indices is PackedInt32Array and not indices.is_empty():
				triangles += int(indices.size() / 3)
			elif vertices is PackedVector3Array:
				triangles += int(vertices.size() / 3)
	_has_model = true
	model_path = path
	_empty_panel.hide()
	_asset_name.text = "NATHAN / " + path.get_file()
	_status.text = "%d meshes · %s triangles · %d bones · %d clips · Original height %.3f m · Framed at 2 m" % [meshes.size(), str(triangles), bones, _animation_entries.size(), original_height]
	_set_view(1)
	print("CHARACTER_REVIEW_LOADED ", path.get_file(), " meshes=", meshes.size(), " triangles=", triangles, " bones=", bones, " animations=", _animation_entries.size())


func _mesh_bounds(meshes: Array[MeshInstance3D]) -> AABB:
	var bounds := AABB()
	var initialized: bool = false
	for instance: MeshInstance3D in meshes:
		var local_bounds: AABB = instance.get_aabb()
		for corner: int in range(8):
			var point: Vector3 = instance.global_transform * local_bounds.get_endpoint(corner)
			if not initialized:
				bounds = AABB(point, Vector3.ZERO)
				initialized = true
			else:
				bounds = bounds.expand(point)
	return bounds


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh != null:
		result.append(node)
	for child: Node in node.get_children():
		_collect_meshes(child, result)


func _collect_skeletons(node: Node, result: Array[Skeleton3D]) -> void:
	if node is Skeleton3D:
		result.append(node)
	for child: Node in node.get_children():
		_collect_skeletons(child, result)


func _collect_animation_players(node: Node, result: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		result.append(node)
	for child: Node in node.get_children():
		_collect_animation_players(child, result)


func _populate_animations() -> void:
	_animation_entries.clear()
	_animation_menu.clear()
	_animation_menu.add_item("Rest pose / no playback")
	_active_animation = null
	for player: AnimationPlayer in _animation_players:
		player.stop()
		for clip: StringName in player.get_animation_list():
			if clip == &"RESET":
				continue
			_animation_entries.append({"player": player, "clip": clip})
			_animation_menu.add_item(str(clip))
	_animation_menu.disabled = _animation_entries.is_empty()


func _select_animation(index: int) -> void:
	for player: AnimationPlayer in _animation_players:
		player.stop()
		if player.has_animation(&"RESET"):
			player.play(&"RESET")
			player.advance(0.0)
			player.stop()
	_active_animation = null
	if index > 0 and index <= _animation_entries.size():
		var entry: Dictionary = _animation_entries[index - 1]
		_active_animation = entry["player"] as AnimationPlayer
		_active_animation.play(entry["clip"])


func _set_view(view: int) -> void:
	_target = _head_target if view == 2 else _body_target
	_distance = 1.3 if view == 2 else 5.5
	_pitch = 0.0 if view == 2 else 0.05
	_yaw = PI * 0.5 if view == 3 else (PI if view == 4 else 0.0)
	_update_camera()


func _process(delta: float) -> void:
	if _turntable and _has_model:
		_yaw += delta * 0.35
		_update_camera()
	if is_instance_valid(_active_animation) and not _active_animation.is_playing():
		var selected: int = _animation_menu.selected
		if selected > 0 and selected <= _animation_entries.size():
			_active_animation.play(_animation_entries[selected - 1]["clip"])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_panning = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(0.16, _distance * 0.9)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(20.0, _distance * 1.1)
	elif event is InputEventMouseMotion:
		if _orbiting:
			_yaw -= event.relative.x * 0.006
			_pitch = clampf(_pitch + event.relative.y * 0.006, -1.35, 1.35)
		elif _panning:
			_target += (-_camera.global_basis.x * event.relative.x + _camera.global_basis.y * event.relative.y) * _distance * 0.0012
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_1, KEY_KP_1: _set_view(1)
			KEY_2, KEY_KP_2: _set_view(2)
			KEY_3, KEY_KP_3: _set_view(3)
			KEY_4, KEY_KP_4: _set_view(4)
			KEY_R: _set_view(1)
			KEY_O: _open_dialog()
			KEY_SPACE: _turntable = not _turntable
	_update_camera()


func _update_camera() -> void:
	if not is_instance_valid(_camera):
		return
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _distance
	_camera.position = _target + offset
	_camera.look_at(_target, Vector3.UP)
