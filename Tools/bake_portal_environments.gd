extends SceneTree

## Run after editor import: Godot --headless --path . --script Tools/bake_portal_environments.gd
## Rebuilds editable engine wrappers from the reviewed Blender assembly manifests.
const OUTPUT: String = "res://Scenes/Environments/"
var baked: Dictionary = {}
var failures: Array[String] = []
var stage_output: bool = false
var staged_files: Array[String] = []

func _initialize() -> void:
	stage_output = OS.get_cmdline_user_args().has("--stage")
	if stage_output:
		DirAccess.remove_absolute("res://.godot/portal_bake/bake_manifest.json")
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
	print("Environment scene/collision bake: ", "PASS / %d shared art wrappers" % baked.size() if failures.is_empty() else str(failures))
	if stage_output and failures.is_empty():
		var manifest := FileAccess.open("res://.godot/portal_bake/bake_manifest.json", FileAccess.WRITE)
		if manifest == null:
			failures.append("Cannot write staging completion manifest")
		else:
			manifest.store_string(JSON.stringify({"version": 1, "files": staged_files}))
	quit(0 if failures.is_empty() else 1)

func _export_path(source: String) -> String:
	var asset_dir: String = source.get_base_dir().get_base_dir()
	var manifest_path: String = "res://" + asset_dir + "/asset_manifest.json"
	var manifest: Dictionary = _read(manifest_path)
	var exported: String = str(manifest.get("export", ""))
	if not exported.ends_with(".glb"):
		exported = asset_dir + "/" + source.get_file().get_basename() + ".glb"
	return "res://" + exported

func _relative_transform(asset_root: Node3D, node: Node3D) -> Transform3D:
	var pose := Transform3D.IDENTITY
	var current: Node3D = node
	while current != asset_root:
		pose = current.transform * pose
		current = current.get_parent() as Node3D
	return pose

func _bake_art(source: String) -> String:
	var path: String = _export_path(source)
	if baked.has(path):
		return baked[path]
	var key: String = path.get_base_dir().get_file() + "_" + path.get_file().get_basename()
	var asset_root := Node3D.new()
	asset_root.name = key
	asset_root.set_script(load("res://Scripts/Portal/environment_art.gd"))
	var model: Node3D = (load(path) as PackedScene).instantiate()
	model.name = "Model"
	asset_root.add_child(model)
	model.owner = asset_root
	# The narrative portal replaces the apartment's partially open entry leaf.
	# Keep its authored frame/threshold, swing the leaf clear of the narrow passage.
	if path.contains("StudioApartment"):
		for node in model.find_children("*", "Node3D", true, false):
			if "Apartment entrance" in str(node.name) and "hinged leaf" in str(node.name):
				node.rotation.y = deg_to_rad(94.0)
				asset_root.get("pose_overrides")[str(asset_root.get_path_to(node))] = node.transform
	var faces := PackedVector3Array()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var lower: String = str(mesh.name).to_lower()
		if "steel stair tread" in lower or "worn safety nosing" in lower:
			continue
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
	asset_root.add_child(collider)
	collider.owner = asset_root
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
	collision.owner = asset_root
	var art_path: String = OUTPUT + "Art/" + key + ".tscn"
	_save_scene(asset_root, art_path)
	print("Baked ", key, " / ", int(faces.size() / 3.0), " solid triangles")
	asset_root.free()
	baked[path] = art_path
	return art_path

