class_name pickup_target
extends Area3D

@export_range(0.05, 1.0, 0.01) var radius: float = 0.25
var body: RigidBody3D

func _ready() -> void:
	body = physics_items.rigid_body(get_parent())
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	$Shape.shape = sphere

func can_target() -> bool:
	return is_instance_valid(body) and not body.get_meta("carried_by_player", false) and not body.is_queued_for_deletion()
