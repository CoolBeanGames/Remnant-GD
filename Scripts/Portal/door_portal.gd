class_name door_portal
extends Node3D

signal crossed(inside: bool)
signal destination_changed(id: StringName, title: String)
@export var door: start_room_door
@export var player: CharacterBody3D
@export var destination_scene: PackedScene = preload("res://Scenes/Portal/sky_test_room.tscn")
@export var destinations: Array[portal_destination] = []
@export var cycle_key: Key = KEY_F9
@export var return_door_scene: PackedScene = preload("res://Scenes/Art/doorway.tscn")
@export var sky_position: Vector3 = Vector3(1600, 0, 0)
@export var activation_flag: String = "exited room"
@export var purchase_required: bool = false
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
## Copy the player's beam into the destination's isolated lighting space.
var portal_flashlight: SpotLight3D
var flashlight: SpotLight3D
var flashlight_properties: Array[StringName] = []
var camera: Camera3D
var original_cull_mask: int
var original_environment: Environment
var previous_camera_position: Vector3
var previous_bodies: Dictionary = {}
var graphics_revision: int = -1
var active_destination_id: StringName = &""
var switching: bool = false
var memory_id: StringName = &""
## F9 previews never complete or clear the purchased memory's ownership.
var debug_override: bool = false
var closing_memory: bool = false
## A resumed concrete room must disappear before a requested debug preview opens.
var queued_debug_preview: bool = false
## Cache resources in the background, while keeping just one instantiated area.
var warmed_scenes: Dictionary[String, PackedScene] = {}
var warming_paths: Array[String] = []
var warm_queue: Array[String] = []
var half_turn := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)

func _ready() -> void:
	add_to_group("story-portal")
	warmed_scenes.merge(scene_warmup.scenes)
	# The dummy renderer cannot safely create shared mesh RIDs on loader threads.
	# Rendered games warm one scene at a time; headless tools load on demand.
	if DisplayServer.get_name() != "headless":
		for destination in destinations:
			if destination != null and not warmed_scenes.has(destination.scene_path) and ResourceLoader.exists(destination.scene_path, "PackedScene") and not warm_queue.has(destination.scene_path):
				warm_queue.append(destination.scene_path)
		_start_next_warm()
	if door == null or player == null:
		return
	camera = player.get_node("Camera3D")
	flashlight = camera.get_node_or_null("SpotLight3D") as SpotLight3D
	if flashlight != null:
		for property in flashlight.get_property_list():
			var key := StringName(property.name)
			if int(property.usage) & PROPERTY_USAGE_STORAGE and (str(key).begins_with("light_") or str(key).begins_with("spot_") or str(key).begins_with("shadow_")) and key != &"light_cull_mask":
				flashlight_properties.append(key)
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

func activate(debug_preview: bool = false) -> void:
	pending = false
	if active or not Flags.check_flag(activation_flag) or destination_scene == null:
		return
	var saved_memory: Variant = Blackboard.read_data("active_memory_id")
	var saved_preview: bool = Blackboard.read_data("portal_debug_preview") == true
	if purchase_required and not debug_preview and not saved_preview and (not (saved_memory is String or saved_memory is StringName) or str(saved_memory).is_empty()):
		return
	memory_id = StringName(saved_memory) if not debug_preview and (saved_memory is String or saved_memory is StringName) else &""
	debug_override = debug_preview or saved_preview
	Blackboard.store_data("portal_debug_preview", debug_override)
	var selected: portal_destination = _destination(StringName(str(Blackboard.read_data("portal_destination_id"))))
	if selected == null and not destinations.is_empty():
		selected = destinations[0]
	var scene: PackedScene = _loaded_scene(selected.scene_path) if selected != null else destination_scene
	if scene == null:
		DevTools.log_error("Portal destination scene is missing.", "portal")
		return
	var instance: Node3D = _instantiate_room(scene)
	if instance == null:
		return
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
	if flashlight != null:
		portal_flashlight = SpotLight3D.new()
		portal_flashlight.name = "PortalFlashlight"
		portal_flashlight.light_cull_mask = 1
		portal_space.apply_actor(portal_flashlight, true)
		add_child(portal_flashlight)
	source_surface = _surface(source_frame)
	if not _install_room(instance):
		source_frame.free()
		viewport.free()
		return
	# Main-world lights must not reveal the isolated room via their shadows.
	for light in get_parent().find_children("*", "Light3D", true, false):
		if not room.is_ancestor_of(light):
			light.light_cull_mask &= ~portal_space.ROOM_LAYER
	active_destination_id = selected.id if selected != null else &""
	if selected != null:
		Blackboard.store_data("portal_destination_id", str(selected.id))
		destination_changed.emit(selected.id, selected.title)
	active = true
	DevTools.log_info("Story portal activated / %s / %s" % [active_destination_id, sky_position], "portal")
	inside = Blackboard.read_data("portal_inside") == true
	_set_player_space()
	previous_camera_position = camera.global_position
	_update_view()

