extends Node

var level: Node3D
var player: CharacterBody3D
var items: Dictionary = {}
var kill_height: float = -10.0
var tracking: bool = false
var snapshot_elapsed: float = 0.0
var serial: int = 0
var session: int = 0
var capture_scheduled: bool = false
var body_cache: Dictionary = {}
@export_range(0.1, 2.0, 0.1) var snapshot_interval: float = 0.5
@export_range(1, 1024, 1) var cull_checks_per_tick: int = 64
var _cull_ids: Array = []
var _cull_cursor: int = 0
var _record_cache: Dictionary = {}
@export_range(1, 128, 1) var snapshot_items_per_tick: int = 32
@export_range(250, 8000, 250) var snapshot_budget_usec: int = 2000
var _snapshot_ids: Array = []
var _snapshot_cursor: int = 0
var _snapshot_records: Dictionary = {}
var _snapshot_carried: Dictionary = {}

func begin(root: Node3D, avatar: CharacterBody3D, kill_y: float = -10.0) -> void:
	tracking = false
	session += 1
	capture_scheduled = false
	snapshot_elapsed = 0.0
	level = root
	player = avatar
	items.clear()
	body_cache.clear()
	_record_cache.clear()
	_snapshot_ids = []
	_snapshot_records.clear()
	_snapshot_carried.clear()
	_cull_ids = []
	_cull_cursor = 0
	kill_height = kill_y
	var pose: Variant = Blackboard.read_data("player_transform")
	if pose is Transform3D:
		player.global_transform = pose
	else:
		var position: Variant = Blackboard.read_data("player_position")
		var rotation: Variant = Blackboard.read_data("player_rotation")
		if position is Vector3:
			player.global_position = position
		if rotation is Vector3:
			player.global_rotation = rotation
	var camera: Camera3D = player.get_node_or_null("Camera3D")
	var camera_rotation: Variant = Blackboard.read_data("player_camera_rotation")
	if camera != null and camera_rotation is Vector3:
		camera.rotation = camera_rotation
	var look: Node = player.get_node_or_null("Controllers/Player_Look_Controller")
	if look != null:
		look.target_rotation = Vector2(camera.rotation_degrees.x, player.rotation_degrees.y)
		look.look_rotation = look.target_rotation
	var movement: Node = player.get_node_or_null("Controllers/Player_Move_Controller")
	if movement != null and movement.has_method("reset_platform_motion"):
		movement.reset_platform_motion()
	var saved: Variant = Blackboard.read_data("spawned_items")
	_restore.call_deferred(saved.duplicate(true) if saved is Array else [], session)

func spawn_item(scene: PackedScene, parent: Node, pose: Transform3D, apply_value: bool = false, inside_portal: bool = false) -> Node3D:
	if scene == null or not is_instance_valid(parent):
		return null
	var instance: Node = scene.instantiate()
	if not instance is Node3D:
		instance.free()
		return null
	var actor: Node3D = instance as Node3D
	if apply_value:
		Progression.apply_spawned_value(actor)
	if inside_portal:
		portal_space.apply_actor(actor, true)
	parent.add_child(actor)
	actor.global_transform = pose
	track(actor)
	return actor

func track(actor: Node3D, id: String = "") -> void:
	if not is_instance_valid(level) or not (actor == level or level.is_ancestor_of(actor)):
		# Game-root chute wrappers may be siblings of the loaded level.
		if not is_instance_valid(level) or actor.get_parent() != Blackboard.read_data("game_root"):
			return
	if actor.scene_file_path.is_empty():
		return
	if id.is_empty():
		id = str(actor.get_meta("persistent_item_id", ""))
	if id.is_empty():
		serial += 1
		id = "%d-%d" % [Time.get_ticks_usec(), serial]
	actor.set_meta("persistent_item_id", id)
	items[id] = weakref(actor)
	_record_cache.erase(id)
	_snapshot_records.erase(id)
	_cull_ids = []
	if tracking:
		_request_capture()

func untrack(actor: Node3D) -> void:
	var id: String = str(actor.get_meta("persistent_item_id", ""))
	items.erase(id)
	_record_cache.erase(id)
	_snapshot_records.erase(id)
	_cull_ids = []
	body_cache.erase(actor.get_instance_id())
	if tracking:
		_request_capture()

## Batch births/removals into one snapshot; explicit saves still capture immediately.
func _request_capture() -> void:
	if not capture_scheduled:
		capture_scheduled = true
		_flush_capture.call_deferred(session)

func _flush_capture(request_session: int) -> void:
	if request_session != session or not capture_scheduled:
		return
	capture_scheduled = false
	capture_background()

