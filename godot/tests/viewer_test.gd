extends SceneTree
## Creates a cuboid solely to exercise GLB serialization/import. Not a character.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var fixture := Node3D.new()
	fixture.name = "ImportValidationFixture_NotNathan"
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 1.8, 0.3)
	mesh.mesh = box
	mesh.position.y = 0.9
	fixture.add_child(mesh)
	root.add_child(fixture)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_scene(fixture, state) == OK)
	var path: String = "user://viewer_validation_fixture.glb"
	assert(document.write_to_filesystem(state, path) == OK)
	fixture.queue_free()
	var viewer: Node3D = load("res://scenes/character_review.tscn").instantiate()
	root.add_child(viewer)
	assert(not viewer._has_model)
	assert(viewer._empty_panel.visible)
	viewer.load_model(path)
	assert(viewer._has_model)
	assert(not viewer._empty_panel.visible)
	assert(viewer._status.text.contains("12 triangles"))
	assert(viewer._status.text.contains("Original height 1.800 m"))
	viewer._set_view(2)
	assert(is_equal_approx(viewer._distance, 0.82))
	viewer.load_model("user://missing_asset.glb")
	assert(viewer._status.text.begins_with("Import failed"))
	assert(viewer._has_model)
	print("VIEWER_TESTS 9 assertions passed; cuboid fixture is not a character asset")
	quit(0)