func _instantiate_room(scene: PackedScene) -> Node3D:
	var instance: Node = scene.instantiate()
	if not instance is Node3D or not instance.get_node_or_null("Entrance") is Node3D:
		instance.free()
		DevTools.log_error("Portal rooms require a Node3D root and an Entrance marker.", "portal")
		return null
	return instance as Node3D

func _install_room(instance: Node3D) -> bool:
	room = instance
	# Apply layers before adding collision and lights to the shared world.
	portal_space.apply_actor(room, true)
	add_child(room)
	room.global_position = sky_position
	destination_frame = room.get_node("Entrance")
	if room is portal_room and room.environment != null:
		room_environment = room.environment
	Settings.register_environment(room_environment)
	return_surface = _surface(destination_frame)
	return_surface.layers = portal_space.ROOM_LAYER
	if return_door_scene != null:
		var return_door: Node3D = return_door_scene.instantiate() as Node3D
		return_door.set_script(preload("res://Scripts/Portal/portal_return_door.gd"))
		return_door.target = door
		return_door.portal = self
		room.add_child(return_door)
		return_door.global_transform = destination_frame.global_transform * Transform3D(Basis.IDENTITY, -source_offset)
	return true

func _destination(id: StringName) -> portal_destination:
	for entry in destinations:
		if entry != null and entry.id == id:
			return entry
	return null

func _loaded_scene(path: String) -> PackedScene:
	warm_queue.erase(path)
	if warmed_scenes.has(path):
		return warmed_scenes[path]
	if warming_paths.has(path):
		var scene: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
		warming_paths.erase(path)
		if scene != null:
			warmed_scenes[path] = scene
			DevTools.log_info("Memory resource ready / " + path.get_file(), "portal")
		return scene
	return load(path) as PackedScene

func _start_next_warm() -> void:
	if not warming_paths.is_empty() or warm_queue.is_empty():
		return
	var path: String = warm_queue.pop_front()
	if ResourceLoader.load_threaded_request(path, "PackedScene") == OK:
		warming_paths.append(path)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode != cycle_key and event.physical_keycode != cycle_key:
		return
	if get_tree().paused or DevTools.any_modal_open() or Blackboard.read_data("player_input_blocked") == true:
		return
	if cycle_destination():
		get_viewport().set_input_as_handled()

func cycle_destination() -> bool:
	if suspended:
		if Flags.check_flag(activation_flag):
			queued_debug_preview = true
			DevTools.log_info("F9 preview queued until the concrete room leaves view.", "portal")
			return true
		return false
	if switching or closing_memory:
		return false
	if purchase_required and not active and Flags.check_flag(activation_flag):
		activate(true)
		return active
	if destinations.is_empty():
		return false
	var index: int = -1
	for current in destinations.size():
		if destinations[current] != null and destinations[current].id == active_destination_id:
			index = current
			break
	for offset in range(1, destinations.size() + 1):
		var next: portal_destination = destinations[(index + offset) % destinations.size()]
		if next != null:
			return select_destination(next.id, true)
	return false