func _restore(records: Array, request_session: int = -1) -> void:
	if request_session != -1 and request_session != session:
		return
	if not is_instance_valid(level) or not level.is_inside_tree() or level.is_queued_for_deletion():
		return
	for record in records:
		if not record is Dictionary or not record.get("scene", "") is String or not ResourceLoader.exists(record.get("scene", "")):
			continue
		var scene: PackedScene = load(record.scene) as PackedScene
		if scene == null:
			continue
		var instance: Node = scene.instantiate()
		if not instance is Node3D:
			instance.free()
			continue
		var actor: Node3D = instance as Node3D
		actor.set_meta("restoring", true)
		# Ready-time registrants must reuse this saved identity, not mint an alias.
		actor.set_meta("persistent_item_id", str(record.get("id", "")))
		if record.get("portal_inside", false):
			portal_space.apply_actor(actor, true)
		if actor is note_drop and record.get("note", "") is String and ResourceLoader.exists(record.get("note", "")):
			actor.note = load(record.note) as note_definition
		if record.has("bases"):
			actor.set_meta("upgrade_base_values", record.bases.duplicate(true))
		if actor is RigidBody3D and actor.physics_material_override != null:
			actor.physics_material_override = actor.physics_material_override.duplicate()
		for property in record.get("properties", {}):
			actor.set_indexed(NodePath(property), record.properties[property])
		if actor is mulch_pellet:
			actor.stored_score = maxf(0, float(record.get("pellet_score", 0)))
		var score: score_object = physics_items.score_component(actor)
		if score != null and record.has("score"):
			score.score = int(record.score)
			score.mulch_value = int(record.get("mulch_value", score.mulch_value))
		level.add_child(actor)
		actor.global_transform = record.get("transform", Transform3D.IDENTITY)
		for body_state in record.get("bodies", []):
			var body: RigidBody3D = actor.get_node_or_null(NodePath(body_state.path)) as RigidBody3D
			if body != null:
				body.global_transform = body_state.transform
				body.freeze_mode = body_state.get("mode", 0)
				body.freeze = body_state.get("freeze", false)
				body.linear_velocity = body_state.get("velocity", Vector3.ZERO)
				body.angular_velocity = body_state.get("angular_velocity", Vector3.ZERO)
				if body_state.get("chute_settled", false):
					var material: PhysicsMaterial = body.physics_material_override.duplicate() if body.physics_material_override != null else PhysicsMaterial.new()
					material.friction = body_state.get("friction", 1.0)
					body.physics_material_override = material
					body.linear_damp = body_state.get("linear_damp", 2.0)
					body.angular_damp = body_state.get("angular_damp", 2.0)
					body.set_meta("chute_settled", true)
		track(actor, str(record.get("id", "")))
	# Old portable bins migrate to the one fixed mount; retain the original actor.
	if Flags.check_flag("mulch bin purchased"):
		Mulch.install_bin()
	# Resolve supports after every saved actor exists (basket attachments included).
	for record in records:
		if not record is Dictionary or not record.get("placed", false):
			continue
		var actor: Node3D = _actor(str(record.get("id", "")))
		if not actor is rotatable_item:
			continue
		var support_root: Node = _actor(str(record.get("support_id", "")))
		if support_root == null:
			support_root = level
		var host: Node3D = support_root.get_node_or_null(NodePath(record.get("support_path", ""))) as Node3D
		if record.get("air", false):
			host = null
		if host != null or actor.air_placeable:
			actor.place_on(host)
		else:
			actor.freeze = false
	# Container links need every actor and support restored before resolving IDs.
	for record in records:
		if not record is Dictionary:
			continue
		var actor: Node3D = _actor(str(record.get("id", "")))
		if is_instance_valid(actor) and actor.has_method("restore_rail_state"):
			actor.restore_rail_state(record.get("rail_state", {}), _actor)
	for record in records:
		if not record is Dictionary:
			continue
		var actor: Node3D = _actor(str(record.get("id", "")))
		if is_instance_valid(actor) and actor.has_method("restore_tool_state"):
			actor.restore_tool_state(record.get("tool_state", {}), _actor)
	# Restoration is a temporary lifecycle phase, not a permanent placement bypass.
	for id in items:
		var actor: Node3D = _actor(id)
		if is_instance_valid(actor):
			actor.remove_meta("restoring")
	tracking = true
	capture()
	DevTools.log_info("World restored / %d items" % items.size(), "world")

func _actor(id: String) -> Node3D:
	return items[id].get_ref() as Node3D if items.has(id) else null

func cull(actor: Node3D) -> void:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return
	if actor.has_method("on_culled"):
		actor.on_culled()
	DevTools.log_info("Culled %s at %s" % [actor.scene_file_path.get_file(), actor.global_position], "world")
	untrack(actor)
	actor.queue_free()

