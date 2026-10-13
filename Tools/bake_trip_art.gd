extends "res://Tools/bake_portal_environments.gd"

## Build only art/solid wrappers; story scripts and designer room poses stay intact.
func _build() -> void:
	var selected: PackedStringArray = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			selected = argument.trim_prefix("--only=").split(",", false)
	for name: String in ["couch", "lounger", "television", "paper_stack", "desk", "office_chair", "hospital_bed", "wheelchair", "waiting_chairs", "coffee_table", "industrial_machine_a", "industrial_machine_b", "industrial_machine_c", "garbage_bag_a", "garbage_bag_b", "ward_door", "entrance_door", "bathroom_door"]:
		if not selected.is_empty() and not selected.has(name):
			continue
		var source_name: String = "door" if name.ends_with("_door") else name
		var source: String = "res://Models/Imported/Trip/%s/%s.glb" % [source_name, source_name]
		var model: Node3D = (load(source) as PackedScene).instantiate()
		model.name = "Model"
		if name.ends_with("_door"):
			# Hospital openings are 1.05 x 2.2 m; keep the hinged leaf open.
			model.scale = Vector3(.59, .67, .67)
			if name == "entrance_door":
				model.scale = Vector3(.49, .63, .63)
			elif name == "bathroom_door":
				model.scale = Vector3(.577, .61, .61)
			var leaf: Node3D = model.find_child("DoorLeaf", true, false)
			if leaf == null:
				failures.append("Missing separated door leaf")
				model.free()
				continue
			leaf.rotation.y = deg_to_rad(-96)
		_bake_model(model, "Trip_" + name, not name.begins_with("garbage_bag"))
	if selected.is_empty():
		var shell: Node3D = (load("res://Models/Architecture/StudioApartment/studio_apartment.glb") as PackedScene).instantiate()
		shell.name = "Model"
		for node in shell.find_children("*", "Node3D", true, false):
			if "Apartment entrance" in str(node.name) and "hinged leaf" in str(node.name):
					node.rotation.y = deg_to_rad(94)
		_bake_model(shell, "StudioApartment_studio_apartment", true)
		for environment_name: String in ["DilapidatedWarehouse", "DilapidatedHospital"]:
			var file_name: String = "dilapidated_warehouse" if environment_name == "DilapidatedWarehouse" else "dilapidated_hospital"
			var architecture: Node3D = (load("res://Models/Architecture/%s/%s.glb" % [environment_name, file_name]) as PackedScene).instantiate()
			architecture.name = "Model"
			_bake_model(architecture, environment_name + "_" + file_name, true)
		var bed: Node3D = (load("res://Models/Interiors/StudioFurniture/BedroomBed/bedroom_bed.glb") as PackedScene).instantiate()
		bed.name = "Model"
		_bake_model(bed, "Trip_bedroom_bed", true)
	if stage_output and failures.is_empty():
		var manifest := FileAccess.open("res://.godot/portal_bake/bake_manifest.json", FileAccess.WRITE)
		manifest.store_string(JSON.stringify({"version": 1, "files": staged_files}))
	print("Trip art/collision bake: ", "PASS / %d wrappers" % baked.size() if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)

func _bake_model(model: Node3D, key: String, solid: bool) -> void:
	var asset_root := Node3D.new()
	asset_root.name = key
	asset_root.set_script(load("res://Scripts/Portal/environment_art.gd"))
	asset_root.add_child(model)
	model.owner = asset_root
	for node in model.find_children("*", "Node3D", true, false):
		if node.name == &"DoorLeaf" or ("Apartment entrance" in str(node.name) and "hinged leaf" in str(node.name)):
			asset_root.get("pose_overrides")[str(asset_root.get_path_to(node))] = node.transform
	if solid:
		var faces := PackedVector3Array()
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var lower: String = str(mesh.name).to_lower()
			if mesh.mesh == null or "grime" in lower or "newsprint" in lower or "damp" in lower or "print" in lower:
				continue
			var pose: Transform3D = _relative_transform(asset_root, mesh)
			var triangles: PackedVector3Array = mesh.mesh.get_faces()
			for index in range(0, triangles.size(), 3):
				var a: Vector3 = pose * triangles[index]
				var b: Vector3 = pose * triangles[index + 1]
				var c: Vector3 = pose * triangles[index + 2]
				if (b - a).cross(c - a).length_squared() > .0000000001:
					faces.append(a)
					faces.append(b)
					faces.append(c)
		var body := StaticBody3D.new()
		body.name = "Solid"
		asset_root.add_child(body)
		body.owner = asset_root
		body.add_to_group("Floor", true)
		body.physics_material_override = PhysicsMaterial.new()
		body.physics_material_override.friction = .95
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		var shape_path: String = OUTPUT + "Collision/" + key + ".tres"
		_save(shape, shape_path)
		shape.take_over_path(shape_path)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		collision.shape = shape
		body.add_child(collision)
		collision.owner = asset_root
	_save_scene(asset_root, OUTPUT + "Art/" + key + ".tscn")
	baked[key] = true
	asset_root.free()
