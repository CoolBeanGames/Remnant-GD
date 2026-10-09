class_name rotatable_item
extends RigidBody3D

@export var carry_prompts: prompt_set
@export var rotation_step: float = 15.0
@export var air_placeable: bool = false
@export var build_direction_preview: PackedScene
var held: bool = false
var rotation_axis: int = 1
var held_rotation: Basis = Basis.IDENTITY
var placed: bool = false
var support: WeakRef
var support_pose: Transform3D


func _ready() -> void:
	# Imported static bodies must not fight the prop's root rigid-body collider.
	for body in find_children("*", "StaticBody3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0


func on_picked_up() -> void:
	held = true
	var previous_host: Node3D = support.get_ref() as Node3D if support != null else null
	if previous_host is PhysicsBody3D:
		remove_collision_exception_with(previous_host)
	placed = false
	remove_from_group("placed-prop")
	support = null
	freeze = false
	# Preserve the orientation at pickup relative to the camera.
	var camera: Camera3D = get_viewport().get_camera_3d()
	held_rotation = camera.global_basis.inverse() * global_basis if camera != null else global_basis


func on_released() -> void:
	held = false


func get_carry_prompts() -> prompt_set:
	return carry_prompts


func get_hold_offset() -> Vector3:
	return Vector3(0, -0.5, -1.0)


func get_hold_rotation() -> Basis:
	return held_rotation


func get_rotation_axis_name() -> String:
	return ["X", "Y", "Z"][rotation_axis]


func cycle_rotation_axis() -> void:
	rotation_axis = (rotation_axis + 1) % 3


func rotate_held(direction: float) -> void:
	held_rotation = (held_rotation * Basis(Basis.IDENTITY[rotation_axis], deg_to_rad(rotation_step) * direction)).orthonormalized()


func place_on(host: Node3D) -> void:
	held = false
	placed = true
	add_to_group("placed-prop")
	freeze = true
	support = weakref(host) if host != null else null
	if host != null:
		support_pose = host.global_transform.affine_inverse() * global_transform
		if host is PhysicsBody3D:
			add_collision_exception_with(host)


func _physics_process(_delta: float) -> void:
	sync_support_pose()


func sync_support_pose() -> void:
	if not placed:
		return
	if air_placeable and support == null:
		return
	var host: Node3D = support.get_ref() as Node3D if support != null else null
	if not is_instance_valid(host) or not host.is_inside_tree():
		placed = false
		remove_from_group("placed-prop")
		freeze = false
	else:
		global_transform = host.global_transform * support_pose


func is_supported_by(root: Node3D) -> bool:
	var current: Node3D = support.get_ref() as Node3D if support != null else null
	var seen: Array[Node3D] = []
	while is_instance_valid(current) and not seen.has(current):
		if current == root or root.is_ancestor_of(current):
			return true
		seen.append(current)
		if current is rotatable_item and current.support != null:
			current = current.support.get_ref() as Node3D
		else:
			current = current.get_parent() as Node3D
	return false