## Gameplay triggers can call this same API later, without synthesizing F9 input.
func select_destination(id: StringName, debug_preview: bool = false) -> bool:
	var selected: portal_destination = _destination(id)
	if not active or suspended or switching or (not memory_id.is_empty() and not debug_preview) or selected == null or selected.id == active_destination_id:
		return false
	if not ResourceLoader.exists(selected.scene_path, "PackedScene"):
		DevTools.log_error("Missing portal destination: %s" % selected.scene_path, "portal")
		return false
	switching = true
	_switch_destination.call_deferred(selected, debug_preview)
	return true

## A purchase selects synchronously before score is charged, retaining failure safety.
func open_memory(id: StringName, destination_id: StringName) -> bool:
	var selected: portal_destination = _destination(destination_id)
	if inside or suspended or switching or closing_memory or selected == null or not Flags.check_flag(activation_flag) or not ResourceLoader.exists(selected.scene_path, "PackedScene"):
		return false
	var old_memory: StringName = memory_id
	var old_debug: bool = debug_override
	var old_destination: Variant = Blackboard.read_data("portal_destination_id")
	debug_override = false
	Blackboard.store_data("portal_debug_preview", false)
	Blackboard.store_data("active_memory_id", str(id))
	if not active:
		Blackboard.store_data("portal_destination_id", str(destination_id))
		activate()
	else:
		memory_id = id
		if active_destination_id != destination_id:
			switching = true
			_switch_destination(selected)
		else:
			destination_changed.emit(selected.id, selected.title)
	if not active or active_destination_id != destination_id:
		memory_id = old_memory
		debug_override = old_debug
		Blackboard.store_data("portal_debug_preview", old_debug)
		if old_destination == null:
			Blackboard.remove_data("portal_destination_id")
		else:
			Blackboard.store_data("portal_destination_id", old_destination)
		if old_memory.is_empty():
			Blackboard.remove_data("active_memory_id")
		else:
			Blackboard.store_data("active_memory_id", str(old_memory))
		return false
	memory_id = id
	DevTools.log_info("Opened %s / %s" % [id, destination_id], "memories")
	return true

func memory_complete() -> bool:
	var entry: computer_entry = Progression.entries.get(memory_id)
	return not debug_override and entry != null and not entry.completion_flag.is_empty() and Flags.check_flag(entry.completion_flag)

func _close_memory() -> void:
	if inside or not active or not memory_complete():
		closing_memory = false
		return
	_evacuate_room_items()
	var finished_id: StringName = memory_id
	active = false
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	source_surface.hide()
	room.hide()
	source_frame.free()
	room.free()
	viewport.free()
	if is_instance_valid(portal_flashlight):
		portal_flashlight.free()
	portal_flashlight = null
	source_frame = null
	source_surface = null
	room = null
	destination_frame = null
	return_surface = null
	viewport = null
	portal_camera = null
	memory_id = &""
	debug_override = false
	Blackboard.remove_data("portal_debug_preview")
	active_destination_id = &""
	previous_bodies.clear()
	Blackboard.remove_data("active_memory_id")
	door.request_close()
	WorldState._physics_process(0.0)
	WorldState.capture()
	closing_memory = false
	Progression.changed.emit()
	DevTools.log_info("Closed %s after returning. Saved cargo evacuated." % finished_id, "memories")

