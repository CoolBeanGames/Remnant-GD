class_name packed_buildable
extends RigidBody3D

@export var definition: buildable_definition


func _ready() -> void:
	add_to_group("pick-up")
	_disable_imported_colliders(self)
	if definition == null:
		push_warning("Packed buildable has no building definition.")


func _disable_imported_colliders(parent: Node) -> void:
	# The root rigid body owns the crate's physics. Imported static bodies
	# otherwise collide with that body and push/spin the crate from inside.
	for child in parent.get_children():
		if child is PhysicsBody3D:
			child.collision_layer = 0
			child.collision_mask = 0
		_disable_imported_colliders(child)
