class_name ceiling_chute
extends Node3D

@export var spawn_point: Node3D
@export var test_actor : PackedScene


func spawn():
	var actor :Node3D= test_actor.instantiate()
	Blackboard.read_data("game_root").add_child(actor)
	actor.global_position = spawn_point.global_position
