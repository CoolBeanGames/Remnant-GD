extends Node3D
@export var roation_speed : Vector3 = Vector3(0,0,0)


func _process(delta: float) -> void:
	rotation_degrees+=roation_speed * delta
