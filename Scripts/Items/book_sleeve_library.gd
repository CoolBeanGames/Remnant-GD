@tool
class_name book_sleeve_library
extends environment_art

## One editable resource per spine, in stable imported-node order.
@export var sleeves: Array[book_sleeve] = []
@export var spine_filter: String = "spine"
var spine_nodes: Array[MeshInstance3D] = []

func _ready() -> void:
	super._ready()
	spine_nodes.clear()
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh != null and spine_filter in str(mesh.name).to_lower() and not "gold" in str(mesh.name).to_lower():
			spine_nodes.append(mesh)
	spine_nodes.sort_custom(func(a: MeshInstance3D, b: MeshInstance3D) -> bool: return str(a.get_path()) < str(b.get_path()))
	for index in mini(spine_nodes.size(), sleeves.size()):
		apply_sleeve(spine_nodes[index], sleeves[index])

func apply_sleeve(mesh: MeshInstance3D, sleeve: book_sleeve) -> void:
	if sleeve == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = sleeve.cover_color
	material.albedo_texture = sleeve.artwork
	material.roughness = .9
	mesh.material_override = material
	var previous := mesh.get_node_or_null("SleeveTitle")
	if previous != null:
		previous.free()
	if sleeve.title.is_empty():
		return
	var bounds: AABB = mesh.mesh.get_aabb()
	var label := Label3D.new()
	label.name = "SleeveTitle"
	label.text = sleeve.title + ("\n" + sleeve.author if not sleeve.author.is_empty() else "")
	label.font_size = 32
	var line_count: int = 2 if not sleeve.author.is_empty() else 1
	var longest_line: int = maxi(sleeve.title.length(), sleeve.author.length())
	label.pixel_size = minf(bounds.size.x / (line_count * 44.0), bounds.size.y / (maxi(1, longest_line) * 26.0))
	label.modulate = sleeve.ink_color
	label.outline_modulate = Color(.06, .05, .04)
	label.outline_size = 3
	label.no_depth_test = false
	label.shaded = true
	mesh.add_child(label)
	label.position = bounds.get_center() + Vector3(0, 0, bounds.size.z * .5 + .002)
	label.rotation.z = PI * .5
	if bool(get_meta("portal_inside", false)):
		portal_space.apply_actor(label, true)
