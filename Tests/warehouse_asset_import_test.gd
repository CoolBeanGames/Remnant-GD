extends SceneTree
## Real engine imports for seven standalone art assets. Run with isolated APPDATA.

func _initialize() -> void:
	_verify.call_deferred()


func _verify() -> void:
	var save_game: Node = root.get_node_or_null("SaveGame")
	if save_game != null:
		save_game.set("enabled", false)
		save_game.set("saving_disabled", true)
	var paths: Array[String] = ["res://Models/Architecture/DilapidatedWarehouse/asset_manifest.json"]
	var directory: DirAccess = DirAccess.open("res://Models/Interiors/WarehouseMachinery")
	if directory == null:
		push_error("Warehouse machinery directory is missing")
		quit(1)
		return
	for folder: String in directory.get_directories():
		var path: String = "res://Models/Interiors/WarehouseMachinery/%s/asset_manifest.json" % folder
		if FileAccess.file_exists(path):
			paths.append(path)
	if paths.size() != 7:
		push_error("Expected warehouse architecture and six independent props")
		quit(1)
		return
	var total_surfaces: int = 0
	for path: String in paths:
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var packed: PackedScene = load("res://" + str(info["export"])) as PackedScene
		if packed == null:
			push_error("Warehouse asset failed to import: " + path)
			quit(1)
			return
		var model: Node3D = packed.instantiate() as Node3D
		root.add_child(model)
		var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		var bounds: AABB
		var first: bool = true
		var mapped: int = 0
		for node: Node in meshes:
			var mesh: MeshInstance3D = node as MeshInstance3D
			var current: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = current if first else bounds.merge(current)
			first = false
			for surface: int in mesh.mesh.get_surface_count():
				var material: StandardMaterial3D = mesh.get_active_material(surface) as StandardMaterial3D
				if material == null:
					push_error("Missing warehouse PBR material: " + str(info["key"]))
					quit(1)
					return
				if material.albedo_texture != null:
					mapped += 1
		var expected: Array = info["dimensions_blender_m"]
		var target: Vector3 = Vector3(float(expected[0]), float(expected[2]), float(expected[1]))
		if meshes.size() != int(info["mesh_objects"]) or mapped == 0 or (bounds.size-target).abs().length() > 0.05:
			push_error("Warehouse import changed meshes/materials/bounds: %s %s vs %s" % [info["key"], bounds.size, target])
			quit(1)
			return
		if info["key"] == "control_cabinet":
			var pivot: Node = model.find_child("PIVOT*", true, false)
			if pivot == null or pivot.get_child_count() != 5:
				push_error("Cabinet door hinge hierarchy was lost on import")
				quit(1)
				return
		print("WAREHOUSE IMPORT PASS ", info["key"], ": ", meshes.size(), " meshes; ", mapped, " mapped surfaces; bounds ", bounds.size)
		total_surfaces += mapped
		model.free()
	print("WAREHOUSE ENGINE COMPLETE: 7 assets; ", total_surfaces, " textured surfaces")
	quit()
