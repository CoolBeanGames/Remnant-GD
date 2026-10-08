class_name object_prompts
extends Node

## Put this component below the collider or any of its ancestors.
@export var prompts: prompt_set


func _ready() -> void:
	if get_parent() is Node3D:
		get_parent().add_to_group("look-prompt")


func get_prompts() -> prompt_set:
	if prompts != null:
		return prompts
	# Generic/repacked crates inherit the recipe's prompts without scene duplication.
	var parent: Node = get_parent()
	if parent is packed_buildable and parent.definition != null:
		return parent.definition.look_prompts
	return null


static func find_for(target: Node) -> object_prompts:
	var current: Node = target
	while is_instance_valid(current):
		for child in current.get_children():
			if child is object_prompts:
				return child as object_prompts
		current = current.get_parent()
	return null
