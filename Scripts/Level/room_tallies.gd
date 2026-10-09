class_name room_tallies
extends Node3D

@export var interior: CSGBox3D
@export var groups_per_row: int = 16
@export var max_visible_marks: int = 500
var count: int = -1

func _ready() -> void:
	refresh()

func refresh() -> void:
	var saved: Variant = Blackboard.read_data("respawn_tallies")
	var total: int = int(saved) if saved is int or saved is float else 0
	if count == total or interior == null:
		return
	count = total
	for child in get_children():
		child.queue_free()
	transform = interior.transform * Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(interior.size.x * .5 - .012, -.35, -interior.size.z * .24))
	if total <= 0:
		return
	var random := RandomNumberGenerator.new()
	random.seed = 391
	var grooves := ImmediateMesh.new()
	var edges := ImmediateMesh.new()
	var rows: int = ceili(float(mini(total, max_visible_marks)) / (5 * maxi(1, groups_per_row)))
	var row_spacing: float = minf(.28, (interior.size.y * .5 - .6) / maxi(1, rows - 1))
	grooves.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	edges.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for mark in mini(total, max_visible_marks):
		var group: int = floori(float(mark) / 5)
		var origin := Vector2((group % maxi(1, groups_per_row)) * .29, -floori(float(group) / maxi(1, groups_per_row)) * row_spacing)
		var digit: int = mark % 5
		var from: Vector2 = origin + Vector2(digit * .047, -.09)
		var to: Vector2 = origin + Vector2(digit * .047 + random.randf_range(-.008, .008), .09)
		if digit == 4:
			from = origin + Vector2(-.025, -.06)
			to = origin + Vector2(.175, .065)
		for segment in 5:
			var a: Vector2 = from.lerp(to, float(segment) / 5)
			var b: Vector2 = from.lerp(to, float(segment + 1) / 5)
			b.x += random.randf_range(-.002, .002)
			_strip(edges, a, b, .007, 0)
			_strip(grooves, a, b, .003, .0005)
	grooves.surface_end()
	edges.surface_end()
	if total == 0:
		return
	_add_mesh(edges, Color(.42, .39, .33))
	_add_mesh(grooves, Color(.075, .06, .045))

func _strip(mesh: ImmediateMesh, a: Vector2, b: Vector2, width: float, depth: float) -> void:
	var normal: Vector2 = (b - a).orthogonal().normalized() * width * .5
	for point in [a - normal, b - normal, b + normal, a - normal, b + normal, a + normal]:
		mesh.surface_set_normal(Vector3.BACK)
		mesh.surface_add_vertex(Vector3(point.x, point.y, depth))

func _add_mesh(mesh: ImmediateMesh, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
