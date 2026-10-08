class_name player_building
extends Node

@export_category("References")
@export var pickup: player_pickup
@export var camera: Camera3D
@export var ray: raycaster

@export_category("Preview")
@export var valid_color: Color = Color(0.15, 0.9, 0.65, 0.45)
@export var invalid_color: Color = Color(1.0, 0.2, 0.15, 0.45)

var package: packed_buildable
var preview: Node3D
var definition: buildable_definition
var placement_valid: bool = false
var rotation_angle: float = 0.0
var anchor_position: Vector3 = Vector3.ZERO
var original_basis: Basis = Basis.IDENTITY
var preview_material: StandardMaterial3D
var preview_shapes: Array[CollisionShape3D] = []
var package_hidden: bool = false
var package_original_visible: bool = true


func _physics_process(_delta: float) -> void:
	_sync_package()
	if Input.is_action_just_pressed("build"):
		if is_building():
			try_build()
		else:
			start_building()
	if is_building():
		_update_preview()
	elif Input.is_action_just_released("unbuild"):
		try_unbuild()


func _unhandled_input(event: InputEvent) -> void:
	if not is_building() or not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	var direction: float = 0.0
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = 1.0
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		direction = -1.0
	else:
		return
	rotation_angle = wrapf(
		rotation_angle + deg_to_rad(definition.rotation_step_degrees) * direction,
		-PI, PI
	)
	get_viewport().set_input_as_handled()


func is_building() -> bool:
	return is_instance_valid(package) and is_instance_valid(preview)


func _sync_package() -> void:
	var held: packed_buildable = null
	if pickup != null and pickup.is_holding_object():
		held = pickup.held_object as packed_buildable
	if held == package:
		return
	_clear_preview()
	if held == null or held.definition == null:
		return
	package = held
	definition = held.definition


## The first B press starts placement; carrying a package alone never shows a ghost.
func start_building() -> bool:
	_sync_package()
	if is_building() or not is_instance_valid(package) or definition == null:
		return false
	var scene: PackedScene = definition.preview_scene
	if scene == null:
		scene = definition.building_scene
	if scene == null or camera == null:
		return false
	var instance: Node = scene.instantiate()
	if not instance is Node3D:
		instance.free()
		return false
	preview = instance as Node3D
	preview_material = StandardMaterial3D.new()
	preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_material.no_depth_test = false
	_prepare_preview(preview)
	get_tree().root.add_child(preview)
	preview.visible = false
	original_basis = preview.transform.basis
	var anchor: Node3D = preview.get_node_or_null(definition.anchor_path) as Node3D
	if anchor == null:
		push_warning("Building preview is missing its configured anchor.")
		_clear_preview()
		return false
	anchor_position = preview.global_transform.affine_inverse() * anchor.global_position
	package_original_visible = package.visible
	package.visible = false
	package_hidden = true
	pickup.cancel_throw_charge()
	_update_preview()
	return true


## F cancels placement back to carrying without releasing the crate.
func cancel_building() -> bool:
	if not is_building():
		return false
	_clear_preview()
	_sync_package()
	return true


## Strip scripts before entering the tree so ghosts cannot run gameplay or register.
func _prepare_preview(node: Node) -> void:
	node.set_script(null)
	node.process_mode = Node.PROCESS_MODE_DISABLED
	for group in node.get_groups():
		node.remove_from_group(group)
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	if node is CollisionShape3D:
		preview_shapes.append(node)
	if node is GeometryInstance3D:
		node.material_override = preview_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is Light3D:
		node.visible = false
	if node is AudioStreamPlayer3D or node is AudioStreamPlayer:
		node.autoplay = false
	for child in node.get_children():
		_prepare_preview(child)


func _query_exclusions(include_player: bool = true) -> Array[RID]:
	var excluded: Array[RID] = []
	if include_player and pickup != null and is_instance_valid(pickup.player_body):
		excluded.append(pickup.player_body.get_rid())
	if pickup != null:
		excluded.append_array(pickup.get_held_collision_rids())
	return excluded