func _physics_process(delta: float) -> void:
	if not tracking or not is_instance_valid(level) or not level.is_inside_tree() or level.is_queued_for_deletion():
		return
	if _cull_ids.size() != items.size():
		_cull_ids = items.keys()
		# Continuous births must not restart at the oldest items every frame.
		_cull_cursor %= maxi(1, _cull_ids.size())
	# Retain this batch if an untrack invalidates the next scan while culling.
	var scan_ids: Array = _cull_ids
	var budget: int = scan_ids.size() if delta <= 0 else mini(cull_checks_per_tick, scan_ids.size())
	for offset in budget:
		var id: String = scan_ids[(_cull_cursor + offset) % scan_ids.size()]
		var actor: Node3D = _actor(id)
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			items.erase(id)
			_record_cache.erase(id)
			continue
		var below: bool = true
		var live_bodies: int = 0
		for reference: WeakRef in _body_references(actor):
			var body: RigidBody3D = reference.get_ref() as RigidBody3D
			if not is_instance_valid(body) or (body != actor and not actor.is_ancestor_of(body)):
				continue
			live_bodies += 1
			if body.global_position.y >= kill_height:
				below = false
				break
		if live_bodies == 0:
			below = actor.global_position.y < kill_height
		if below:
			cull(actor)
			items.erase(id)
			snapshot_elapsed = snapshot_interval
	if not scan_ids.is_empty():
		_cull_cursor = (_cull_cursor + budget) % scan_ids.size()

	if is_instance_valid(player) and player.is_inside_tree():
		Blackboard.store_data("player_transform", player.global_transform)
		Blackboard.store_data("player_position", player.global_position)
		Blackboard.store_data("player_rotation", player.global_rotation)
		var camera: Camera3D = player.get_node_or_null("Camera3D")
		if camera != null:
			var view_session: world_view_session = Blackboard.read_data("world_view_session") as world_view_session
			Blackboard.store_data("player_camera_rotation", view_session.original_camera_rotation if view_session != null and view_session.active else camera.rotation)
	snapshot_elapsed += delta
	if snapshot_elapsed >= snapshot_interval:
		snapshot_elapsed = 0.0
		capture_background()
	_advance_snapshot()

## Refresh topology at snapshot cadence, rather than searching every physics tick.
## Weak handles never keep discarded actors alive; detached bodies are ignored.
func _bodies(actor: Node3D, refresh: bool = false) -> Array[RigidBody3D]:
	var bodies: Array[RigidBody3D] = []
	for reference: WeakRef in _body_references(actor, refresh):
		var body: RigidBody3D = reference.get_ref() as RigidBody3D
		if is_instance_valid(body) and (body == actor or actor.is_ancestor_of(body)):
			bodies.append(body)
	return bodies

func _body_references(actor: Node3D, refresh: bool = false) -> Array[WeakRef]:
	var actor_id: int = actor.get_instance_id()
	if refresh or not body_cache.has(actor_id):
		var references: Array[WeakRef] = []
		if actor is RigidBody3D:
			references.append(weakref(actor))
		for child in actor.find_children("*", "RigidBody3D", true, false):
			references.append(weakref(child))
		body_cache[actor_id] = {"actor": weakref(actor), "bodies": references}
	return body_cache[actor_id].bodies

## Explicit saves/interactions force a fresh record; periodic snapshots reuse
## sleeping ordinary items only while their actual root/body transforms agree.
func capture() -> void:
	_start_snapshot(true)

func capture_background() -> void:
	_start_snapshot(false)

func _start_snapshot(force_refresh: bool) -> void:
	if not tracking or not is_instance_valid(level) or not level.is_inside_tree():
		return
	capture_scheduled = false
	if not force_refresh and not _snapshot_ids.is_empty():
		return
	_snapshot_ids = items.keys()
	_snapshot_cursor = 0
	_snapshot_records.clear()
	_snapshot_carried.clear()
	for actor_id in body_cache.keys():
		if body_cache[actor_id].actor.get_ref() == null:
			body_cache.erase(actor_id)
	for id in items:
		var container: Node3D = _actor(id)
		if is_instance_valid(container) and not container is object_manager and container.has_method("get_carried_bodies"):
			for body in container.get_carried_bodies():
				_snapshot_carried[body.get_instance_id()] = true
	if _snapshot_ids.is_empty():
		Blackboard.store_data("spawned_items", [])
	elif force_refresh:
		_advance_snapshot(true)

