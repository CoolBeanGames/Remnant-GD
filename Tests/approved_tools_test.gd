extends Node

class DriveHost extends StaticBody3D:
	var impulse: Vector3 = Vector3.ZERO
	func apply_drive_impulse(value: Vector3) -> void:
		impulse += value

var failures: Array[String] = []
var world: Node3D

func check(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
		push_error(description)

func tick(count: int = 2) -> void:
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func item(point: Vector3, mass_value: float = 1.0) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.position = point
	body.mass = mass_value
	body.gravity_scale = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * .2
	collision.shape = shape
	body.add_child(collision)
	var component := score_object.new()
	component.score = 3
	body.add_child(component)
	world.add_child(body)
	return body

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	Blackboard.store_data("player_input_blocked", false)
	var fan: RigidBody3D = load("res://Scenes/Actors/fan.tscn").instantiate()
	fan.freeze = true
	fan.vacuum_enabled = true
	fan.vacuum_mode = true
	world.add_child(fan)
	var body: RigidBody3D = item(Vector3(0, 1, -1.6), .5)
	body.set_meta("persistent_item_id", "catch-item")
	var original_parent: Node = body.get_parent()
	var immune: RigidBody3D = item(Vector3(.5, 1, -1.5))
	immune.add_to_group("machine-immune")
	var heavy: RigidBody3D = item(Vector3(0, 1, -2.7), 5.0)
	var heavy_position: Vector3 = heavy.position
	await tick(55)
	check(fan.vacuum.get_bodies().has(body), "Suction must physically draw a nearby loose object into the bag.")
	check(body.freeze and body.collision_layer == 0 and body.get_parent() == original_parent, "Catch bag preserves original wrapper while suspending only contained physics.")
	check(physics_items.score_component(body).score == 3 and not fan.vacuum.get_bodies().has(immune), "Suction must preserve score and exclude reusable tools.")
	check(heavy.position.is_equal_approx(heavy_position), "Heavy objects outside their shorter suction reach must stay put.")
	var state: Dictionary = fan.get_tool_state()
	check(state.vacuum_contents.size() == 1 and state.vacuum_contents[0].id == "catch-item", "Saved bag uses persistent actor references, not copies.")
	var pose: Transform3D = body.global_transform
	fan.vacuum.empty()
	check(not body.freeze and body.collision_layer == 1 and body.linear_velocity == Vector3.ZERO and body.global_transform == pose, "Bag empty restores existing bodies in place with no launch impulse.")
	fan.restore_tool_state(state, func(id: String) -> Node: return body if id == "catch-item" else null)
	check(fan.vacuum.get_bodies().size() == 1 and body.freeze, "Restored bag reattaches the original persistent body once.")
	fan.restore_tool_state(state, func(id: String) -> Node: return body if id == "catch-item" else null)
	check(fan.vacuum.get_bodies().size() == 1, "Repeated containment restoration cannot duplicate a body.")
	fan.vacuum.portal_transform_contents(Transform3D.IDENTITY, true)
	fan.vacuum.empty()
	check(body.collision_layer == portal_space.ROOM_LAYER, "Emptying in a portal restores collisions in the correct physics space.")
	body.gravity_scale = 1
	var release_height: float = body.position.y
	await tick(25)
	check(body.position.y < release_height - .3 and not body.get_collision_exceptions().has(fan), "Emptied objects fall below the bag and clear their temporary fan collision exception.")
	body.queue_free()
	immune.queue_free()
	heavy.queue_free()
	var drive := DriveHost.new()
	world.add_child(drive)
	fan.place_on(drive)
	fan.vacuum_mode = false
	fan._physics_process(.1)
	check(drive.impulse.dot(fan.global_basis.z) > .7, "Mounted blower supplies opposite airflow reaction to a rail slider.")
	drive.impulse = Vector3.ZERO
	fan.held = true
	fan._physics_process(.1)
	check(drive.impulse == Vector3.ZERO, "Held fans must not propel a slider or the player.")
	fan.held = false
	fan.swivel_enabled = true
	fan.swivel_active = true
	fan.swivel_phase = 0.0
	fan._physics_process(fan.swivel_period * .25)
	check(absf(rad_to_deg(fan.global_basis.get_euler().y) - fan.swivel_stop_degrees) < .1, "Swivel sweeps on one local axis up to its configurable stop.")
	var phase: float = fan.swivel_phase
	fan.powered = false
	fan._physics_process(.5)
	check(is_equal_approx(fan.swivel_phase, phase), "Swivel stops when fan power is off.")
	var broom: RigidBody3D = load("res://Scenes/Actors/push_broom.tscn").instantiate()
	broom.position = Vector3(10, 0, 0)
	broom.freeze = true
	broom.held = true
	broom.side_skirt_enabled = true
	world.add_child(broom)
	broom.get_node("Sweep").collision_mask = 1
	var swept: RigidBody3D = item(Vector3(10.6, .2, -.3))
	swept.linear_velocity = Vector3.RIGHT * 3
	await tick(1)
	swept.global_position = Vector3(10.6, .2, -.3)
	broom.stroke_time = .45
	broom._physics_process(.05)
	await tick(1)
	check(broom.get_node("SideSkirts").visible and not broom.get_node("LeftGuard").disabled, "Side skirt upgrade activates visible and physical side guards.")
	check(swept.linear_velocity.x < 3, "Upgraded broom must reduce lateral scattering while pushing.")
	# Removal releases caught actors rather than leaking frozen invisible contents.
	var released_body: RigidBody3D = item(Vector3(0, 1, -.8))
	fan.vacuum._capture(released_body)
	fan.queue_free()
	await tick(2)
	check(not released_body.freeze and released_body.collision_layer == 1, "Removing a fan releases its bag contents safely.")
	world.queue_free()
	await tick(2)
	print("Approved fan and broom upgrades: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
