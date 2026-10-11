class_name start_room
extends CSGCombiner3D

signal room_erased
signal exited
@export var door: start_room_door
@export var player: CharacterBody3D
@export var camera: Camera3D
@export var interior: CSGBox3D
## Conservative visibility estimate includes light colors, shadows and distance fog.
@export var darkness_threshold: float = 0.015
@export var unseen_delay: float = 0.2
@export var visibility_check_interval: float = 0.1
@export var respect_exit_flag: bool = true
@export var auto_close_on_exit: bool = true
@export_category("Room Audio")
@export var footsteps: footstep_audio
@export var left_foot_sounds: Array[AudioStream] = []
@export var right_foot_sounds: Array[AudioStream] = []
@export var mute_sfx_until_open: bool = true
var exit_armed: bool = false
var unseen_time: float = 0.0
var erased: bool = false
var visibility_elapsed: float = 0.0
var sfx_gated: bool = false
var previous_sfx_volume: float = 0.0
var previous_sfx_mute: bool = false
var settings_revision: int = 0
var has_left: bool = false
var door_meshes: Array[Node] = []
var mesh_faces: Dictionary[Mesh, PackedVector3Array] = {}

func _ready() -> void:
	if respect_exit_flag and Flags.check_flag("exited room"):
		_remove_room()
		return
	door.opened.connect(_on_door_opened)
	door_meshes = door.find_children("*", "MeshInstance3D", true, false)
	if mute_sfx_until_open:
		var index: int = AudioServer.get_bus_index("SFX")
		if index >= 0:
			previous_sfx_volume = AudioServer.get_bus_volume_db(index)
			previous_sfx_mute = AudioServer.is_bus_mute(index)
			settings_revision = Settings.revision
			Settings.world_gates += 1
			sfx_gated = true
			AudioServer.set_bus_volume_db(index, -80.0)
			AudioServer.set_bus_mute(index, true)
	_update_footsteps()
	var tallies := room_tallies.new()
	tallies.name = "TallyMarks"
	tallies.interior = interior
	add_child(tallies)

func _on_door_opened() -> void:
	exit_armed = true
	_restore_sfx()

func _restore_sfx() -> void:
	if not sfx_gated:
		return
	var index: int = AudioServer.get_bus_index("SFX")
	if index >= 0:
		AudioServer.set_bus_volume_db(index, previous_sfx_volume if settings_revision == Settings.revision else (linear_to_db(float(Settings.values.sfx)) if float(Settings.values.sfx) > 0 else -80.0))
		AudioServer.set_bus_mute(index, previous_sfx_mute)
	Settings.world_gates = maxi(0, Settings.world_gates - 1)
	sfx_gated = false

func _update_footsteps() -> void:
	if not is_instance_valid(footsteps) or not is_instance_valid(player):
		return
	var bounds := AABB(-interior.size * 0.5, interior.size).grow(0.1)
	if bounds.has_point(interior.to_local(player.global_position)):
		footsteps.set_sound_override(self, left_foot_sounds, right_foot_sounds)
	else:
		footsteps.clear_sound_override(self)

func _exit_tree() -> void:
	_restore_sfx()
	if is_instance_valid(footsteps):
		footsteps.clear_sound_override(self)

func _physics_process(delta: float) -> void:
	_update_footsteps()
	if erased or not exit_armed or not is_instance_valid(player):
		return
	var local_player := interior.to_local(player.global_position)
	var bounds := AABB(-interior.size * 0.5, interior.size).grow(0.35)
	if bounds.has_point(local_player):
		unseen_time = 0.0
		return
	if not door.is_strange:
		door.mark_strange()
	if not has_left:
		has_left = true
		if auto_close_on_exit:
			door.request_close()
		exited.emit()
	visibility_elapsed += delta
	if visibility_elapsed < visibility_check_interval:
		return
	var elapsed: float = visibility_elapsed
	visibility_elapsed = 0.0
	if is_room_visible():
		unseen_time = 0.0
		return
	unseen_time += elapsed
	if unseen_time >= unseen_delay:
		_remove_room()

