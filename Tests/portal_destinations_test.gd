extends Node

var failures: Array[String] = []
var level: level_sequence
var portal: door_portal
var player: CharacterBody3D
var movement: Node
var peak_ascent: float = 0.0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 2) -> void:
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _ready() -> void:
	run.call_deferred()

func f9() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F9
	event.keycode = KEY_F9
	event.pressed = true
	return event

func pose(position: Vector3, yaw: float = 0.0) -> void:
	player.global_position = position
	player.rotation = Vector3(0, yaw, 0)
	player.velocity = Vector3.ZERO
	movement.reset_platform_motion()
	portal.previous_camera_position = portal.camera.global_position

func walk_until(target: Callable, count: int = 180) -> void:
	peak_ascent = 0.0
	Input.action_press("forward")
	for index in count:
		await get_tree().physics_frame
		var previous_height: float = player.global_position.y
		movement._physics_process(1.0 / 60.0)
		peak_ascent = maxf(peak_ascent, player.global_position.y-previous_height)
		await get_tree().process_frame
		if target.call():
			break
	Input.action_release("forward")
	player.velocity = Vector3.ZERO

func enter() -> void:
	if not portal.door.is_open:
		portal.door.interact()
		portal.door.animation.advance(portal.door.animation.current_animation_length)
	pose(portal.source_frame.to_global(Vector3(0, -portal.source_offset.y + .04, 1.1)), PI)
	await walk_until(func() -> bool: return portal.inside)
	check(portal.inside, "Real capsule crosses into %s" % portal.active_destination_id)
	if not portal.inside:
		print("Failed entrance pose: ", player.global_position, " / ", portal.source_frame.global_transform)
	check(player.collision_mask == portal_space.ROOM_LAYER, "Crossing updates player physics")

