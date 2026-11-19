extends RefCounted
## Preserve the authored glTF beard-root vertex alpha in Godot's importer.
## Materials are copied per mesh; source resources and other surfaces stay intact.


static func apply(model: Node) -> int:
	var changed: int = 0
	if model is MeshInstance3D:
		var instance: MeshInstance3D = model as MeshInstance3D
		if instance.mesh != null and "beard" in instance.name.to_lower():
			for surface: int in range(instance.mesh.get_surface_count()):
				var arrays: Array = instance.mesh.surface_get_arrays(surface)
				if arrays.size() <= Mesh.ARRAY_COLOR or arrays[Mesh.ARRAY_COLOR] == null:
					continue
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				if colors.is_empty():
					continue
				var authored_alpha: bool = false
				for color: Color in colors:
					if color.a < 0.999:
						authored_alpha = true
						break
				if not authored_alpha:
					continue
				var material: Material = instance.get_active_material(surface)
				if material is StandardMaterial3D:
					var corrected: StandardMaterial3D = material.duplicate() as StandardMaterial3D
					corrected.vertex_color_use_as_albedo = true
					corrected.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
					instance.set_surface_override_material(surface, corrected)
					changed += 1
	for child: Node in model.get_children():
		changed += apply(child)
	return changed