func _build_room(kind: String, placements: Array, entrance_position: Vector3) -> void:
	var asset_root := Node3D.new()
	asset_root.name = kind.to_pascal_case()
	asset_root.set_script(load("res://Scripts/Portal/portal_room.gd"))
	asset_root.set("environment", load("res://Data/Portal/apartment_environment.tres" if kind == "furnished_apartment" else "res://Data/Portal/dark_environment.tres"))
	asset_root.set("suppress_player_light", true)
	if kind == "furnished_apartment":
		var left: Array[AudioStream] = []
		var right: Array[AudioStream] = []
		for index in range(1, 4):
			left.append(load("res://Audio/SFX/Footsteps/Wood/wood_left_%d.wav" % index))
			right.append(load("res://Audio/SFX/Footsteps/Wood/wood_right_%d.wav" % index))
		asset_root.set("left_foot_sounds", left)
		asset_root.set("right_foot_sounds", right)
	var entrance := Marker3D.new()
	entrance.name = "Entrance"
	asset_root.add_child(entrance)
	entrance.owner = asset_root
	entrance.position = entrance_position
	entrance.rotation.y = PI
	var art := Node3D.new()
	art.name = "Art"
	asset_root.add_child(art)
	art.owner = asset_root
	for entry: Dictionary in placements:
		var scene: PackedScene = load(_bake_art(entry.source)) as PackedScene
		var instance: Node3D = scene.instantiate()
		instance.name = str(entry.name).validate_node_name()
		art.add_child(instance)
		instance.owner = asset_root
		var pos: Array = entry.position_m
		instance.position = Vector3(float(pos[0]), float(pos[2]), -float(pos[1]))
		instance.rotation.y = deg_to_rad(float(entry.rotation_z_degrees))
	var lighting := Node3D.new()
	lighting.name = "Lighting"
	asset_root.add_child(lighting)
	lighting.owner = asset_root
	if kind == "furnished_apartment":
		# A short plaster vestibule accommodates the existing 3.18 m story door;
		# the apartment's original narrow, lower doorway stays intact behind it.
		_box(asset_root, "VestibuleFloor", Vector3(1.76, -.08, 3.88), Vector3(2.4, .16, 1.7), Color(.23, .22, .19))
		for side in [-1, 1]:
			_box(asset_root, "VestibuleWall", Vector3(1.76 + side * 1.13, 1.70, 3.90), Vector3(.14, 3.4, 1.8), Color(.32, .32, .27))
		_box(asset_root, "VestibuleCeiling", Vector3(1.76, 3.43, 3.9), Vector3(2.4, .14, 1.8), Color(.32, .32, .27))
		_omni(lighting, Vector3(1.4, 2.45, -1.3), Color(1, .58, .16), .32, 5.0, true)
		_omni(lighting, Vector3(-2.95, 1.55, .4), Color(1, .49, .09), .18, 3.5, false)
		_omni(lighting, Vector3(-2.65, 2.3, -2.1), Color(1, .58, .17), .12, 3.0, false)
		_omni(lighting, Vector3(1.76, 2.85, 3.88), Color(1, .58, .17), .13, 3.4, false)
	elif kind == "dilapidated_warehouse":
		_box(asset_root, "EntranceLanding", Vector3(0, -.08, 18.35), Vector3(4.0, .16, 1.2), Color(.23, .24, .22))
		_stair_ramp(asset_root)
	else:
		_box(asset_root, "EntranceLanding", Vector3(0, -.08, 13.25), Vector3(2.5, .16, 1.2), Color(.28, .30, .29))
	_save_scene(asset_root, OUTPUT + kind + ".tscn")
	asset_root.free()

func _stair_ramp(asset_root: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "StairWalkingSurface"
	asset_root.add_child(body)
	body.owner = asset_root
	body.add_to_group("Floor", true)
	body.add_to_group("smooth-walking-surface", true)
	var collision := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	var a := Vector3(8.96, 0, 10.11)
	var b := Vector3(10.74, 0, 10.11)
	var c := Vector3(10.74, 4.205, 2.98)
	var d := Vector3(8.96, 4.205, 2.98)
	shape.set_faces(PackedVector3Array([a, b, c, a, c, d]))
	shape.backface_collision = true
	collision.shape = shape
	body.add_child(collision)
	collision.owner = asset_root

func _box(asset_root: Node3D, name: String, position: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = name
	asset_root.add_child(body, true)
	body.owner = asset_root
	body.position = position
	body.add_to_group("Floor", true)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	collision.owner = asset_root
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .94
	box.material = material
	mesh.mesh = box
	body.add_child(mesh)
	mesh.owner = asset_root

func _omni(asset_root: Node3D, position: Vector3, color: Color, energy: float, radius: float, shadow: bool) -> void:
	var light := OmniLight3D.new()
	light.name = "InteriorLight"
	asset_root.add_child(light, true)
	light.owner = asset_root.get_parent()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = shadow

func _save(resource: Resource, path: String) -> void:
	# Optional staging avoids rewriting editor-watched resources mid-bake.
	# External references retain their canonical scene paths when published.
	var output: String = "res://.godot/portal_bake/" + path.trim_prefix(OUTPUT) if stage_output else path
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error: Error = ResourceSaver.save(resource, output)
	if error != OK:
		failures.append("Cannot save %s: %s" % [path, error])
	elif stage_output:
		staged_files.append(path.trim_prefix(OUTPUT))

func _save_scene(asset_root: Node3D, path: String) -> void:
	var packed := PackedScene.new()
	var error: Error = packed.pack(asset_root)
	if error == OK:
		_save(packed, path)
	else:
		failures.append("Cannot pack %s: %s" % [path, error])