func run() -> void:
	SaveGame.save_path = "res://.godot/portal_destinations_test.save"
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("portal_inside", false)
	for key in ["portal_destination_id", "player_transform", "player_position", "player_rotation", "player_camera_rotation"]:
		Blackboard.remove_data(key)
	for key in ["exited room", "level enabled", "grinder enabled", "computer enabled"]:
		Flags.set_flag(key, false)
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	level.get_node("DoorPortal").purchase_required = false # Explicit free F9/physics test mode.
	add_child(level)
	player = level.player
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	movement = player.get_node("Controllers/Player_Move_Controller")
	portal = level.get_node("DoorPortal")
	Blackboard.store_data("player_input_blocked", false)
	await tick()
	portal._input(f9())
	await tick()
	check(not portal.active and portal.room == null, "F9 cannot bypass initial room removal")
	level.room._remove_room()
	await tick()
	check(portal.active_destination_id == &"apartment", "Apartment is the default destination")
	check(portal.room.get_node("Art").get_child_count() == 24, "Expanded apartment includes 23 separate furniture and door instances")
	var old_room: WeakRef = weakref(portal.room)
	Blackboard.store_data("player_input_blocked", true)
	portal._input(f9())
	Blackboard.store_data("player_input_blocked", false)
	DevTools.active_modal = &"test"
	portal._input(f9())
	DevTools.active_modal = &""
	var echo: InputEventKey = f9()
	echo.echo = true
	portal._input(echo)
	await tick()
	check(portal.active_destination_id == &"apartment", "Menus, input lock and key repeats cannot cycle")
	await enter()
	await walk_until(func() -> bool: return player.global_position.z < 1.7)
	print("Apartment walk pose: ", player.global_position, " / ", player.global_basis)
	check(player.global_position.z < 1.7 and player.global_position.y > -.02, "Open apartment leaf and vestibule permit actual walking")
	var basket: RigidBody3D = WorldState.spawn_item(load("res://Scenes/Actors/basket.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(1601.76, .05, 2.15)), false, true)
	basket.freeze = true
	var item: Node3D = WorldState.spawn_item(load("res://Scenes/test_object.tscn"), level, basket.global_transform, false, true)
	var item_body: RigidBody3D = WorldState._bodies(item)[0]
	item_body.global_position = basket.global_position + Vector3(0, .6, 0)
	item_body.linear_velocity = Vector3.ZERO
	await tick(15)
	var lamp: rotatable_item = WorldState.spawn_item(load("res://Scenes/Actors/light.tscn"), level, Transform3D(Basis.IDENTITY, Vector3(1602.4, .05, 2.7)), false, true)
	lamp.place_on(portal.room.get_node("Art/Apartment shell/Solid"))
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	check(pickup.pickup_object(basket), "Fixture can carry a loaded basket")
	pickup._physics_process(.2)
	var cargo_pose: Transform3D = basket.global_transform.affine_inverse() * item_body.global_transform
	Input.parse_input_event(f9())
	await tick(4)
	var release: InputEventKey = f9()
	release.pressed = false
	Input.parse_input_event(release)
	check(portal.active_destination_id == &"warehouse" and not portal.inside, "F9 while inside returns player and selects warehouse")
	check(old_room.get_ref() == null, "Previous room is freed rather than cached")
	check(portal.room.get_node("Art").get_child_count() == 21, "Warehouse includes replacement machines, office and four decorative garbage bags")
	check(player.global_position.distance_to(portal.source_frame.global_position) < 2.3 and player.collision_mask == 1, "Cycling lands safely outside the workshop door")
	check(not basket.get_meta("portal_inside") and not item.get_meta("portal_inside"), "Loaded held basket returns with original actors")
	var returned_pose: Transform3D = basket.global_transform.affine_inverse() * item_body.global_transform
	check(returned_pose.origin.distance_to(cargo_pose.origin) < .002, "Cycling preserves contained cargo placement")
	check(not lamp.get_meta("portal_inside") and not lamp.placed and lamp.collision_mask == 1, "Placed room prop detaches and returns with workshop collision")
	pickup.drop_object()
	check(item_body.collision_mask == 1, "Returned basket snapshots restore workshop collision on drop")
	# Returned equipment is real physics: move it off the next walking route.
	portal._transfer_assembly(basket, Transform3D(Basis.IDENTITY, Vector3(5, 0, 0)), false)
	lamp.global_position.x += 5
	await enter()
	pose(Vector3(1609.55, .04, 10.6))
	await tick()
	await walk_until(func() -> bool: return player.global_position.y > 4.1 and player.global_position.z < 2.8, 240)
	check(player.global_position.y > 4.1, "Real capsule climbs all 24 warehouse stairs without a jump upgrade")
	check(peak_ascent < .12, "Warehouse stair collision produces a smooth rise instead of individual tread jumps")
	await walk_until(func() -> bool: return player.global_position.z < -11.5, 500)
	print("Warehouse office walk pose: ", player.global_position)
	check(player.global_position.z < -11.5 and player.global_position.y > 4.1, "Catwalk connects physically to the production office")
	portal._input(f9())
	await tick(4)
	check(portal.active_destination_id == &"hospital", "F9 selects hospital after warehouse")
	check(portal.room.get_node("Art").get_child_count() == 54, "Hospital includes replacement furniture and four decorative garbage bags")
	await enter()
	# Exercise every room opening with the actual capsule and imported collision.
	for z in [9.4, 3.75, -4.5, -10.15]:
		pose(Vector3(1600, .04, z), PI / 2)
		await tick()
		await walk_until(func() -> bool: return player.global_position.x < 1596.7, 90)
		check(player.global_position.x < 1596.7 and player.global_position.y > -.05, "West hospital room at %s is physically explorable" % z)
	for z in [9.4, -4.5, -10.15]:
		pose(Vector3(1600, .04, z), -PI / 2)
		await tick()
		await walk_until(func() -> bool: return player.global_position.x > 1603.3, 90)
		check(player.global_position.x > 1603.3 and player.global_position.y > -.05, "East hospital ward at %s is physically explorable" % z)
	pose(Vector3(1605.8, .04, .1), PI)
	await tick()
	await walk_until(func() -> bool: return player.global_position.z > 2.0, 90)
	check(player.global_position.z > 2.0, "Nursing station rear staff access is walkable")
	pose(portal.destination_frame.to_global(Vector3(0, -portal.source_offset.y + .04, 1.1)), PI)
	await walk_until(func() -> bool: return not portal.inside)
	check(not portal.inside and player.collision_mask == 1, "Real walking back through the hospital door returns to the workshop")
	await enter()
	WorldState._physics_process(0.0)
	WorldState.capture()
	var saved: Array = Blackboard.read_data("spawned_items").duplicate(true)
	var saved_pose: Transform3D = player.global_transform
	var encoded: Variant = SaveGame._encode(Blackboard._data)
	check(SaveGame._decode(encoded).get("portal_destination_id") == "hospital", "Selected destination survives the save codec")
	WorldState.tracking = false
	level.queue_free()
	await tick(4)
	Blackboard.store_data("spawned_items", saved)
	Blackboard.store_data("player_transform", saved_pose)
	Blackboard.store_data("portal_inside", true)
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	level.get_node("DoorPortal").purchase_required = false # Explicit free preview fixture.
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await tick(4)
	portal = level.get_node("DoorPortal")
	check(portal.active_destination_id == &"hospital" and portal.inside, "Startup restores the selected hospital and player's physics space")
	check(level.player.global_position.is_equal_approx(saved_pose.origin), "Reload keeps the matching saved hospital transform")
	check(not portal.select_destination(&"missing"), "Unknown destination does not unload the current area")
	var malformed := portal_destination.new()
	malformed.id = &"malformed"
	malformed.scene_path = "res://Tests/invalid_portal_destination.tscn"
	portal.destinations.append(malformed)
	var retained: WeakRef = weakref(portal.room)
	check(portal.select_destination(malformed.id), "Known replacement can be requested")
	await tick(4)
	check(retained.get_ref() == portal.room and portal.inside and not portal.switching, "Invalid replacement retains the existing room, player and controls")
	portal.destinations.erase(malformed)
	check(portal.cycle_destination(), "Last destination cycles back to apartment")
	await tick(4)
	check(portal.active_destination_id == &"apartment", "F9 order wraps without accumulating rooms")
	WorldState.tracking = false
	level.queue_free()
	await tick(4)
	for audio: audio_player in pool.active:
		audio.reset()
	await tick(4)
	print("Portal destinations / F9 / imported walking / cargo / save restoration: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
