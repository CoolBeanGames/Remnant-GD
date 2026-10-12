@tool
class_name environment_art
extends Node3D

## Keep engine pose overrides separate from the immutable imported art model.
@export var pose_overrides: Dictionary[String, Transform3D] = {}

func _ready() -> void:
	for path in pose_overrides:
		var node: Node3D = get_node_or_null(NodePath(path)) as Node3D
		if node != null:
			node.transform = pose_overrides[path]
