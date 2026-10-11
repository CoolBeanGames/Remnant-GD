class_name door_portal
extends Node3D

signal crossed(inside: bool)
@export var door: start_room_door
@export var player: CharacterBody3D
@export var destination_scene: PackedScene = preload("res://Scenes/Portal/sky_test_room.tscn")
@export var return_door_scene: PackedScene = preload("res://Models/Door/source/doorway_animated.glb")
@export var sky_position: Vector3 = Vector3(1600, 0, 0)
@export var activation_flag: String = "exited room"
@export var source_offset: Vector3 = Vector3(0, 1.7195, 0)
@export var aperture: Vector2 = Vector2(1.74, 3.18)
@export_range(0.25, 1.0, 0.05) var resolution_scale: float = 1.0
@export var room_environment: Environment = preload("res://Data/Portal/sky_environment.tres")
var active: bool = false
var inside: bool = false
var pending: bool = false
var suspended: bool = false
var room: Node3D
var source_frame: Marker3D
var destination_frame: Node3D
var source_surface: MeshInstance3D
var return_surface: MeshInstance3D
var viewport: SubViewport
var portal_camera: Camera3D
var camera: Camera3D
var original_cull_mask: int
var original_environment: Environment
var previous_camera_position: Vector3
var previous_bodies: Dictionary = {}
var half_turn := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)

func _ready() -> void:
	if door == null or player == null:
		return
	camera = player.get_node("Camera3D")
	original_cull_mask = camera.cull_mask & ~portal_space.ROOM_LAYER
	original_environment = camera.environment
	camera.cull_mask = original_cull_mask
	Flags.connect_to_flag(activation_flag, [request_activation])
	if Flags.check_flag(activation_flag):
		request_activation()

func request_activation() -> void:
	if active or pending:
		return
	pending = true
	activate.call_deferred()

func activate() -> void:
	pending = false
	if active or not Flags.check_flag(activation_flag) or destination_scene == null:
		return
	room = destination_scene.instantiate() as Node3D
	add_child(room)
	room.global_position = sky_position
	destination_frame = room.get_node("Entrance")
	portal_space.apply_actor(room, true)
	# Main-world lights must not reveal the isolated room via their shadows.
	for light in get_parent().find_children("*", "Light3D", true, false):
		if not room.is_ancestor_of(light):
			light.light_cull_mask &= ~portal_space.ROOM_LAYER
	source_frame = Marker3D.new()
	add_child(source_frame)
	source_frame.global_transform = door.global_transform * Transform3D(Basis(Vector3.UP, PI), source_offset)
	viewport = SubViewport.new()
	viewport.name = "PortalView"
	viewport.world_3d = get_world_3d()
	viewport.handle_input_locally = false
	viewport.audio_listener_enable_3d = false
	# Keep the portal texture linear, so the main viewport performs its single
	# display conversion instead of treating an sRGB image as linear lighting.
	viewport.use_hdr_2d = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	add_child(viewport)
	portal_camera = Camera3D.new()
	viewport.add_child(portal_camera)
	portal_camera.current = true
	source_surface = _surface(source_frame)
	return_surface = _surface(destination_frame)
	if return_door_scene != null:
		var return_door: Node3D = return_door_scene.instantiate() as Node3D
		return_door.set_script(preload("res://Scripts/Portal/portal_return_door.gd"))
		return_door.target = door
		room.add_child(return_door)
		return_door.global_transform = destination_frame.global_transform * Transform3D(Basis.IDENTITY, -source_offset)
	active = true
	DevTools.log_info("Story portal activated at %s." % sky_position, "portal")
	inside = Blackboard.read_data("portal_inside") == true
	_set_player_space()
	previous_camera_position = camera.global_position
	_update_view()

func _surface(frame: Node3D) -> MeshInstance3D:
	var surface := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = aperture
	surface.mesh = quad
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://Shaders/portal_view.gdshader")
	material.set_shader_parameter("portal_view", viewport.get_texture())
	surface.material_override = material
	frame.add_child(surface)
	return surface

func mapping(from: Node3D, to: Node3D) -> Transform3D:
	return to.global_transform * half_turn * from.global_transform.affine_inverse()

func _process(_delta: float) -> void:
	if active:
		_update_view()

func _update_view() -> void:
	if suspended:
		source_surface.hide()
		return_surface.hide()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	source_frame.global_transform = door.global_transform * Transform3D(Basis(Vector3.UP, PI), source_offset)
	var size: Vector2 = camera.get_viewport().get_visible_rect().size * resolution_scale
	var target_size := Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))
	if viewport.size != target_size:
		viewport.size = target_size
	if viewport.msaa_3d != camera.get_viewport().msaa_3d:
		viewport.msaa_3d = camera.get_viewport().msaa_3d
	portal_camera.fov = camera.fov
	portal_camera.keep_aspect = camera.keep_aspect
	portal_camera.near = camera.near
	portal_camera.far = camera.far
	portal_camera.attributes = camera.attributes
	var from: Node3D = destination_frame if inside else source_frame
	var to: Node3D = source_frame if inside else destination_frame
	portal_camera.global_transform = mapping(from, to) * camera.global_transform
	portal_camera.cull_mask = original_cull_mask if inside else portal_space.ROOM_LAYER
	portal_camera.environment = original_environment if inside else room_environment
	var open_front: bool = door.is_open and from.to_local(camera.global_position).z > -0.03
	source_surface.visible = open_front and not inside
	return_surface.visible = open_front and inside
	source_surface.layers = 1
	return_surface.layers = portal_space.ROOM_LAYER
	# A second full-resolution render is only needed while its doorway can
	# appear on screen. Plane rejection preserves partially visible doorways.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if open_front and _aperture_in_frustum(from) else SubViewport.UPDATE_DISABLED

