extends Node

var failures: Array[String] = []
var world: Node3D

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 2) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(80, .4, 80)
	floor_collision.shape = floor_box
	floor_body.position.y = -.2
	floor_body.add_child(floor_collision)
	world.add_child(floor_body)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.position = Vector3(0, .01, -3)
	world.add_child(player)
	var movement: Node = player.get_node("Controllers/Player_Move_Controller")
	movement.footstep_player = null
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var fan: rotatable_item = load("res://Scenes/Actors/fan.tscn").instantiate()
	fan.freeze = true
	world.add_child(fan)
	await tick(40)
	check(player.position.z < -3.4 and movement.wind_velocity.length() > 1.0, "An unheld fan must push the actual player despite movement deceleration.")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	player.position = Vector3(0, .01, -3)
	movement.wind_velocity = Vector3.ZERO
	movement.applied_wind = Vector3.ZERO
	player.velocity = Vector3.ZERO
	fan.held = true
	await tick(5)
	check(movement.wind_velocity == Vector3.ZERO, "A held fan must not push the player.")
	fan.held = false
	player.position = Vector3(10, 0, 4)
	check(pickup.pickup_object(fan), "Fan must use normal pickup.")
	var before: Basis = fan.held_rotation
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	pickup._unhandled_input(wheel)
	check(not fan.held_rotation.is_equal_approx(before), "Wheel input rotates the held fan.")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.pressed = true
	pickup._unhandled_input(key)
	check(fan.rotation_axis == 2, "R changes the held rotation axis.")
	for i in 30:
		pickup._physics_process(1.0 / 60.0)
		await tick(1)
	check(fan.collision_layer == 0 and fan.get_node("Wind").collision_mask == 1, "Held fan retains wind sensing while its solid body ignores the player.")
	var item: Node3D = load("res://Scenes/test_object.tscn").instantiate()
	item.start_force = 0
	world.add_child(item)
	var body: RigidBody3D = item.get_node("RigidBody3D")
	body.set_script(null)
	body.contact_monitor = false
	body.gravity_scale = 0
	body.global_position = fan.to_global(Vector3(0, 1, -2))
	await tick(12)
	check(body.linear_velocity.dot(-fan.global_basis.z) > .5, "Held fans must still blow loose items in their rotated direction.")
	pickup.drop_object()
	check(not fan.held and fan.collision_layer == 1, "Dropping fan restores solid collision and player wind eligibility.")
	var plate: rotatable_item = load("res://Scenes/Actors/steel_plate.tscn").instantiate()
	plate.position = Vector3(-10, 3, 0)
	world.add_child(plate)
	check(not plate.has_node("Foot") and plate.get_node("PlateCollision").shape.size == Vector3(2.4, 2.4, .12), "Plate must be a single flat sheet without the T base.")
	check(not plate.freeze and plate.is_in_group("pick-up"), "Plate must spawn directly as a loose physical prop.")
	var basket: RigidBody3D = load("res://Scenes/Actors/basket.tscn").instantiate()
	basket.position = Vector3(-20, .02, 0)
	world.add_child(basket)
	body.gravity_scale = 1
	body.linear_velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.global_transform = Transform3D(Basis.IDENTITY, basket.to_global(Vector3(0, .8, 0)))
	await tick(120)
	check(basket.contained_bodies().has(body), "Basket must still capture a real gravity-settled item.")
	pickup.pickup_object(basket)
	for i in 20:
		player.position.x += .1
		pickup._physics_process(1.0 / 60.0)
		await tick(1)
	check(basket.contents.size() == 1 and body.freeze and body.get_parent() == item, "Basket carries items without changing their logical parent.")
	basket.empty_contents()
	check(not body.freeze and body.collision_layer == 1 and pickup.held_object == basket, "Basket empty restores physics while keeping it held.")
	pickup.drop_object()
	world.queue_free()
	await tick()
	print("Manual props and player wind: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
