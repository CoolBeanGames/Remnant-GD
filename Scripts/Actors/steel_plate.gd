class_name steel_plate
extends rotatable_item

## Edge joins use the physical sheet, including its local collider transform.
@export var edge_snap_enabled: bool = true
@export_range(0.0, 2.0, 0.05) var edge_snap_distance: float = 0.55
@export_range(0.001, 0.1, 0.001) var edge_gap: float = 0.015
@onready var plate_collision: CollisionShape3D = $PlateCollision

const EDGES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN]


func get_placement_pose(host: Node3D, hit_position: Vector3, _normal: Vector3, placement_rotation: Basis) -> Dictionary:
	var target: steel_plate = from_collider(host)
	if not edge_snap_enabled or target == null or not target.edge_snap_enabled or not target.placed:
		return {}
	if target == self or target.held or target.get_meta("carried_by_player", false) or target.is_queued_for_deletion() or target.collision_layer == 0 or target.is_supported_by(self):
		return {"valid": false}
	if not plate_collision.shape is BoxShape3D or not target.plate_collision.shape is BoxShape3D:
		return {}
	var target_box: BoxShape3D = target.plate_collision.shape
	var own_box: BoxShape3D = plate_collision.shape
	var target_frame: Transform3D = target.plate_collision.global_transform
	var local_hit: Vector3 = target_frame.affine_inverse() * hit_position
	var x_distance: float = absf(absf(local_hit.x) - target_box.size.x * .5) * target_frame.basis.x.length()
	var y_distance: float = absf(absf(local_hit.y) - target_box.size.y * .5) * target_frame.basis.y.length()
	if minf(x_distance, y_distance) > minf(edge_snap_distance, target.edge_snap_distance):
		return {}
	var edge: Vector3 = (Vector3.RIGHT if local_hit.x >= 0 else Vector3.LEFT) if x_distance <= y_distance else (Vector3.UP if local_hit.y >= 0 else Vector3.DOWN)
	var outward: Vector3 = (target_frame.basis * edge).normalized()
	var tangent: Vector3 = _tangent(target_frame.basis, edge)
	var placement_basis: Basis = target_frame.basis * placement_rotation * plate_collision.transform.basis.inverse()
	var incoming_frame: Basis = placement_basis * plate_collision.transform.basis
	var incoming_edge := Vector3.ZERO
	var best_score: float = -INF
	for candidate in EDGES:
		# A full edge must line up; wheel/R can fold the sheet about that edge.
		if absf(tangent.dot(_tangent(incoming_frame, candidate))) < .9999:
			continue
		var score: float = -(incoming_frame * candidate).normalized().dot(outward)
		if score < -.0001:
			continue
		# Keep the same hinge at exactly 90 degrees instead of flipping sides.
		if candidate == -edge:
			score += .00001
		if score > best_score:
			best_score = score
			incoming_edge = candidate
	if incoming_edge == Vector3.ZERO:
		return {"valid": false}
	var edge_position: Vector3 = target_frame * _edge_center(target_box, edge)
	var own_edge_position: Vector3 = plate_collision.transform * _edge_center(own_box, incoming_edge)
	var gap: float = maxf(edge_gap, target.edge_gap)
	var pose := Transform3D(placement_basis, edge_position + outward * gap - placement_basis * own_edge_position)
	# Folding exposes sheet thickness. Keep its whole solid collider outside
	# the host edge so perpendicular joins cannot penetrate the existing plate.
	var bounds := AABB(-own_box.size * .5, own_box.size)
	var closest: float = INF
	for corner in 8:
		var vertex: Vector3 = pose * plate_collision.transform * bounds.get_endpoint(corner)
		closest = minf(closest, (vertex - edge_position).dot(outward))
	if closest < gap:
		pose.origin += outward * (gap - closest)
	return {"valid": true, "transform": pose, "host": target}


static func _edge_center(box: BoxShape3D, edge: Vector3) -> Vector3:
	return edge * box.size * .5


static func _tangent(placement_basis: Basis, edge: Vector3) -> Vector3:
	return (placement_basis.y if edge.x != 0 else placement_basis.x).normalized()


static func from_collider(collider: Node3D) -> steel_plate:
	var current: Node = collider
	while is_instance_valid(current):
		if current is steel_plate:
			return current as steel_plate
		current = current.get_parent()
	return null
