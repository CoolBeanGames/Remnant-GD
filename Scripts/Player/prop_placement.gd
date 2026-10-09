class_name prop_placement
extends Node

@export var pickup: player_pickup
@export var camera: Camera3D
@export var reach: float = 6.0
var preview: Node3D
var shapes: Array[Dictionary] = []
var placement_valid: bool = false
var host: Node3D
var item: rotatable_item
var material: StandardMaterial3D
var carry_rotation: Basis
var carry_axis: int


func is_building() -> bool:
	return is_instance_valid(preview)


func _unhandled_input(event: InputEvent) -> void:
	if Blackboard.read_data("player_input_blocked"):
		return
	if event.is_action_released("unbuild") and not pickup.is_holding_object():
		var target: Node3D = pickup.ray.get_looked_at()
		if target is rotatable_item and target.placed:
			pickup.pickup_object(target)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("place_in_air"):
		if pickup.is_holding_object() and pickup.held_object is rotatable_item and pickup.held_object.air_placeable:
			place_in_air()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("build"):
		if is_building():
			try_build()
		else:
			start_building()
		get_viewport().set_input_as_handled()
	elif is_building() and event.is_action_pressed("rotate_axis"):
		item.cycle_rotation_axis()
		get_viewport().set_input_as_handled()
	elif is_building() and event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			item.rotate_held(1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
			_update_preview()
			get_viewport().set_input_as_handled()


func place_in_air() -> bool:
	if not pickup.is_holding_object() or not pickup.held_object is rotatable_item or not pickup.held_object.air_placeable:
		return false
	var prop: rotatable_item = pickup.held_object
	var pose: Transform3D = prop.global_transform
	if is_building():
		pose.basis = pickup.hold_position.global_basis * carry_rotation
	pickup.drop_object()
	prop.global_transform = pose
	prop.place_on(null)
	return true

func start_building() -> bool:
	if is_building():
		return false
	if pickup == null or camera == null or not pickup.is_holding_object() or not pickup.held_object is rotatable_item:
		return false
	item = pickup.held_object
	carry_rotation = item.held_rotation
	carry_axis = item.rotation_axis
	item.held_rotation = Basis.IDENTITY
	item.rotation_axis = 1
	preview = item.duplicate() as Node3D
	shapes.clear()
	for collider in item.find_children("*", "CollisionShape3D", true, false):
		if collider.get_parent() is PhysicsBody3D and collider.shape != null:
			shapes.append({"shape": collider.shape, "pose": item.global_transform.affine_inverse() * collider.global_transform})
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_prepare(preview)
	if item.build_direction_preview != null:
		preview.add_child(item.build_direction_preview.instantiate())
	get_tree().root.add_child(preview)
	item.hide()
	if item.has_method("on_held_transform_updated"):
		item.on_held_transform_updated()
	pickup.cancel_throw_charge()
	_update_preview()
	return true


func _prepare(node: Node) -> void:
	node.set_script(null)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for group in node.get_groups():
		node.remove_from_group(group)
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is MeshInstance3D:
		node.material_override = material
	if node is Light3D:
		node.visible = false
	if node is CPUParticles3D:
		node.emitting = false
	if node is AudioStreamPlayer3D:
		node.stop()
		node.autoplay = false
	for child in node.get_children():
		_prepare(child)


func _physics_process(_delta: float) -> void:
	if is_building():
		if not pickup.is_holding_object() or pickup.held_object != item:
			cancel_building()
		else:
			_update_preview()


func _update_preview() -> void:
	placement_valid = false
	host = null
	var excluded: Array[RID] = [item.get_rid(), pickup.player_body.get_rid()]
	for state in physics_items.collider_states(item):
		var collider: CollisionObject3D = state.node.get_ref() as CollisionObject3D
		if is_instance_valid(collider):
			excluded.append(collider.get_rid())
	var start: Vector3 = camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start, start - camera.global_basis.z * reach, pickup.player_body.collision_mask)
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	preview.visible = not hit.is_empty()
	if hit.is_empty():
		return
	host = hit.collider as Node3D
	var normal: Vector3 = hit.normal
	var basis := Basis(Quaternion(Vector3.UP, normal)) * item.held_rotation
	var lowest: float = INF
	for state in shapes:
		var bounds: AABB = state.shape.get_debug_mesh().get_aabb()
		for corner in 8:
			lowest = minf(lowest, normal.dot(basis * (state.pose * bounds.get_endpoint(corner))))
	preview.global_transform = Transform3D(basis, hit.position + normal * (.015 - lowest))
	placement_valid = not shapes.is_empty()
	excluded.append(hit.collider.get_rid())
	for state in shapes:
		var shape_query := PhysicsShapeQueryParameters3D.new()
		shape_query.shape = state.shape
		shape_query.transform = preview.global_transform * state.pose
		shape_query.exclude = excluded
		shape_query.collision_mask = pickup.player_body.collision_mask
		if not space.intersect_shape(shape_query, 1).is_empty():
			placement_valid = false
	material.albedo_color = Color(.8, .9, .8, .4) if placement_valid else Color(1, .3, .3, .4)


func try_build() -> bool:
	if not is_building():
		return false
	_update_preview()
	if not placement_valid:
		return false
	var pose: Transform3D = preview.global_transform
	var target: Node3D = host
	var placed_item: rotatable_item = item
	cancel_building()
	pickup.drop_object()
	placed_item.global_transform = pose
	placed_item.place_on(target)
	return true


func cancel_building() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
	if is_instance_valid(item):
		item.held_rotation = carry_rotation
		item.rotation_axis = carry_axis
		if pickup.is_holding_object() and pickup.held_object == item:
			item.global_basis = pickup.hold_position.global_basis * carry_rotation
		item.show()
		if item.has_method("on_held_transform_updated"):
			item.on_held_transform_updated()
	item = null
	shapes.clear()
	placement_valid = false


func _exit_tree() -> void:
	cancel_building()
