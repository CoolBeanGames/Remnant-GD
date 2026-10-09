class_name object_manager
extends Node3D

@export var rb : RigidBody3D
@export var start_force : float = 10

func _ready() -> void:
	if get_meta("restoring", false):
		return
	rb.apply_central_impulse((Vector3(randf(),randf(),randf()).normalized())*start_force)
