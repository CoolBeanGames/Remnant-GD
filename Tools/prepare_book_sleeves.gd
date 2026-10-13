extends SceneTree

func _initialize() -> void:
	build.call_deferred()

func build() -> void:
	var scene_path: String = "res://Scenes/Environments/Art/Bookshelf_bookshelf.tscn"
	var actor: Node3D = (load(scene_path) as PackedScene).instantiate()
	var spines: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if "spine" in str(mesh.name).to_lower() and not "gold" in str(mesh.name).to_lower():
			spines.append(mesh)
	spines.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool: return str(actor.get_path_to(a)) < str(actor.get_path_to(b)))
	DirAccess.make_dir_recursive_absolute("res://Data/Books/Shelves")
	var entries: Array[book_sleeve] = []
	for index in spines.size():
		var path: String = "res://Data/Books/Shelves/book_%02d.tres" % (index + 1)
		var entry: book_sleeve
		if ResourceLoader.exists(path):
			entry = load(path) as book_sleeve
		else:
			entry = book_sleeve.new()
			entry.title = ""
		if entry.title.is_empty() and entry.artwork == null:
			var original: Material = spines[index].mesh.surface_get_material(0)
			if original is StandardMaterial3D:
				entry.cover_color = original.albedo_color
		ResourceSaver.save(entry, path)
		entries.append(entry)
	actor.set_script(load("res://Scripts/Items/book_sleeve_library.gd"))
	actor.set("sleeves", entries)
	var packed := PackedScene.new()
	packed.pack(actor)
	ResourceSaver.save(packed, scene_path)
	actor.free()
	print("Editable book sleeves / ", entries.size())
	quit(0 if entries.size() == 25 else 1)