func _update_preview() -> void:
	placement_valid = false
	if not is_building() or not is_instance_valid(camera):
		return
	var from: Vector3 = camera.global_position
	var to: Vector3 = from - camera.global_basis.z * definition.placement_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, definition.placement_mask)
	query.exclude = _query_exclusions()
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	preview.visible = not hit.is_empty()
	if hit.is_empty():
		return
	var normal: Vector3 = hit["normal"]
	var axis: Vector3 = definition.rotation_axis.normalized()
	if axis.is_zero_approx():
		axis = Vector3.UP
	var surface_basis := Basis.IDENTITY
	if definition.align_to_surface:
		surface_basis = Basis(Quaternion(Vector3.UP, normal))
	var basis: Basis = surface_basis * Basis(axis, rotation_angle) * original_basis
	var origin: Vector3 = hit["position"] + normal * definition.surface_offset - basis * anchor_position
	preview.global_transform = Transform3D(basis, origin)
	placement_valid = definition.accepts_surface(hit["collider"] as Node, normal)
	if placement_valid:
		placement_valid = _has_clearance(space)
	preview_material.albedo_color = valid_color if placement_valid else invalid_color


func _has_clearance(space: PhysicsDirectSpaceState3D) -> bool:
	for shape in preview_shapes:
		if shape.disabled or shape.shape == null:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = shape.global_transform
		query.collision_mask = definition.placement_mask
		query.exclude = _query_exclusions(false)
		query.margin = 0.001
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true


func try_build() -> bool:
	_sync_package()
	if not is_building() or pickup.held_object != package:
		return false
	# Recheck the current aim/clearance; never build using an old valid position.
	_update_preview()
	if not placement_valid or definition.building_scene == null:
		return false
	var instance: Node = definition.building_scene.instantiate()
	if not instance is buildable:
		push_warning("Building scenes must have a buildable root.")
		instance.free()
		return false
	var building: buildable = instance as buildable
	building.definition = definition
	var parent: Node = _world_parent()
	# Establish the final pose before _ready registers this building.
	var pose: Transform3D = preview.global_transform
	if parent is Node3D:
		building.transform = parent.global_transform.affine_inverse() * pose
	else:
		building.transform = pose
	parent.add_child(building)
	if not pickup.consume_held_object(package):
		Buildings.unregister_building(building)
		building.queue_free()
		return false
	_clear_preview()
	return true


func try_unbuild() -> bool:
	if pickup == null or pickup.is_holding_object() or ray == null:
		return false
	if not is_instance_valid(pickup.hold_position):
		return false
	var target: Node = ray.get_looked_at()
	while is_instance_valid(target) and not target is buildable:
		target = target.get_parent()
	var building: buildable = target as buildable
	if not is_instance_valid(building) or building.is_queued_for_deletion():
		return false
	if building.definition == null or building.definition.packed_scene == null:
		return false
	var instance: Node = building.definition.packed_scene.instantiate()
	if not instance is packed_buildable:
		instance.free()
		return false
	var packed: packed_buildable = instance as packed_buildable
	packed.definition = building.definition
	_world_parent().add_child(packed)
	packed.global_transform = pickup.hold_position.global_transform
	if not pickup.pickup_object(packed):
		packed.queue_free()
		return false
	Buildings.unregister_building(building)
	building.queue_free()
	_sync_package()
	return true


func _world_parent() -> Node:
	var parent: Node = Blackboard.read_data("game_root") as Node
	return parent if is_instance_valid(parent) else get_tree().root


func _clear_preview() -> void:
	if package_hidden and is_instance_valid(package):
		package.visible = package_original_visible
	package_hidden = false
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null
	package = null
	definition = null
	preview_shapes.clear()
	preview_material = null
	placement_valid = false
	rotation_angle = 0.0


func _exit_tree() -> void:
	_clear_preview()
