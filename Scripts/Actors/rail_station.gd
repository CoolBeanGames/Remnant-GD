class_name rail_station
extends rotatable_item

## Endpoint-only parts. Cargo retains its original actors and logical parents.
enum Mode { LOAD, UNLOAD }
@export var mode: Mode = Mode.LOAD
@export_range(1, 128, 1) var capacity: int = 64
@export_range(.02, .5, .01) var scan_interval: float = .10
@export var dock_tolerance: float = .16
@export var bin_bounds: AABB = AABB(Vector3(-.96, .45, .8), Vector3(1.92, 1.8, 1.9))
@export_range(1, 8, 1) var loading_batch: int = 4
@export var eject_speed: float = 4.5
@export var eject_lift: float = 1.0
@export_range(.05, 1, .01) var eject_spacing: float = .15
@export_group("Optional Audio")
@export var transfer_sound: AudioStream
@export var sound_volume: float = 1.0
@export var sound_bus: StringName = &"SFX"
var endpoint_end: int = 1
var queue: Array[Dictionary] = []
var scan_elapsed: float = 0.0
var eject_remaining: float = 0.0
var _status_count: int = -1
@onready var intake: Area3D = $Intake
@onready var dock: Area3D = $Dock
@onready var output: Marker3D = $Output

func _ready() -> void:
	super._ready()
	add_to_group("rail-station")
	_update_status()

func get_hold_offset() -> Vector3:
	return Vector3(0, -.85, -2.9)

func mounted_rail() -> train_rail:
	return support.get_ref() as train_rail if placed and support != null else null

func can_place_on(host: Node3D) -> bool:
	return train_rail.from_collider(host) != null

func _can_mount(rail: train_rail, end: int) -> bool:
	return rail != null and rail._can_connect() and rail.connected_rail(end).is_empty() and rail.endpoint_station(end, self) == null

func get_placement_pose(host: Node3D, hit: Vector3, _normal: Vector3, _rotation: Basis) -> Dictionary:
	var rail: train_rail = train_rail.from_collider(host)
	var end: int = -1 if rail != null and rail.to_local(hit).z < 0 else 1
	if not _can_mount(rail, end):
		return {"valid": false}
	var facing: Basis = rail.global_basis * (Basis(Vector3.UP, PI) if end < 0 else Basis.IDENTITY)
	return {"valid": true, "host": rail, "transform": Transform3D(facing, rail.endpoint(end)), "clearance_exclude": [rail.get_rid()]}

func place_on(host: Node3D) -> void:
	var rail: train_rail = train_rail.from_collider(host)
	var end: int = -1 if rail != null and rail.to_local(global_position).z < 0 else 1
	if rail == null or (not get_meta("restoring", false) and not _can_mount(rail, end)):
		return
	endpoint_end = end
	super.place_on(rail)
	$Dock.position.z = -rail.end_margin
	DevTools.log_info("Mounted %s at rail end %d." % ["loader" if mode == Mode.LOAD else "unloader", end], "rails")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_sync_queue()
	eject_remaining = maxf(0, eject_remaining - delta)
	var rail: train_rail = mounted_rail()
	if held or get_meta("carried_by_player", false) or rail == null or not rail._can_connect():
		return
	scan_elapsed += delta
	if scan_elapsed < scan_interval:
		return
	scan_elapsed = 0
	var mask: int = int(get_meta("collision_space_mask", 1))
	intake.collision_mask = mask
	dock.collision_mask = mask
	if mode == Mode.LOAD:
		_capture_intake()
	for collider in dock.get_overlapping_bodies():
		var car: rail_slider = collider as rail_slider
		if car == null or car.mounted_rail() != rail or car.held or car.get_meta("carried_by_player", false):
			continue
		if absf(car.slider_position - endpoint_end * rail.travel_limit()) > dock_tolerance:
			continue
		var transferred: int = _load_car(car) if mode == Mode.LOAD else _unload_car(car)
		if transferred > 0:
			if transfer_sound != null:
				audio_global.play_3d(transfer_sound, global_position, sound_volume, 1.0, sound_bus)
			DevTools.log_info("%s %d cargo item(s)." % ["Loaded" if mode == Mode.LOAD else "Ejected", transferred], "rails")
			break
	_update_status()

func _capture_intake() -> void:
	var candidates: Array[Node3D] = []
	candidates.assign(intake.get_overlapping_bodies())
	# Capture a basket before its inner objects so ownership remains nested.
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.has_method("contained_bodies") and not b.has_method("contained_bodies"))
	for collider in candidates:
		var body: RigidBody3D = physics_items.rigid_body(collider)
		if queue.size() >= capacity:
			break
		if not physics_items.is_loose(body) or physics_items.prestige_locked(body) or body == self or body is train_rail or body is rail_slider or body is rail_station or body.get_meta("carried_by_player", false) or body.has_meta("rail_cargo_owner"):
			continue
		var bounds: AABB = physics_items.solid_bounds(body, global_transform.affine_inverse())
		if bounds.has_volume() and bin_bounds.grow(.025).encloses(bounds):
			_capture_body(body)

