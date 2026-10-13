@tool
class_name environment_art
extends Node3D

## Keep engine pose overrides separate from the immutable imported art model.
@export var pose_overrides: Dictionary[String, Transform3D] = {}
## Match imported mesh names; material overrides stay separate from source art.
@export var material_overrides: Dictionary[String, Material] = {}

func _ready() -> void:
	for path in pose_overrides:
		var node: Node3D = get_node_or_null(NodePath(path)) as Node3D
		if node != null:
			node.transform = pose_overrides[path]
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		for fragment in material_overrides:
			if fragment.to_lower() in str(mesh.name).to_lower():
				mesh.material_override = material_overrides[fragment]