func _aperture_in_frustum(frame: Node3D) -> bool:
	var corners := PackedVector3Array()
	for x in [-1.0, 1.0]:
		for y in [-1.0, 1.0]:
			corners.append(frame.to_global(Vector3(x * aperture.x * .5, y * aperture.y * .5, 0)))
	for plane: Plane in camera.get_frustum():
		var outside: bool = true
		for corner: Vector3 in corners:
			if plane.distance_to(corner) <= .01:
				outside = false
				break
		if outside:
			return false
	return true

func crosses_aperture(frame: Node3D, previous: Vector3, current: Vector3) -> bool:
	var a: Vector3 = frame.to_local(previous)
	var b: Vector3 = frame.to_local(current)
	if a.z <= 0 or b.z > 0:
		return false
	var point: Vector3 = a.lerp(b, a.z / (a.z - b.z))
	return absf(point.x) < aperture.x * .5 and absf(point.y) < aperture.y * .5

func _physics_process(_delta: float) -> void:
	if not active or suspended:
		return
	var from: Node3D = destination_frame if inside else source_frame
	var to: Node3D = source_frame if inside else destination_frame
	if door.is_open and crosses_aperture(from, previous_camera_position, camera.global_position):
		teleport_player(mapping(from, to))
	previous_camera_position = camera.global_position
	_transfer_loose_items()

func teleport_player(pose_map: Transform3D) -> void:
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var placement: prop_placement = player.get_node("Controllers/Prop_Placement")
	if placement.is_building():
		placement.cancel_building()
	inside = not inside
	DevTools.log_info("Player entered the story room." if inside else "Player returned through the story portal.", "portal")
	player.global_transform = pose_map * player.global_transform
	player.velocity = pose_map.basis * player.velocity
	var movement: Node = player.get_node("Controllers/Player_Move_Controller")
	for property in ["wind_velocity", "applied_wind", "velocity_target"]:
		movement.set(property, pose_map.basis * movement.get(property))
	var look: Node = player.get_node("Controllers/Player_Look_Controller")
	look.target_rotation = Vector2(camera.rotation_degrees.x, player.rotation_degrees.y)
	look.look_rotation = look.target_rotation
	look.mouse_input = Vector2.ZERO
	pickup.teleport_held(pose_map, inside)
	Blackboard.store_data("portal_inside", inside)
	_set_player_space()
	previous_camera_position = camera.global_position
	_update_view()
	WorldState._physics_process(0.0)
	WorldState.capture()
	crossed.emit(inside)

func _set_player_space() -> void:
	portal_space.apply_actor(player, inside)
	player.get_node("Camera3D/RayCast3D").collision_mask = player.collision_mask
	player.get_node("Camera3D/RayCast3D")._set_looked_at(null)
	camera.cull_mask = portal_space.ROOM_LAYER if inside else original_cull_mask
	camera.environment = room_environment if inside else original_environment

func _transfer_loose_items() -> void:
	for id in previous_bodies.keys():
		if not WorldState.items.has(id):
			previous_bodies.erase(id)
	for id in WorldState.items.keys():
		var actor: Node3D = WorldState._actor(id)
		if not is_instance_valid(actor) or actor.get_meta("carried_by_player", false):
			previous_bodies.erase(id)
			continue
		var bodies: Array[RigidBody3D] = WorldState._bodies(actor)
		if bodies.is_empty() or bodies[0].freeze:
			continue
		var body: RigidBody3D = bodies[0]
		var in_room: bool = actor.get_meta("portal_inside", false)
		var from: Node3D = destination_frame if in_room else source_frame
		var to: Node3D = source_frame if in_room else destination_frame
		var previous: Vector3 = previous_bodies.get(id, body.global_position)
		if door.is_open and crosses_aperture(from, previous, body.global_position):
			var pose_map: Transform3D = mapping(from, to)
			actor.global_transform = pose_map * actor.global_transform
			for rigid in bodies:
				rigid.linear_velocity = pose_map.basis * rigid.linear_velocity
				rigid.angular_velocity = pose_map.basis * rigid.angular_velocity
			portal_space.apply_actor(actor, not in_room)
			for prop in get_tree().get_nodes_in_group("placed-prop"):
				if prop is rotatable_item and prop != actor and prop.is_supported_by(actor):
					portal_space.apply_actor(prop, not in_room)
					prop.sync_support_pose()
		previous_bodies[id] = body.global_position

func _exit_tree() -> void:
	if is_instance_valid(camera):
		camera.cull_mask = original_cull_mask
		camera.environment = original_environment
	previous_bodies.clear()

func set_suspended(value: bool) -> void:
	suspended = value
	if active:
		previous_camera_position = camera.global_position
		previous_bodies.clear()
		_update_view()
