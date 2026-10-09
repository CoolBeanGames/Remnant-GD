extends Node

@export var target : Node

func interact():
	if is_instance_valid(target) and target.has_method("interact"):
		target.interact()
