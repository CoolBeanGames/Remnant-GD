class_name prompt_display
extends Node3D

@export_category("Player")
@export var camera: Camera3D
@export var ray: raycaster
@export var pickup: player_pickup
@export var placement: prop_placement
@export var placement_prompts: prompt_set

@export_category("Presentation")
@export var label_scene: PackedScene
@export var carrying_prompts: prompt_set
@export_range(0.5, 4.0, 0.1) var reference_distance: float = 1.6
@export_range(0.0, 80.0, 1.0) var screen_gap: float = 18.0
@export_range(0.0, 80.0, 1.0) var screen_margin: float = 20.0
@export_range(1, 10, 1) var single_column_limit: int = 3
@export var column_gap: float = 0.08
@export var row_gap: float = 0.025

var labels: Array[world_prompt_label] = []
var displayed_texts: Array[String] = []
var air_prompt := prompt_entry.new()
var axis_prompt := prompt_entry.new()
var toggle_prompt := prompt_entry.new()
var layout_size := Vector2.ZERO
var _bounds_owner: Node3D
var _local_bounds := AABB()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	air_prompt.text = "Lock In Air"
	air_prompt.action = &"place_in_air"
	air_prompt.key_first = true
	axis_prompt.action = &"rotate_axis"
	axis_prompt.key_first = true
	toggle_prompt.action = &"confirm"
	refresh()


func _process(_delta: float) -> void:
	refresh()


func get_current_prompts() -> prompt_set:
	if pickup != null and pickup.is_holding_object():
		if placement != null and placement.is_building():
			return placement_prompts
		if pickup.held_object.has_method("get_carry_prompts"):
			return pickup.held_object.get_carry_prompts()
		return carrying_prompts
	if ray == null or not ray.is_looking_at_something():
		return null
	var provider: object_prompts = object_prompts.find_for(ray.get_looked_at())
	return provider.get_prompts() if provider != null else null


func refresh() -> void:
	var selected: prompt_set = get_current_prompts()
	var entries: Array[prompt_entry] = []
	var texts: Array[String] = []
	if selected != null:
		for entry in selected.entries:
			if entry != null:
				entries.append(entry)
				texts.append(entry.get_display_text())
	if pickup != null and pickup.is_holding_object() and pickup.held_object is rotatable_item:
		if placement != null and placement.is_building() and pickup.held_object.air_placeable:
			entries.append(air_prompt)
			texts.append(air_prompt.get_display_text())
		axis_prompt.text = "Axis: " + pickup.held_object.get_rotation_axis_name()
		entries.append(axis_prompt)
		texts.append(axis_prompt.get_display_text())
	if pickup != null and pickup.is_holding_object() and pickup.held_object is switchable_prop and (placement == null or not placement.is_building()):
		toggle_prompt.text = "Turn Off" if pickup.held_object.powered else "Turn On"
		entries.append(toggle_prompt)
		texts.append(toggle_prompt.get_display_text())
	if Blackboard.read_data("player_input_blocked") or get_tree().paused or DevTools.any_modal_open():
		entries.clear()
		texts.clear()
	if texts == displayed_texts:
		_update_world_pose()
		return
	while labels.size() > entries.size():
		var label: world_prompt_label = labels.pop_back()
		remove_child(label)
		label.queue_free()
	while labels.size() < entries.size():
		if label_scene == null:
			push_warning("Prompt display needs a world_prompt_label scene.")
			return
		var instance: Node = label_scene.instantiate()
		if not instance is world_prompt_label:
			instance.free()
			push_warning("World prompt label scenes must use world_prompt_label.gd.")
			return
		var label: world_prompt_label = instance as world_prompt_label
		add_child(label)
		labels.append(label)
	for i in entries.size():
		labels[i].set_prompt(entries[i])
	displayed_texts = texts
	_bounds_owner = null
	_layout_labels()
	_update_world_pose()


func _layout_labels() -> void:
	layout_size = Vector2.ZERO
	if labels.is_empty():
		return
	var columns: int = 1 if labels.size() <= single_column_limit else 2
	var rows: int = ceili(float(labels.size()) / columns)
	var widths: Array[float] = [0.0, 0.0]
	var heights: Array[float] = []
	heights.resize(rows)
	heights.fill(0.0)
	for index in labels.size():
		var label: world_prompt_label = labels[index]
		var font: Font = label.font if label.font != null else ThemeDB.fallback_font
		var measured: Vector2 = font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.width, label.font_size) * label.pixel_size
		widths[index % columns] = maxf(widths[index % columns], measured.x)
		var row: int = floori(float(index) / columns)
		heights[row] = maxf(heights[row], measured.y)
	var y: float = 0.0
	for row in rows:
		for column in columns:
			var index: int = row * columns + column
			if index < labels.size():
				labels[index].position = Vector3(0 if column == 0 else widths[0] + column_gap, -y, 0)
		y += heights[row] + row_gap
	layout_size = Vector2(widths[0] + (widths[1] + column_gap if columns == 2 else 0.0), y - row_gap)