func is_room_visible() -> bool:
	if not is_instance_valid(camera):
		return true
	# Reuse this snapshot for every visibility sample. Light energy/transforms
	# are still read live, and newly built lights are included on the next check.
	var lights: Array[Node] = get_tree().root.find_children("*", "Light3D", true, false)
	# Sample the viewport and actual mesh surfaces: partial doorway visibility counts.
	var viewport_size := camera.get_viewport().get_visible_rect().size
	for y in 9:
		for x in 13:
			var screen := viewport_size * Vector2((x + 0.5) / 13.0, (y + 0.5) / 9.0)
			var origin := camera.project_ray_origin(screen)
			var hit := _ray(origin, origin + camera.project_ray_normal(screen) * camera.far)
			if not hit.is_empty() and _is_room(hit.collider) and _lit(hit.position, lights):
				return true
	var generated := get_meshes()
	if generated.size() >= 2:
		if _mesh_visible(generated[1], global_transform * generated[0], lights):
			return true
	for mesh in door_meshes:
		if is_instance_valid(mesh) and mesh.is_visible_in_tree() and _mesh_visible(mesh.mesh, mesh.global_transform, lights):
			return true
	return false

func _mesh_visible(mesh: Mesh, pose: Transform3D, lights: Array[Node]) -> bool:
	if mesh == null:
		return false
	if not mesh_faces.has(mesh):
		# Bound the cache in case CSG changes create replacement mesh resources.
		if mesh_faces.size() >= 8:
			mesh_faces.clear()
		mesh_faces[mesh] = mesh.get_faces()
	var faces: PackedVector3Array = mesh_faces[mesh]
	for index in range(0, faces.size(), 3):
		var point: Vector3 = pose * ((faces[index] + faces[index + 1] + faces[index + 2]) / 3.0)
		if not camera.is_position_in_frustum(point):
			continue
		var hit := _ray(camera.global_position, point + (point - camera.global_position).normalized() * 0.02)
		if not hit.is_empty() and _is_room(hit.collider) and _lit(hit.position, lights):
			return true
	return false

func _is_room(node: Node) -> bool:
	return node == self or is_ancestor_of(node) or node == door or door.is_ancestor_of(node)

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _lit(point: Vector3, lights: Array[Node]) -> bool:
	var brightness: float = 0.0
	var environment := camera.environment
	if environment == null:
		environment = camera.get_world_3d().environment
	if environment != null:
		brightness += environment.ambient_light_color.get_luminance() * environment.ambient_light_energy
	for light in lights:
		if not is_instance_valid(light):
			continue
		if not light.is_visible_in_tree() or light.light_energy <= 0:
			continue
		var contribution: float = light.light_color.get_luminance() * light.light_energy
		if light is DirectionalLight3D:
			if light.shadow_enabled and not _ray(point + light.global_basis.z * 0.03, point + light.global_basis.z * 100.0).is_empty():
				continue
		else:
			var light_position: Vector3 = light.global_position
			var light_range: float
			if light is OmniLight3D:
				light_range = light.omni_range
			elif light is SpotLight3D:
				light_range = light.spot_range
			elif light is AreaLight3D:
				light_range = light.area_range
				var local_point: Vector3 = light.to_local(point)
				light_position = light.to_global(Vector3(clampf(local_point.x, -light.area_size.x * .5, light.area_size.x * .5), clampf(local_point.y, -light.area_size.y * .5, light.area_size.y * .5), 0))
			else:
				continue
			var distance: float = point.distance_to(light_position)
			if distance >= light_range:
				continue
			if light is SpotLight3D:
				if (-light.global_basis.z).angle_to(point - light.global_position) > deg_to_rad(light.spot_angle):
					continue
			if light.shadow_enabled:
				var hit := _ray(light_position, point)
				if not hit.is_empty() and hit.position.distance_to(point) > 0.06:
					continue
			contribution *= pow(1.0 - distance / light_range, 2.0)
		brightness += contribution
	if environment != null:
		var density: float = 0.0
		if environment.fog_enabled:
			density += environment.fog_density
		if environment.volumetric_fog_enabled:
			density += environment.volumetric_fog_density
		brightness *= exp(-density * camera.global_position.distance_to(point))
	return brightness >= darkness_threshold

func _remove_room() -> void:
	if erased:
		return
	erased = true
	DevTools.log_info("Start room removed after leaving the player's view.", "level")
	Flags.set_flag("exited room", true)
	room_erased.emit()
	queue_free()
