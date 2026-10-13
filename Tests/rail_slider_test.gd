extends Node

var failures: Array[String] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func tick(count: int = 2) -> void:
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var anchor := StaticBody3D.new()
	anchor.name = "RailAnchor"
	world.add_child(anchor)
	var rail: train_rail = load("res://Scenes/Actors/train_rail.tscn").instantiate()
	rail.rail_length = 8.0
	rail.position = Vector3(0, 3, 0)
	world.add_child(rail)
	rail.place_on(anchor)
	var slider: rail_slider = load("res://Scenes/Actors/rail_slider.tscn").instantiate()
	world.add_child(slider)
	check(not slider.can_place_on(anchor), "A slider must require a rail rather than mounting to arbitrary scenery.")
	var snap: Dictionary = slider.get_placement_pose(rail, rail.to_global(Vector3(.28, .19, .4)), Vector3.UP, Basis.IDENTITY)
	check(snap.valid and snap.host == rail and rail.to_local(snap.transform.origin).is_equal_approx(Vector3(0, rail.carriage_height, .4)), "Slider ghost must snap to the rail centerline and correct height.")
	slider.global_transform = snap.transform
	slider.place_on(rail)
	check(slider.placed and not slider.freeze and slider.support.get_ref() == rail, "Mounted carriage stays a physical placed prop.")
	await _check_ghost_placement(world, rail)
	slider.apply_drive_impulse(Vector3(10, 0, 0))
	await tick(8)
	check(absf(slider.slider_position - .4) < .04, "Transverse impulses cannot push the carriage off the rail.")
	slider.apply_drive_impulse(Vector3(0, 0, 10))
	await tick(30)
	check(slider.slider_position > .7, "A drive impulse physically moves the carriage along its rail.")
	check(absf(rail.to_local(slider.global_position).x) < .01 and absf(rail.to_local(slider.global_position).y - rail.carriage_height) < .01, "The carriage cannot leave its constrained axis.")
	slider.apply_drive_impulse(Vector3(0, 0, 100))
	await tick(80)
	check(slider.slider_position <= rail.travel_limit() + .01 and absf(slider.linear_velocity.z) < .1, "End stops must stop motion without allowing the carriage to escape.")
	var old_pose: Transform3D = slider.global_transform
	anchor.position.x += 2
	rail.sync_support_pose()
	slider.sync_support_pose()
	check(slider.global_position.is_equal_approx(old_pose.origin + Vector3(2, 0, 0)), "Carriage follows a moved rail and its support.")
	slider.slider_position = 0.0
	slider.linear_velocity = Vector3.ZERO
	slider.sync_support_pose()
	var drive_fan: rotatable_item = load("res://Scenes/Actors/fan.tscn").instantiate()
	world.add_child(drive_fan)
	drive_fan.global_transform = slider.global_transform * Transform3D(Basis.IDENTITY, Vector3(1.2, .12, 0))
	drive_fan.place_on(slider)
	await tick(60)
	check(slider.slider_position > .35, "An attached powered fan drives the carriage opposite its airflow.")
	drive_fan.queue_free()
	await tick()
	var light: rotatable_item = load("res://Scenes/Actors/light.tscn").instantiate()
	world.add_child(light)
	light.global_position = slider.global_position + Vector3(.5, slider.deck_surface, 0)
	light.place_on(slider)
	var item: Node3D = load("res://Scenes/test_object.tscn").instantiate()
	item.start_force = 0.0
	item.set_meta("persistent_item_id", "test-cargo")
	world.add_child(item)
	var body: RigidBody3D = item.get_node("RigidBody3D")
	body.contact_monitor = false
	body.global_position = slider.global_position + Vector3(0, .5, 0)
	await tick(90)
	check(slider.get_carried_bodies().has(body) and body.freeze, "Objects actually resting on the top become carriage cargo.")
	var cargo_pose: Transform3D = slider.global_transform.affine_inverse() * body.global_transform
	slider.apply_drive_impulse(Vector3(0, 0, -12))
	await tick(25)
	light.sync_support_pose()
	check(body.global_transform.is_equal_approx(slider.global_transform * cargo_pose), "Top cargo follows carriage motion rather than sliding away.")
	check(light.global_transform.is_equal_approx(slider.global_transform * light.support_pose), "Built attachments also follow carriage motion.")
	var saved: Dictionary = slider.get_rail_state()
	check(saved.cargo.size() == 1 and saved.cargo[0].id == "test-cargo", "Cargo save state identifies its existing actor instead of copying items.")
	slider.release_cargo_body(body)
	check(not body.freeze and not body.has_meta("rail_cargo_owner"), "Removing cargo restores its original physics.")
	slider.restore_rail_state(saved, func(id: String) -> Node3D: return item if id == "test-cargo" else null)
	check(slider.get_carried_bodies().has(body) and body.freeze, "Saved cargo can be reattached to its existing actor after restoration.")
	light.queue_free()
	await tick()
	var basket: RigidBody3D = load("res://Scenes/Actors/basket.tscn").instantiate()
	basket.set_meta("persistent_item_id", "test-basket")
	world.add_child(basket)
	slider.release_cargo_body(body)
	body.global_position = Vector3(20, 3, 0)
	slider.linear_velocity = Vector3.ZERO
	basket.global_position = slider.global_position + Vector3(0, .14, 0)
	await tick(30)
	check(slider.get_carried_bodies().has(basket), "A basket resting on the carriage must move with it.")
	body.global_position = basket.to_global(Vector3(0, .7, 0))
	body.linear_velocity = Vector3.ZERO
	await tick(90)
	check(slider.get_carried_bodies().has(body) and basket.contents.size() == 1, "New items dropped into a carriage basket become contained cargo too.")
	var basket_pose: Transform3D = slider.global_transform.affine_inverse() * basket.global_transform
	var inner_pose: Transform3D = basket.global_transform.affine_inverse() * body.global_transform
	slider.apply_drive_impulse(Vector3(0, 0, -8))
	await tick(20)
	check(basket.global_transform.is_equal_approx(slider.global_transform * basket_pose) and body.global_transform.is_equal_approx(basket.global_transform * inner_pose), "A moving carriage must move the basket and its physically contained contents together.")
	slider.linear_velocity = Vector3.ZERO
	var basket_fan: rotatable_item = load("res://Scenes/Actors/fan.tscn").instantiate()
	world.add_child(basket_fan)
	basket_fan.global_position = basket.to_global(Vector3(.72, 1.05, .1))
	basket_fan.place_on(basket)
	var before_basket_thrust: float = slider.slider_position
	await tick(60)
	check(basket_fan._drive_host() == slider and slider.slider_position > before_basket_thrust + .25, "A fan attached to a cargo basket must drive the underlying carriage too.")
	basket_fan.queue_free()
	await tick()
	var saved_basket_state: Dictionary = slider.get_rail_state()
	check(saved_basket_state.cargo.size() == 1 and saved_basket_state.cargo[0].contents.size() == 1, "A carriage basket saves its nested contents and their original physical state.")
	slider.on_picked_up()
	check(not basket.freeze and not body.freeze and basket.contents.is_empty(), "Retrieving the carriage releases cargo and nested basket contents cleanly.")
	slider.held = false
	slider.place_on(rail)
	slider.restore_rail_state(saved_basket_state, func(id: String) -> Node3D: return basket if id == "test-basket" else item if id == "test-cargo" else null)
	check(basket.contents.size() == 1 and body.freeze, "Nested basket contents restore before Area3D overlap information becomes available.")
	await _check_assembly_pickup(world, rail, slider, basket, body, anchor)
	await _check_world_roundtrip(world, rail, slider, basket, item)
	world.queue_free()
	await tick()
	print("Rail slider physics, cargo and save state: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_ghost_placement(world: Node3D, rail: train_rail) -> void:
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3(20, 3, 20)
	world.add_child(player)
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var placement: prop_placement = player.get_node("Controllers/Prop_Placement")
	var camera: Camera3D = player.get_node("Camera3D")
	var ghost_item: rail_slider = load("res://Scenes/Actors/rail_slider.tscn").instantiate()
	ghost_item.position = Vector3(12, 3, 12)
	world.add_child(ghost_item)
	pickup.pickup_object(ghost_item)
	camera.global_position = rail.to_global(Vector3(.28, 4, -2))
	camera.look_at(rail.to_global(Vector3(.28, .15, -2)), Vector3.FORWARD)
	await tick()
	check(placement.start_building() and placement.placement_valid and placement.host == rail, "B creates a valid carriage ghost on a real rail collider.")
	check(rail.to_local(placement.preview.global_position).is_equal_approx(Vector3(0, rail.carriage_height, -2)), "The real placement ghost centers itself on the rail instead of the hit beam edge.")
	check(placement.try_build() and ghost_item.placed and ghost_item.mounted_rail() == rail, "A second B places the original carriage onto its rail.")
	player.queue_free()
	ghost_item.queue_free()
	await tick()


func _check_assembly_pickup(world: Node3D, rail: train_rail, slider: rail_slider, basket: RigidBody3D, body: RigidBody3D, anchor: StaticBody3D) -> void:
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3(20, 3, 20)
	world.add_child(player)
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var pose: Transform3D = rail.global_transform
	pickup.pickup_object(rail)
	pickup._physics_process(1.0 / 60.0)
	check(is_equal_approx(slider.get_node("Deck").transparency, .35) and is_equal_approx(basket.get_node("Bottom").transparency, .35), "A carried rail assembly fades each slider and basket exactly once.")
	check(slider.collision_layer == 0 and basket.collision_layer == 0 and body.collision_layer == 0 and slider.freeze, "Carrying the rail disables physics for its mounted carriage and loaded cargo.")
	pickup.drop_object()
	rail.global_transform = pose
	rail.place_on(anchor)
	slider.sync_support_pose()
	check(slider.get_node("Deck").transparency == 0.0 and basket.get_node("Bottom").transparency == 0.0, "Dropping the complete rail assembly restores original transparency.")
	check(slider.collision_layer == 1 and basket.collision_layer == 1 and not slider.freeze, "Dropping the rail restores mounted carriage motion and solid cargo.")
	player.queue_free()
	await tick()


func _check_world_roundtrip(world: Node3D, rail: train_rail, slider: rail_slider, basket: RigidBody3D, item: Node3D) -> void:
	var player := CharacterBody3D.new()
	player.add_child(Camera3D.new())
	world.add_child(player)
	Blackboard.store_data("spawned_items", [])
	WorldState.begin(world, player)
	await tick(3)
	WorldState.track(rail, "test-rail")
	WorldState.track(slider, "test-slider")
	WorldState.track(basket, "test-basket")
	WorldState.track(item, "test-cargo")
	var fan: rotatable_item = load("res://Scenes/Actors/fan.tscn").instantiate()
	fan.powered = false
	world.add_child(fan)
	fan.global_position = slider.to_global(Vector3(1.2, .12, 0))
	fan.place_on(slider)
	WorldState.track(fan, "test-fan")
	WorldState.capture()
	var records: Array = Blackboard.read_data("spawned_items").duplicate(true)
	WorldState.tracking = false
	# Stop the originals so their sensors cannot capture restored test actors.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.position = Vector3(100, 100, 100)
	var restored := Node3D.new()
	add_child(restored)
	var anchor := StaticBody3D.new()
	anchor.name = "RailAnchor"
	restored.add_child(anchor)
	var avatar := CharacterBody3D.new()
	avatar.add_child(Camera3D.new())
	restored.add_child(avatar)
	Blackboard.store_data("spawned_items", records)
	WorldState.begin(restored, avatar)
	await tick(8)
	var restored_slider: rail_slider = WorldState._actor("test-slider") as rail_slider
	var restored_basket: RigidBody3D = WorldState._actor("test-basket") as RigidBody3D
	var restored_item: Node3D = WorldState._actor("test-cargo")
	var restored_fan: rotatable_item = WorldState._actor("test-fan") as rotatable_item
	check(is_instance_valid(restored_slider) and restored_slider.placed and restored_slider.mounted_rail() != null and not restored_slider.freeze, "WorldState restores the existing rail and physical mounted slider.")
	check(is_instance_valid(restored_fan) and restored_fan.support.get_ref() == restored_slider, "WorldState restores built fan attachments to the moving carriage.")
	if is_instance_valid(restored_basket) and is_instance_valid(restored_item):
		var restored_body: RigidBody3D = restored_item.get_node("RigidBody3D")
		check(restored_slider.get_carried_bodies().has(restored_basket) and restored_basket.contents.size() == 1 and restored_body.freeze, "WorldState restores carriage basket contents without duplicating or losing them.")
		restored_basket.empty_contents()
		await tick(1)
		check(restored_basket.contents.is_empty(), "Emptying a mounted basket must not immediately recapture the items leaving its bottom.")
		await tick(20)
		check(restored_basket.contents.is_empty(), "A mounted basket must keep released bottom contents out of its carried list.")
		restored_slider.on_picked_up()
		check(not restored_basket.freeze and not restored_body.freeze, "Restored cargo returns to normal physics when released.")
	else:
		check(false, "WorldState must recreate each existing cargo actor.")
	WorldState.tracking = false
	restored.queue_free()
	await tick()
