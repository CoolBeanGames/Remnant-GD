class_name buildable_definition
extends Resource

## Shared recipe used by both a package and its placed building.
@export var id: StringName
@export var building_scene: PackedScene
## Generic package scene: must not reference this definition (avoids resource cycles).
@export var packed_scene: PackedScene
@export var preview_scene: PackedScene
@export var look_prompts: prompt_set

@export_category("Placement")
@export var anchor_path: NodePath = ^"Anchor"
@export var surface_groups: Array[StringName] = [&"Floor"]
@export_range(0.0, 90.0) var maximum_slope_degrees: float = 15.0
@export var align_to_surface: bool = true
@export_range(0.001, 0.1) var surface_offset: float = 0.01
@export_range(0.5, 30.0) var placement_distance: float = 8.0
@export_flags_3d_physics var placement_mask: int = 1

@export_category("Rotation")
## Axis is local to the building before its surface alignment.
@export var rotation_axis: Vector3 = Vector3.UP
@export_range(1.0, 180.0) var rotation_step_degrees: float = 15.0


func accepts_surface(collider: Node, normal: Vector3) -> bool:
	if normal.dot(Vector3.UP) < cos(deg_to_rad(maximum_slope_degrees)):
		return false
	if surface_groups.is_empty():
		return true
	var current: Node = collider
	while current != null:
		for group in surface_groups:
			if current.is_in_group(group):
				return true
		current = current.get_parent()
	return false
