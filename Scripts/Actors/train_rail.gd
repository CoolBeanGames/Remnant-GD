class_name train_rail
extends rotatable_item

## Straight, movable rail. Matching placed endpoints form a continuous track.
@export_range(1.0, 20.0, 0.25) var rail_length: float = 3.0
@export var carriage_height: float = 0.28
@export var end_margin: float = 0.45
@export_range(0.001, 0.1, 0.001) var connection_tolerance: float = 0.04
var _connections: Dictionary = {}
var _stop_connections: Array[bool] = [false, false]
static var _network_frame: int = -1
static var _network_links: Dictionary = {}


func _ready() -> void:
	super._ready()
	refresh_geometry()
	add_to_group("train-rail")


func refresh_geometry() -> void:
	for side in ["LeftRail", "RightRail"]:
		var mesh: MeshInstance3D = get_node(side)
		mesh.mesh = mesh.mesh.duplicate()
		(mesh.mesh as BoxMesh).size.z = rail_length
		var collider: CollisionShape3D = get_node(side + "Collision")
		collider.shape = collider.shape.duplicate()
		(collider.shape as BoxShape3D).size.z = rail_length
	for index in 7:
		get_node("Tie%d" % index).position.z = lerpf(-rail_length * .45, rail_length * .45, index / 6.0)
	for end in ["FrontStop", "BackStop"]:
		var offset: float = -rail_length * .5 if end == "FrontStop" else rail_length * .5
		get_node(end).position.z = offset
		get_node(end + "Collision").position.z = offset
	_network_frame = -1


func travel_limit() -> float:
	return maxf(0.0, rail_length * .5 - end_margin)


func end_limit(end: int) -> float:
	return rail_length * .5 if not connected_rail(end).is_empty() else travel_limit()


func carriage_pose(position_on_rail: float) -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(0, carriage_height, clampf(position_on_rail, -end_limit(-1), end_limit(1))))


func endpoint(end: int) -> Vector3:
	return to_global(Vector3(0, 0, end * rail_length * .5))


func _can_connect() -> bool:
	if not placed or not freeze or held or get_meta("carried_by_player", false) or is_queued_for_deletion() or collision_layer == 0:
		return false
	var host: Node3D = support.get_ref() as Node3D if support != null else null
	while is_instance_valid(host):
		if host.get_meta("carried_by_player", false) or (host is RigidBody3D and not host.freeze):
			return false
		if host is rotatable_item and host.support != null:
			host = host.support.get_ref() as Node3D
		else:
			host = host.get_parent() as Node3D
	return true


func connected_rail(end: int) -> Dictionary:
	_refresh_connections()
	var connection: Dictionary = _connections.get(end, {})
	var other: Variant = connection.get("rail")
	# Pickup, queued deletion, support motion or a portal change can happen
	# after this frame's network discovery. Never use a stale open endpoint.
	if not _can_connect() or not is_instance_valid(other) or not other is train_rail or not other._can_connect():
		return {}
	if int(other.get_meta("collision_space_mask", 1)) != int(get_meta("collision_space_mask", 1)) or bool(other.get_meta("portal_inside", false)) != bool(get_meta("portal_inside", false)):
		return {}
	var other_end: int = connection.end
	var tolerance: float = minf(connection_tolerance, other.connection_tolerance)
	var here: Vector3 = endpoint(end)
	var there: Vector3 = other.endpoint(other_end)
	if here.distance_to(there) > tolerance or (here + global_basis.y.normalized() * carriage_height).distance_to(there + other.global_basis.y.normalized() * other.carriage_height) > tolerance:
		return {}
	if (global_basis.z.normalized() * end).dot(other.global_basis.z.normalized() * other_end) > -.9999 or global_basis.y.normalized().dot(other.global_basis.y.normalized()) < .9999:
		return {}
	return connection


func _refresh_connections(force: bool = false) -> void:
	var frame: int = Engine.get_physics_frames()
	if force or _network_frame != frame:
		_network_frame = frame
		_rebuild_network()
	_connections = _network_links.get(get_instance_id(), {})


