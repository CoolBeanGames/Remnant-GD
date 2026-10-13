class_name grind_debris
extends RigidBody3D

var remaining: float = 0

func _ready() -> void:
	add_to_group("machine-immune")
	reset()

func reset() -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	remaining = 0
	hide()

func launch(pose: Transform3D, impulse: Vector3, lifetime: float, layer: int, mask: int) -> void:
	global_transform = pose
	remaining = lifetime
	collision_layer = layer
	collision_mask = mask
	freeze = false
	sleeping = false
	show()
	linear_velocity = impulse
	angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
