class_name object_prompts
extends Node

## Put this component below the collider or any of its ancestors.
@export var prompts: prompt_set


func _ready() -> void:
	if get_parent() is Node3D:
		get_parent().add_to_group("look-prompt")


func get_prompts() -> prompt_set:
	if get_parent().has_method("get_look_prompts"):
		return get_parent().get_look_prompts()
	return prompts


static func find_for(target: Node) -> object_prompts:
	var current: Node = target
	while is_instance_valid(current):
		for child in current.get_children():
			if child is object_prompts:
				return child as object_prompts
		current = current.get_parent()
	return null