func _switch_destination(selected: portal_destination, debug_preview: bool = false) -> void:
	if not active or suspended:
		switching = false
		return
	var scene: PackedScene = _loaded_scene(selected.scene_path)
	if scene == null or not scene.can_instantiate():
		switching = false
		return
	# Validate off-tree; this also supports inherited scenes. Only one room is
	# ever live in the world. A malformed replacement leaves the old room usable.
	var instance: Node3D = _instantiate_room(scene)
	if instance == null:
		switching = false
		return
	# A rejected scene must leave paid ownership/completion behavior unchanged.
	var owned: computer_entry = Progression.entries.get(memory_id)
	debug_override = debug_preview and (owned == null or owned.memory_destination != selected.id)
	Blackboard.store_data("portal_debug_preview", debug_override)
	if inside:
		var return_map: Transform3D = mapping(destination_frame, source_frame)
		var safe_position: Vector3 = source_frame.to_global(Vector3(0, -source_offset.y + .04, 1.25))
		return_map.origin += safe_position - return_map * player.global_position
		teleport_player(return_map)
	_evacuate_room_items()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	source_surface.hide()
	# The old collision/geometry leaves the tree before the next room enters.
	remove_child(room)
	room.free()
	room = null
	destination_frame = null
	return_surface = null
	if _install_room(instance):
		active_destination_id = selected.id
		Blackboard.store_data("portal_destination_id", str(selected.id))
		previous_bodies.clear()
		previous_camera_position = camera.global_position
		_set_player_space()
		_update_view()
		WorldState._physics_process(0.0)
		WorldState.capture()
		destination_changed.emit(selected.id, selected.title)
		DevTools.log_info("Portal destination selected / %s. Previous room unloaded." % selected.id, "portal")
	switching = false

func _evacuate_room_items() -> void:
	var actors: Array[Node3D] = []
	var children: Dictionary = {}
	for id in WorldState.items:
		var actor: Node3D = WorldState._actor(id)
		if is_instance_valid(actor) and actor.get_meta("portal_inside", false):
			actors.append(actor)
	for actor in actors:
		for child in _assembly_actors(actor):
			if child != actor:
				children[child.get_instance_id()] = true
	var pose_map: Transform3D = mapping(destination_frame, source_frame)
	# Keep purchased props, contained items and contraptions when cycling.
	# Scene furniture remains static and is deliberately not a saved item.
	for actor in actors:
		if actor is rotatable_item and actor.support != null:
			var host: Node3D = actor.support.get_ref() as Node3D
			if is_instance_valid(host) and room.is_ancestor_of(host):
				actor.on_picked_up()
				actor.on_released()
	for actor in actors:
		if not children.has(actor.get_instance_id()) and actor.get_meta("portal_inside", false):
			_transfer_assembly(actor, pose_map, false)
	# A malformed attachment cycle must not strand a saved actor in an empty world.
	for actor in actors:
		if actor.get_meta("portal_inside", false):
			_transfer_assembly(actor, pose_map, false)

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
	for path in warming_paths.duplicate():
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			_loaded_scene(path)
	_start_next_warm()
	if active:
		_update_view()

func _update_view() -> void:
	if suspended:
		source_surface.hide()
		return_surface.hide()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if is_instance_valid(portal_flashlight):
			portal_flashlight.hide()
		return
	source_frame.global_transform = door.global_transform * Transform3D(Basis(Vector3.UP, PI), source_offset)
	var size: Vector2 = camera.get_viewport().get_visible_rect().size * resolution_scale
	var target_size := Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))
	if viewport.size != target_size:
		viewport.size = target_size
	if graphics_revision != Settings.graphics_revision:
		Settings.apply_viewport(viewport)
		graphics_revision = Settings.graphics_revision
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
	_update_flashlight(mapping(from, to), open_front and viewport.render_target_update_mode != SubViewport.UPDATE_DISABLED)

func _update_flashlight(pose_map: Transform3D, visible_aperture: bool) -> void:
	if not is_instance_valid(portal_flashlight) or not is_instance_valid(flashlight):
		return
	portal_flashlight.visible = visible_aperture and flashlight.is_visible_in_tree()
	if not portal_flashlight.visible:
		return
	for key in flashlight_properties:
		var value: Variant = flashlight.get(key)
		if portal_flashlight.get(key) != value:
			portal_flashlight.set(key, value)
	portal_space.apply_actor(portal_flashlight, not inside)
	portal_flashlight.global_transform = pose_map * flashlight.global_transform

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
	movement.reset_platform_motion()
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
	if not inside and not memory_id.is_empty() and memory_complete():
		closing_memory = true
		_close_memory.call_deferred()