func _rebuild_network() -> void:
	# One bounded discovery pass per physics frame for the whole workshop.
	# Requiring a unique match on BOTH ends prevents one-sided duplicate joins.
	_network_links.clear()
	var rails: Array[train_rail] = []
	for node in get_tree().get_nodes_in_group("train-rail"):
		if node is train_rail and node._can_connect():
			rails.append(node)
	var matches: Dictionary = {}
	for index in rails.size():
		var rail: train_rail = rails[index]
		var axis: Vector3 = rail.global_basis.z.normalized()
		var up: Vector3 = rail.global_basis.y.normalized()
		for other_index in range(index + 1, rails.size()):
			var other: train_rail = rails[other_index]
			if int(other.get_meta("collision_space_mask", 1)) != int(rail.get_meta("collision_space_mask", 1)) or bool(other.get_meta("portal_inside", false)) != bool(rail.get_meta("portal_inside", false)):
				continue
			var other_axis: Vector3 = other.global_basis.z.normalized()
			var other_up: Vector3 = other.global_basis.y.normalized()
			if absf(axis.dot(other_axis)) < .9999 or up.dot(other_up) < .9999:
				continue
			var tolerance: float = minf(rail.connection_tolerance, other.connection_tolerance)
			for end in [-1, 1]:
				var here: Vector3 = rail.endpoint(end)
				for other_end in [-1, 1]:
					if (axis * end).dot(other_axis * other_end) > -.9999:
						continue
					var there: Vector3 = other.endpoint(other_end)
					if here.distance_to(there) > tolerance or (here + up * rail.carriage_height).distance_to(there + other_up * other.carriage_height) > tolerance:
						continue
					var key: String = "%d:%d" % [rail.get_instance_id(), end]
					var other_key: String = "%d:%d" % [other.get_instance_id(), other_end]
					if not matches.has(key):
						matches[key] = []
					if not matches.has(other_key):
						matches[other_key] = []
					matches[key].append({"rail": other, "end": other_end, "key": other_key})
					matches[other_key].append({"rail": rail, "end": end, "key": key})
	for rail in rails:
		var links: Dictionary = {}
		for end in [-1, 1]:
			var candidates: Array = matches.get("%d:%d" % [rail.get_instance_id(), end], [])
			if candidates.size() == 1 and matches.get(candidates[0].key, []).size() == 1:
				links[end] = {"rail": candidates[0].rail, "end": candidates[0].end}
		_network_links[rail.get_instance_id()] = links


func _update_end_stops() -> void:
	_refresh_connections()
	for index in 2:
		var end: int = -1 if index == 0 else 1
		var connected: bool = not connected_rail(end).is_empty()
		if connected == _stop_connections[index]:
			continue
		_stop_connections[index] = connected
		var stop: String = "FrontStop" if end < 0 else "BackStop"
		get_node(stop).visible = not connected
		get_node(stop + "Collision").set_deferred("disabled", connected)


func _physics_process(_delta: float) -> void:
	sync_support_pose()
	_update_end_stops()


## Looking at an existing rail appends a collinear segment to its nearest end.
## Empty means ordinary anchored placement (handled by prop_placement).
func get_placement_pose(host: Node3D, hit_position: Vector3, _normal: Vector3, rotation: Basis) -> Dictionary:
	var rail: train_rail = from_collider(host)
	if rail == null:
		return {}
	if rail == self or not rail._can_connect() or rail.is_supported_by(self):
		return {"valid": false}
	if absf(carriage_height - rail.carriage_height) > minf(connection_tolerance, rail.connection_tolerance):
		return {"valid": false}
	var end: int = -1 if rail.to_local(hit_position).z < 0 else 1
	if not rail.connected_rail(end).is_empty():
		return {"valid": false}
	var reversed: bool = rotation.z.z < 0.0
	var basis: Basis = rail.global_basis * (Basis(Vector3.UP, PI) if reversed else Basis.IDENTITY)
	var incoming_end: int = end if reversed else -end
	var pose := Transform3D(basis, rail.endpoint(end) - basis.z * incoming_end * rail_length * .5)
	return {"valid": true, "transform": pose, "host": rail, "clearance_exclude": [rail.get_rid()]}


func place_on(host: Node3D) -> void:
	var rail: train_rail = from_collider(host)
	# Independent sections share the scenery anchor, rather than becoming cargo
	# of another rail. Picking up one section cleanly disconnects only that rail.
	if rail != null and rail != self:
		host = rail.support.get_ref() as Node3D if rail.support != null else null
	super.place_on(host)
	_network_frame = -1
	for node in get_tree().get_nodes_in_group("train-rail"):
		node._update_end_stops()


func on_picked_up() -> void:
	super.on_picked_up()
	_network_frame = -1
	for node in get_tree().get_nodes_in_group("train-rail"):
		node._update_end_stops()


func _exit_tree() -> void:
	_network_frame = -1


static func from_collider(collider: Node3D) -> train_rail:
	var current: Node = collider
	while is_instance_valid(current):
		if current is train_rail:
			return current as train_rail
		current = current.get_parent()
	return null


## The pickup system also fades cargo when the whole rail assembly is carried.
func get_carried_bodies() -> Array[RigidBody3D]:
	var result: Array[RigidBody3D] = []
	for prop in get_tree().get_nodes_in_group("placed-prop"):
		if prop is rail_slider and prop.is_supported_by(self):
			result.append(prop)
			for body in prop.get_carried_bodies():
				if not result.has(body):
					result.append(body)
	return result
