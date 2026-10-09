class_name world_boundary
extends StaticBody3D

@export var centre_target: Node3D
@export var half_extent: float = 500.0
@export var wall_thickness: float = 4.0

func _ready() -> void:
	if centre_target != null:
		global_position = centre_target.global_position
	for axis in 3:
		for direction in [-1, 1]:
			var shape := BoxShape3D.new()
			shape.size = Vector3.ONE * (half_extent * 2 + wall_thickness * 2)
			shape.size[axis] = wall_thickness
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position[axis] = direction * (half_extent + wall_thickness * .5)
			add_child(collision)
