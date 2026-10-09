class_name chute_zone
extends Area3D

@export var stuck_seconds: float = 30.0
@export var chute_friction: float = 0.35
@export var chute_damping: float = 0.1
@export var note_friction: float = 0.02
@export var note_stall_seconds: float = 0.75
@export var note_flow_velocity: Vector3 = Vector3(0, -1.0, 2.0)
@export var exit_friction: float = 1.0
@export var exit_linear_damp: float = 2.0
@export var exit_angular_damp: float = 2.0
var occupants: Dictionary = {}

func _ready() -> void:
	body_entered.connect(entered)
	body_exited.connect(left)

func entered(body: Node3D) -> void:
	if not body is RigidBody3D:
		return
	var actor: Node3D = physics_items.item_root(body)
	if body.is_in_group("score") or actor is note_drop:
		occupants[body.get_instance_id()] = {"body": weakref(body), "elapsed": 0.0, "stalled": 0.0, "last_position": body.global_position}
		var material: PhysicsMaterial = body.physics_material_override.duplicate() if body.physics_material_override != null else PhysicsMaterial.new()
		material.friction = note_friction if actor is note_drop else chute_friction
		body.physics_material_override = material
		body.linear_damp = chute_damping
		body.angular_damp = chute_damping
		body.set_meta("chute_settled", false)

func left(body: Node3D) -> void:
	if occupants.erase(body.get_instance_id()) and body is RigidBody3D:
		settle(body)

func settle(body: RigidBody3D) -> void:
	var material: PhysicsMaterial = body.physics_material_override.duplicate() if body.physics_material_override != null else PhysicsMaterial.new()
	material.friction = exit_friction
	body.physics_material_override = material
	body.linear_damp = exit_linear_damp
	body.angular_damp = exit_angular_damp
	body.set_meta("chute_settled", true)

func _physics_process(delta: float) -> void:
	for id in occupants.keys():
		var body: RigidBody3D = occupants[id].body.get_ref() as RigidBody3D
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			occupants.erase(id)
			continue
		# Picking an item out of the chute releases it rather than timing it out.
		if body.get_meta("carried_by_player", false):
			occupants.erase(id)
			settle(body)
			continue
		occupants[id].elapsed += delta
		if body is note_drop:
			var moved: float = body.global_position.distance_to(occupants[id].last_position)
			occupants[id].last_position = body.global_position
			occupants[id].stalled = occupants[id].stalled + delta if moved < .003 else 0.0
			if occupants[id].stalled >= note_stall_seconds:
				body.sleeping = false
				body.linear_velocity = global_basis.orthonormalized() * note_flow_velocity
				occupants[id].stalled = 0.0
		if occupants[id].elapsed >= maxf(.1, stuck_seconds):
			var actor: Node3D = physics_items.item_root(body)
			WorldState.cull(actor)
			occupants.erase(id)