func _advance_snapshot(force_refresh: bool = false) -> void:
	if _snapshot_ids.is_empty():
		return
	var started: int = Time.get_ticks_usec()
	var processed: int = 0
	while _snapshot_cursor < _snapshot_ids.size():
		var id: String = _snapshot_ids[_snapshot_cursor]
		_snapshot_cursor += 1
		var actor: Node3D = _actor(id)
		if is_instance_valid(actor) and not actor.is_queued_for_deletion():
			var record: Dictionary = _make_record(id, actor, _snapshot_carried, force_refresh)
			_record_cache[id] = record
			_snapshot_records[id] = record
		processed += 1
		if not force_refresh and (processed >= snapshot_items_per_tick or Time.get_ticks_usec() - started >= snapshot_budget_usec):
			break
	if _snapshot_cursor >= _snapshot_ids.size():
		var records: Array[Dictionary] = []
		for id in _snapshot_records:
			if items.has(id):
				records.append(_snapshot_records[id])
		Blackboard.store_data("spawned_items", records)
		_snapshot_ids = []
		_snapshot_records.clear()
		_snapshot_carried.clear()

func _make_record(id: String, actor: Node3D, carried_body_ids: Dictionary, force_refresh: bool) -> Dictionary:
	if not force_refresh and actor is object_manager and _record_cache.has(id):
		var cached: Dictionary = _record_cache[id]
		var body: RigidBody3D = actor.rb
		if is_instance_valid(body) and body.sleeping and not body.freeze and not body.get_meta("carried_by_player", false) and cached.transform == actor.global_transform and cached.bodies.size() == 1 and cached.bodies[0].transform == body.global_transform:
			return cached
	var record: Dictionary = {"id": id, "scene": actor.scene_file_path, "transform": actor.global_transform, "bodies": [], "properties": {}, "bases": actor.get_meta("upgrade_base_values", {}).duplicate(true)}
	record.portal_inside = actor.get_meta("portal_inside", false)
	if actor is note_drop and actor.note != null:
		record.note = actor.note.resource_path
	if actor is mulch_pellet:
		record.pellet_score = actor.stored_score
	if actor is switchable_prop:
		record.properties["powered"] = actor.powered
	if actor.has_method("cycle_lens"):
		record.properties["lens_index"] = actor.get("lens_index")
	if actor.has_method("set_beam_active"):
		record.properties["beam_hood_active"] = actor.get("beam_hood_active")
	if actor.has_method("get_tool_state"):
		record.tool_state = actor.get_tool_state()
		record.properties["vacuum_mode"] = actor.get("vacuum_mode")
		record.properties["swivel_active"] = actor.get("swivel_active")
	if actor.has_method("get_rail_state"):
		record.rail_state = actor.get_rail_state()
	if actor is train_rail:
		for property in ["rail_length", "carriage_height", "end_margin", "connection_tolerance"]:
			record.properties[property] = actor.get(property)
	if actor is rail_station:
		for property in ["mode", "capacity", "scan_interval", "dock_tolerance", "bin_bounds", "loading_batch", "eject_speed", "eject_lift", "eject_spacing"]:
			record.properties[property] = actor.get(property)
	if actor is rail_slider:
		for property in ["travel_damping", "deck_half_size", "deck_surface", "cargo_tolerance"]:
			record.properties[property] = actor.get(property)
	for property in record.bases:
		record.properties[property] = actor.get_indexed(NodePath(property))
	for property in ["spawn_interval", "remaining"]:
		if actor is automatic_spawner:
			record.properties[property] = actor.get(property)
	var component: score_object = physics_items.score_component(actor)
	if component != null:
		record.score = component.score
		record.mulch_value = component.mulch_value
	for body in _bodies(actor, force_refresh or not actor is object_manager):
		var extra: Dictionary = {"chute_settled": body.get_meta("chute_settled", false), "friction": body.physics_material_override.friction if body.physics_material_override != null else 1.0, "linear_damp": body.linear_damp, "angular_damp": body.angular_damp}
		record.bodies.append({"path": str(actor.get_path_to(body)), "transform": body.global_transform, "freeze": body.freeze and not body.get_meta("carried_by_player", false) and not carried_body_ids.has(body.get_instance_id()), "mode": body.freeze_mode, "velocity": body.linear_velocity, "angular_velocity": body.angular_velocity})
		record.bodies.back().merge(extra)
	if actor is rotatable_item and actor.placed:
		record.placed = true
		record.air = actor.support == null
		var host: Node3D = actor.support.get_ref() as Node3D if actor.support != null else null
		if is_instance_valid(host):
			var root: Node = host
			while root != null and not root.has_meta("persistent_item_id") and root != level:
				root = root.get_parent()
			if root != null:
				record.support_id = str(root.get_meta("persistent_item_id", ""))
				record.support_path = str(root.get_path_to(host))
	return record
