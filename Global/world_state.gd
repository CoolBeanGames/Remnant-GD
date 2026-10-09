extends Node

var level: Node3D
var player: CharacterBody3D
var items: Dictionary = {}
var kill_height: float = -10.0
var tracking: bool = false
var snapshot_elapsed: float = 0.0
var serial: int = 0

func begin(root: Node3D, avatar: CharacterBody3D, kill_y: float = -10.0) -> void:
	tracking = false
	level = root
	player = avatar
	items.clear()
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
	var saved: Variant = Blackboard.read_data("spawned_items")
	_restore.call_deferred(saved.duplicate(true) if saved is Array else [])

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
	if tracking:
		capture()

func untrack(actor: Node3D) -> void:
	items.erase(str(actor.get_meta("persistent_item_id", "")))
	if tracking:
		capture()

func _restore(records: Array) -> void:
	if not is_instance_valid(level) or level.is_queued_for_deletion():
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
	tracking = true
	capture()

func _actor(id: String) -> Node3D:
	return items[id].get_ref() as Node3D if items.has(id) else null

func cull(actor: Node3D) -> void:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return
	if actor.has_method("on_culled"):
		actor.on_culled()
	untrack(actor)
	actor.queue_free()

func _physics_process(delta: float) -> void:
	if not tracking or not is_instance_valid(level) or not level.is_inside_tree() or level.is_queued_for_deletion():
		return
	for id in items.keys():
		var actor: Node3D = _actor(id)
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			items.erase(id)
			continue
		var bodies: Array[RigidBody3D] = _bodies(actor)
		var below: bool = actor.global_position.y < kill_height if bodies.is_empty() else true
		for body in bodies:
			if body.global_position.y >= kill_height:
				below = false
		if below:
			cull(actor)
			items.erase(id)
			snapshot_elapsed = .1

	if is_instance_valid(player) and player.is_inside_tree():
		Blackboard.store_data("player_transform", player.global_transform)
		Blackboard.store_data("player_position", player.global_position)
		Blackboard.store_data("player_rotation", player.global_rotation)
		Blackboard.store_data("player_camera_rotation", player.get_node("Camera3D").rotation)
	snapshot_elapsed += delta
	if snapshot_elapsed >= .1:
		snapshot_elapsed = 0.0
		capture()

func _bodies(actor: Node3D) -> Array[RigidBody3D]:
	var bodies: Array[RigidBody3D] = []
	if actor is RigidBody3D:
		bodies.append(actor)
	for child in actor.find_children("*", "RigidBody3D", true, false):
		bodies.append(child)
	return bodies

func capture() -> void:
	if not tracking or not is_instance_valid(level) or not level.is_inside_tree():
		return
	var records: Array[Dictionary] = []
	var carried_body_ids: Array[int] = []
	for id in items:
		var container: Node3D = _actor(id)
		if is_instance_valid(container) and container.get_meta("carried_by_player", false) and container.has_method("get_carried_bodies"):
			for body in container.get_carried_bodies():
				carried_body_ids.append(body.get_instance_id())
	for id in items:
		var actor: Node3D = _actor(id)
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		var record: Dictionary = {"id": id, "scene": actor.scene_file_path, "transform": actor.global_transform, "bodies": [], "properties": {}, "bases": actor.get_meta("upgrade_base_values", {}).duplicate(true)}
		record.portal_inside = actor.get_meta("portal_inside", false)
		if actor is note_drop and actor.note != null:
			record.note = actor.note.resource_path
		if actor is switchable_prop:
			record.properties["powered"] = actor.powered
		for property in record.bases:
			record.properties[property] = actor.get_indexed(NodePath(property))
		for property in ["spawn_interval", "remaining"]:
			if actor is automatic_spawner:
				record.properties[property] = actor.get(property)
		var component: score_object = physics_items.score_component(actor)
		if component != null:
			record.score = component.score
			record.mulch_value = component.mulch_value
		for body in _bodies(actor):
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
		records.append(record)
	Blackboard.store_data("spawned_items", records)