func _set_player_space() -> void:
	var footsteps: footstep_audio = player.get_node_or_null("footstep_sound_players")
	if room is portal_room and footsteps != null:
		if inside:
			footsteps.set_sound_override(room, room.left_foot_sounds, room.right_foot_sounds)
		else:
			footsteps.clear_sound_override(room)
	var headlight: Light3D = player.get_node_or_null("Camera3D/SpotLight3D")
	# A player-controlled flashlight keeps its on/off choice across crossings.
	# Bare legacy cameras still honor the room's automatic-light preference.
	if headlight != null and not headlight.has_method("set_powered"):
		headlight.visible = not (inside and room is portal_room and room.suppress_player_light)
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
		# A mounted carriage is dynamic, but belongs to its support's space.
		# Its loose/held parent crossing transfers the complete assembly instead.
		if actor is rotatable_item and actor.placed and actor.support != null and is_instance_valid(actor.support.get_ref()):
			previous_bodies.erase(id)
			continue
		var bodies: Array[RigidBody3D] = WorldState._bodies(actor)
		if bodies.is_empty() or bodies[0].freeze:
			previous_bodies.erase(id)
			continue
		var body: RigidBody3D = bodies[0]
		var in_room: bool = actor.get_meta("portal_inside", false)
		var from: Node3D = destination_frame if in_room else source_frame
		var to: Node3D = source_frame if in_room else destination_frame
		var previous: Vector3 = previous_bodies.get(id, body.global_position)
		if door.is_open and crosses_aperture(from, previous, body.global_position):
			var pose_map: Transform3D = mapping(from, to)
			_transfer_assembly(actor, pose_map, not in_room)
		previous_bodies[id] = body.global_position

func _assembly_actors(root: Node3D) -> Array[Node3D]:
	var actors: Array[Node3D] = [root]
	var props: Array[Node] = get_tree().get_nodes_in_group("placed-prop")
	var index: int = 0
	while index < actors.size():
		var current: Node3D = actors[index]
		if current.has_method("get_carried_bodies"):
			for body in current.get_carried_bodies():
				if not is_instance_valid(body):
					continue
				var actor: Node3D = physics_items.item_root(body)
				if not actors.has(actor):
					actors.append(actor)
		for prop in props:
			if prop is rotatable_item and not actors.has(prop) and prop.is_supported_by(current):
				actors.append(prop)
		index += 1
	return actors

func _transfer_assembly(root: Node3D, pose_map: Transform3D, inside_room: bool) -> void:
	var actors: Array[Node3D] = _assembly_actors(root)
	var poses: Array[Transform3D] = []
	for actor in actors:
		poses.append(actor.global_transform)
	var moved_bodies: Dictionary = {}
	for index in actors.size():
		var actor: Node3D = actors[index]
		actor.global_transform = pose_map * poses[index]
		portal_space.apply_actor(actor, inside_room)
		for body in WorldState._bodies(actor):
			if not moved_bodies.has(body.get_instance_id()):
				body.linear_velocity = pose_map.basis * body.linear_velocity
				body.angular_velocity = pose_map.basis * body.angular_velocity
				moved_bodies[body.get_instance_id()] = true
	# Every container remaps its own suspended collider snapshots exactly once.
	# Nested baskets and attached fan bags are independent saved actors.
	for actor in actors:
		if actor.has_method("portal_transform_contents"):
			actor.portal_transform_contents(pose_map, inside_room)
		var id: String = str(actor.get_meta("persistent_item_id", ""))
		var bodies: Array[RigidBody3D] = WorldState._bodies(actor)
		if not id.is_empty() and not bodies.is_empty():
			# Prevent a child from crossing again later in this same actor loop.
			previous_bodies[id] = bodies[0].global_position

func _exit_tree() -> void:
	# Join background resource loads before this world or engine is destroyed.
	for path in warming_paths.duplicate():
		_loaded_scene(path)
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
	if not value and queued_debug_preview:
		queued_debug_preview = false
		cycle_destination.call_deferred()
