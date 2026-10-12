extends SceneTree

## Run after editor import: Godot --headless --path . --script Tools/bake_portal_environments.gd
## Rebuilds editable engine wrappers from the reviewed Blender assembly manifests.
const OUTPUT: String = "res://Scenes/Environments/"
var baked: Dictionary = {}
var failures: Array[String] = []

func _initialize() -> void:
	_build.call_deferred()

func _read(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) as Dictionary

func _build() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT + "Art")
	DirAccess.make_dir_recursive_absolute(OUTPUT + "Collision")
	var apartment: Dictionary = _read("res://Models/Interiors/FurnishedStudio/assembly_manifest.json")
	var placements: Array = [{"name": "Apartment shell", "source": apartment.room_source, "position_m": [0, 0, 0], "rotation_z_degrees": 0}]
	for entry: Dictionary in apartment.linked_assets:
		var item: Dictionary = entry.duplicate()
		item.name = entry.asset
		placements.append(item)
	_build_room("furnished_apartment", placements, Vector3(1.76, 1.7195, 4.60))
	for kind in ["warehouse", "hospital"]:
		var folder: String = "DilapidatedWarehouse" if kind == "warehouse" else "DilapidatedHospital"
		var manifest: Dictionary = _read("res://Models/Interiors/%s/assembly_manifest.json" % folder)
		_build_room("dilapidated_" + kind, manifest.instances, Vector3(0, 1.7195, 18.44 if kind == "warehouse" else 13.44))
	print("Environment scene/collision bake: ", "PASS / %d shared art wrappers" % baked.size() if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

func _export_path(source: String) -> String:
	var asset_dir: String = source.get_base_dir().get_base_dir()
	var manifest_path: String = "res://" + asset_dir + "/asset_manifest.json"
	var manifest: Dictionary = _read(manifest_path)
	var exported: String = str(manifest.get("export", ""))
	if not exported.ends_with(".glb"):
		exported = asset_dir + "/" + source.get_file().get_basename() + ".glb"
	return "res://" + exported

func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	var pose := Transform3D.IDENTITY
	var current: Node3D = node
	while current != root:
		pose = current.transform * pose
		current = current.get_parent() as Node3D
	return pose

func _bake_art(source: String) -> String:
	var path: String = _export_path(source)
	if baked.has(path):
		return baked[path]
	var key: String = path.get_base_dir().get_file() + "_" + path.get_file().get_basename()
	var root := Node3D.new()
	root.name = key
	root.set_script(load("res://Scripts/Portal/environment_art.gd"))
	var model: Node3D = (load(path) as PackedScene).instantiate()
	model.name = "Model"
	root.add_child(model)
	model.owner = root
	# The narrative portal replaces the apartment's partially open entry leaf.
	# Keep its authored frame/threshold, swing the leaf clear of the narrow passage.
	if path.contains("StudioApartment"):
		for node in model.find_children("*", "Node3D", true, false):
			if "Apartment entrance" in str(node.name) and "hinged leaf" in str(node.name):
				node.rotation.y = deg_to_rad(94.0)
				root.get("pose_overrides")[str(root.get_path_to(node))] = node.transform
	var faces := PackedVector3Array()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var lower: String = str(mesh.name).to_lower()
		if mesh.mesh == null or "grime" in lower or "blood" in lower or "stain" in lower or "decal" in lower or "newsprint" in lower or "damp" in lower or "print" in lower:
			continue
		var pose: Transform3D = _relative_transform(model, mesh)
		var triangles: PackedVector3Array = mesh.mesh.get_faces()
		for index in range(0, triangles.size(), 3):
			var a: Vector3 = pose * triangles[index]
			var b: Vector3 = pose * triangles[index + 1]
			var c: Vector3 = pose * triangles[index + 2]
			if (b - a).cross(c - a).length_squared() > 0.0000000001:
				faces.append(a)
				faces.append(b)
				faces.append(c)
	var collider := StaticBody3D.new()
	collider.name = "Solid"
	root.add_child(collider)
	collider.owner = root
	collider.add_to_group("Floor", true)
	collider.physics_material_override = PhysicsMaterial.new()
	collider.physics_material_override.friction = 0.95
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var shape_path: String = OUTPUT + "Collision/" + key + ".tres"
	_save(shape, shape_path)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	collision.shape = load(shape_path)
	collider.add_child(collision)
	collision.owner = root
	var art_path: String = OUTPUT + "Art/" + key + ".tscn"
	_save_scene(root, art_path)
	print("Baked ", key, " / ", faces.size() / 3, " solid triangles")
	root.free()
	baked[path] = art_path
	return art_path

func _build_room(kind: String, placements: Array, entrance_position: Vector3) -> void:
	var root := Node3D.new()
	root.name = kind.to_pascal_case()
	root.set_script(load("res://Scripts/Portal/portal_room.gd"))
	root.set("environment", load("res://Data/Portal/interior_environment.tres"))
	var entrance := Marker3D.new()
	entrance.name = "Entrance"
	root.add_child(entrance)
	entrance.owner = root
	entrance.position = entrance_position
	entrance.rotation.y = PI
	var art := Node3D.new()
	art.name = "Art"
	root.add_child(art)
	art.owner = root
	for entry: Dictionary in placements:
		var scene: PackedScene = load(_bake_art(entry.source)) as PackedScene
		var instance: Node3D = scene.instantiate()
		instance.name = str(entry.name).validate_node_name()
		art.add_child(instance)
		instance.owner = root
		var pos: Array = entry.position_m
		instance.position = Vector3(float(pos[0]), float(pos[2]), -float(pos[1]))
		instance.rotation.y = deg_to_rad(float(entry.rotation_z_degrees))
	var lighting := Node3D.new()
	lighting.name = "Lighting"
	root.add_child(lighting)
	lighting.owner = root
	if kind == "furnished_apartment":
		# A short plaster vestibule accommodates the existing 3.18 m story door;
		# the apartment's original narrow, lower doorway stays intact behind it.
		_box(root, "VestibuleFloor", Vector3(1.76, -.08, 3.88), Vector3(2.4, .16, 1.7), Color(.23, .22, .19))
		for side in [-1, 1]:
			_box(root, "VestibuleWall", Vector3(1.76 + side * 1.13, 1.70, 3.90), Vector3(.14, 3.4, 1.8), Color(.32, .32, .27))
		_box(root, "VestibuleCeiling", Vector3(1.76, 3.43, 3.9), Vector3(2.4, .14, 1.8), Color(.32, .32, .27))
		_omni(lighting, Vector3(1.4, 2.45, -1.3), Color(.75, .85, .94), 1.65, 5.0, true)
		_omni(lighting, Vector3(-2.95, 1.55, .4), Color(1, .71, .42), .95, 3.5, false)
		_omni(lighting, Vector3(-2.65, 2.3, -2.1), Color(.78, .87, .86), .9, 3.0, false)
		_omni(lighting, Vector3(1.76, 2.85, 3.88), Color(.78, .83, .8), .75, 3.4, false)
	elif kind == "dilapidated_warehouse":
		_box(root, "EntranceLanding", Vector3(0, -.08, 18.35), Vector3(4.0, .16, 1.2), Color(.23, .24, .22))
		for z in [-12, -3, 7, 15]:
			for x in [-6, 6]:
				_omni(lighting, Vector3(x, 6.8, z), Color(.82, .89, .92), 2.3, 13.0, z == 7)
		_omni(lighting, Vector3(7.4, 6.8, -13.6), Color(1, .78, .52), 1.8, 7, true)
	else:
		_box(root, "EntranceLanding", Vector3(0, -.08, 13.25), Vector3(2.5, .16, 1.2), Color(.28, .30, .29))
		for z in [-9.4, -4.5, 3.75, 9.4]:
			_omni(lighting, Vector3(0, 2.9, z), Color(.76, .87, .86), 1.5, 7.5, z == 9.4)
			for x in [-5.4, 5.4]:
				_omni(lighting, Vector3(x, 2.85, z), Color(.88, .92, .83), 1.5, 6.5, false)
	_save_scene(root, OUTPUT + kind + ".tscn")
	root.free()

func _box(root: Node3D, name: String, position: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = name
	root.add_child(body, true)
	body.owner = root
	body.position = position
	body.add_to_group("Floor", true)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	collision.owner = root
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .94
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	mesh.owner = root

func _omni(root: Node3D, position: Vector3, color: Color, energy: float, radius: float, shadow: bool) -> void:
	var light := OmniLight3D.new()
	light.name = "InteriorLight"
	root.add_child(light, true)
	light.owner = root.get_parent()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = shadow

func _save(resource: Resource, path: String) -> void:
	var error: Error = ResourceSaver.save(resource, path)
	if error != OK:
		failures.append("Cannot save %s: %s" % [path, error])

func _save_scene(root: Node3D, path: String) -> void:
	var packed := PackedScene.new()
	var error: Error = packed.pack(root)
	if error == OK:
		_save(packed, path)
	else:
		failures.append("Cannot pack %s: %s" % [path, error])