func _capture_body(body: RigidBody3D, saved: Dictionary = {}) -> void:
	var entry: Dictionary = {"body": weakref(body), "pose": global_transform.affine_inverse() * body.global_transform,
		"freeze": saved.get("freeze", body.freeze), "mode": saved.get("mode", body.freeze_mode),
		"states": physics_items.collider_states(body), "carry_collisions": false}
	entry.pose = saved.get("pose", entry.pose)
	if body.has_method("contained_bodies"):
		body.on_picked_up()
	queue.append(entry)
	body.set_meta("rail_cargo_owner", weakref(self))
	body.freeze = true
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO

func _sync_queue() -> void:
	for index in range(queue.size() - 1, -1, -1):
		var entry: Dictionary = queue[index]
		var body: RigidBody3D = entry.body.get_ref() as RigidBody3D
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			queue.remove_at(index)
			continue
		var carried: bool = bool(get_meta("carried_by_player", false))
		if entry.carry_collisions != carried:
			physics_items.set_collisions(entry.states, not carried)
			entry.carry_collisions = carried
		body.global_transform = global_transform * entry.pose
		if body.has_method("capture_current_contents"):
			body.capture_current_contents()
		if body.has_method("on_held_transform_updated"):
			body.on_held_transform_updated()

func on_held_transform_updated() -> void:
	_sync_queue()

func release_cargo_body(body: RigidBody3D, preserve_contents: bool = false) -> void:
	for index in range(queue.size() - 1, -1, -1):
		var entry: Dictionary = queue[index]
		if entry.body.get_ref() != body:
			continue
		physics_items.set_collisions(entry.states, true)
		if not preserve_contents and body.has_method("contained_bodies"):
			body.on_released()
		body.remove_meta("rail_cargo_owner")
		body.freeze_mode = entry.mode
		body.freeze = entry.freeze
		body.linear_velocity = linear_velocity
		body.sleeping = false
		queue.remove_at(index)
	_update_status()

func get_carried_bodies() -> Array[RigidBody3D]:
	var result: Array[RigidBody3D] = []
	for entry in queue:
		var body: RigidBody3D = entry.body.get_ref() as RigidBody3D
		if is_instance_valid(body):
			result.append(body)
			if body.has_method("get_carried_bodies"):
				result.append_array(body.get_carried_bodies())
	return result

func _load_car(car: rail_slider) -> int:
	var moved: int = 0
	for entry in queue.duplicate():
		if moved >= loading_batch:
			break
		var body: RigidBody3D = entry.body.get_ref() as RigidBody3D
		if not is_instance_valid(body):
			continue
		var space: Dictionary = car.cargo_loading_pose(body, [get_rid()])
		if space.is_empty():
			continue
		# Transfer the basket owner without briefly releasing its inner contents.
		# Physics sensors cannot rediscover disabled inner colliders in this tick.
		release_cargo_body(body, true)
		if car.accept_cargo(body, space.pose):
			moved += 1
		else:
			_capture_body(body, entry)
	return moved

func _unload_car(car: rail_slider) -> int:
	if eject_remaining > 0:
		return 0
	car.capture_current_cargo()
	for entry in car.cargo.duplicate():
		var body: RigidBody3D = entry.body.get_ref() as RigidBody3D
		if not is_instance_valid(body):
			continue
		var pose: Transform3D = body.global_transform
		pose.origin = output.global_position + global_basis.y.normalized() * physics_items.support_extent(body, global_basis.y)
		car.eject_cargo(body, pose, global_basis.z.normalized() * eject_speed + global_basis.y.normalized() * eject_lift)
		eject_remaining = maxf(.05, eject_spacing)
		return 1
	return 0

func _update_status() -> void:
	if not is_node_ready() or _status_count == queue.size():
		return
	_status_count = queue.size()
	$Status.text = "LOAD / %02d" % queue.size() if mode == Mode.LOAD else "EJECT"

func get_rail_state() -> Dictionary:
	return {"queue": physics_items.cargo_records(queue)}

func restore_rail_state(state: Dictionary, resolve_actor: Callable) -> void:
	for entry in state.get("queue", []):
		if not entry is Dictionary:
			continue
		var actor: Node3D = resolve_actor.call(str(entry.get("id", ""))) as Node3D
		var body: RigidBody3D = actor.get_node_or_null(NodePath(entry.get("path", ""))) as RigidBody3D if is_instance_valid(actor) else null
		if not is_instance_valid(body) or body.has_meta("rail_cargo_owner"):
			continue
		_capture_body(body, entry)
		body.global_transform = global_transform * queue.back().pose
		if body.has_method("capture_current_contents"):
			physics_items.restore_basket_contents(body, entry.get("contents", []), resolve_actor)
	_sync_queue()
	_update_status()

func portal_transform_contents(_pose_map: Transform3D, inside: bool) -> void:
	for entry in queue:
		for state in entry.states:
			state.layer = portal_space.remap_mask(state.layer, inside)
			state.mask = portal_space.remap_mask(state.mask, inside)

func _exit_tree() -> void:
	for entry in queue.duplicate():
		var body: RigidBody3D = entry.body.get_ref() as RigidBody3D
		if is_instance_valid(body):
			release_cargo_body(body)
	queue.clear()