func _update_world_pose() -> void:
	visible = false
	if displayed_texts.is_empty() or not is_instance_valid(camera):
		return
	var target: Node3D
	var bounds_owner: Node3D
	var anchor: Node3D
	var carrying: bool = pickup != null and pickup.is_holding_object()
	if carrying:
		target = pickup.held_object
		bounds_owner = target
		if placement != null and placement.is_building():
			# Use the original model bounds, excluding the ghost's direction arrow.
			target = placement.preview if placement.preview.visible else pickup.hold_position
	else:
		var provider: object_prompts = object_prompts.find_for(ray.get_looked_at()) if ray != null else null
		if provider == null or not provider.get_parent() is Node3D:
			return
		target = provider.get_parent()
		bounds_owner = target
		anchor = provider.world_anchor
	if not is_instance_valid(target):
		return
	if not is_instance_valid(_bounds_owner) or bounds_owner != _bounds_owner:
		_bounds_owner = bounds_owner
		_local_bounds = _measure_bounds(bounds_owner)
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var rectangle := Rect2()
	var depth: float = INF
	var projected: bool = false
	var camera_inverse: Transform3D = camera.global_transform.affine_inverse()
	for index in 8:
		var point: Vector3 = target.global_transform * _local_bounds.get_endpoint(index)
		var distance: float = -(camera_inverse * point).z
		if distance <= camera.near:
			continue
		var screen: Vector2 = camera.unproject_position(point)
		rectangle = rectangle.expand(screen) if projected else Rect2(screen, Vector2.ZERO)
		depth = minf(depth, distance)
		projected = true
	if not projected:
		return
	# Real geometry keeps wall occlusion. Place just in front of the model's nearest face.
	depth = maxf(camera.near + 0.05, depth - 0.08)
	var authored_anchor: bool = is_instance_valid(anchor) and not camera.is_position_behind(anchor.global_position)
	if authored_anchor:
		depth = maxf(camera.near + 0.05, -(camera_inverse * anchor.global_position).z)
	var factor: float = clampf(depth / reference_distance, 0.15, 8.0)
	var origin: Vector3 = camera.project_position(viewport_size * 0.5, depth)
	var pixels_per_metre: float = camera.unproject_position(origin + camera.global_basis.x).distance_to(viewport_size * 0.5)
	var pixels: Vector2 = layout_size * factor * pixels_per_metre
	var available: Vector2 = (viewport_size - Vector2.ONE * screen_margin * 2.0).max(Vector2.ONE)
	var fit: float = minf(1.0, minf(available.x / maxf(pixels.x, 1.0), available.y / maxf(pixels.y, 1.0)))
	factor *= fit
	pixels *= fit
	var position_on_screen := Vector2(rectangle.end.x + screen_gap, rectangle.get_center().y - pixels.y * 0.5)
	if authored_anchor:
		position_on_screen = camera.unproject_position(anchor.global_position)
	elif position_on_screen.x + pixels.x > viewport_size.x - screen_margin:
		position_on_screen.x = rectangle.position.x - screen_gap - pixels.x
	position_on_screen = position_on_screen.clamp(Vector2.ONE * screen_margin, (viewport_size - pixels - Vector2.ONE * screen_margin).max(Vector2.ONE * screen_margin))
	global_transform = Transform3D(camera.global_basis.orthonormalized().scaled(Vector3.ONE * factor), camera.project_position(position_on_screen, depth))
	var space: int = 1
	if pickup != null and is_instance_valid(pickup.player_body):
		space = int(pickup.player_body.get_meta("collision_space_mask", 1))
	for label in labels:
		label.layers = space
	visible = true


func _measure_bounds(target: Node3D) -> AABB:
	var result := AABB(Vector3(-0.15, -0.15, -0.15), Vector3.ONE * 0.3)
	if not is_instance_valid(target):
		return result
	var meshes: Array[Node] = target.find_children("*", "MeshInstance3D", true, false)
	if target is MeshInstance3D:
		meshes.push_front(target)
	var found: bool = false
	var inverse: Transform3D = target.global_transform.affine_inverse()
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null or not _model_part_visible(mesh, target):
			continue
		var bounds: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		result = result.merge(bounds) if found else bounds
		found = true
	return result


func _model_part_visible(mesh: Node3D, model: Node3D) -> bool:
	# Ignore hidden upgrade variants, but allow the held model's root to be hidden
	# while its cached geometry supplies bounds for the placement ghost.
	var part: Node = mesh
	while part != model and part != null:
		if part is Node3D and not part.visible:
			return false
		part = part.get_parent()
	return true
