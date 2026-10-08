extends Node

@export var target : Node

func interact():
	print("interact pass through")
	if target.has_method("interact"):
		target.interact()
