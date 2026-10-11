extends SceneTree
## Standalone import smoke for art assets. Use isolated APPDATA, no real save data.

func _initialize() -> void:
	_verify.call_deferred()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _verify() -> void:
	var save_game: Node = root.get_node_or_null("SaveGame")
	if save_game != null:
		save_game.set("enabled", false)
		save_game.set("saving_disabled", true)
	var directory: DirAccess = DirAccess.open("res://Models/Interiors/StudioFurniture")
	if directory == null:
		_fail("Studio furniture directory is missing")
		return
	var assets: int = 0
	var surfaces: int = 0
	for folder: String in directory.get_directories():
		var path: String = "res://Models/Interiors/StudioFurniture/%s/asset_manifest.json" % folder
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			_fail("Invalid asset manifest: " + folder)
			return
		var info: Dictionary = parsed
		var scene: PackedScene = load("res://" + str(info.get("export", ""))) as PackedScene
		if scene == null:
			_fail("Furniture failed to import: " + folder)
			return
		var model: Node3D = scene.instantiate() as Node3D
		root.add_child(model)
		var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
		if meshes.size() != int(info.get("mesh_objects", 0)):
			_fail("Furniture mesh count changed on import: " + folder)
			return
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
					_fail("Missing imported PBR material: " + folder)
					return
				if material.albedo_texture != null:
					mapped += 1
		if mapped == 0:
			_fail("Furniture has no imported texture maps: " + folder)
			return
		var expected: Array = info.get("dimensions_blender_m", [])
		var target: Vector3 = Vector3(float(expected[0]), float(expected[2]), float(expected[1]))
		if (bounds.size - target).abs().length() > 0.05:
			_fail("Furniture bounds differ after Y-up conversion: %s %s vs %s" % [folder, bounds.size, target])
			return
		print("STUDIO IMPORT PASS ", folder, ": ", meshes.size(), " meshes; ", mapped, " textured surfaces; bounds ", bounds.size)
		surfaces += mapped
		assets += 1
		model.free()
	if assets != 18:
		_fail("Expected 18 independent furniture imports")
		return
	var room_scene: PackedScene = load("res://Models/Architecture/StudioApartment/studio_apartment.glb") as PackedScene
	if room_scene == null:
		_fail("Worn apartment shell failed to import")
		return
	var apartment: Node3D = room_scene.instantiate() as Node3D
	root.add_child(apartment)
	var room_meshes: Array[Node] = apartment.find_children("*", "MeshInstance3D", true, false)
	var room_info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Models/Architecture/StudioApartment/asset_manifest.json"))
	if room_meshes.size() != int(room_info.get("architecture_meshes", 0)):
		_fail("Room mesh count must match its current architecture manifest")
		return
	apartment.free()
	print("STUDIO ENGINE PASS: ", assets, " independent furniture assets, ", surfaces, " textured surfaces; worn room ", room_meshes.size(), " meshes")
	quit()
