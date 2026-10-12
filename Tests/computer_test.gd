extends Node
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Progression.levels.clear()
	Progression.entries.clear()
	Blackboard.store_data("score", 5000)
	Blackboard.store_data("player_input_blocked", false)
	var world := Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60, .2, 60)
	collision.shape = box
	floor_body.position.y = -.1
	floor_body.add_child(collision)
	world.add_child(floor_body)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.add_child(player)
	var terminal: computer_terminal = load("res://Scenes/Computer/computer_terminal.tscn").instantiate()
	terminal.player = player
	var delivery := Marker3D.new()
	delivery.position = Vector3(12, 10, 12)
	world.add_child(delivery)
	terminal.delivery_point = delivery
	world.add_child(terminal)
	check(terminal.catalog.entries.size() == 42, "Editable catalog contains regular upgrades, approved tool upgrades, three memory unlocks, twelve store entries and nine permanent mulch upgrades.")
	var old_fan: Node3D = load("res://Scenes/Actors/fan.tscn").instantiate()
	old_fan.position = Vector3(20, 2, 20)
	world.add_child(old_fan)
	var old_force: float = old_fan.force
	check(terminal.buy(Progression.entries[&"fan_power"]) == "", "Buy mechanics upgrade.")
	var current_score: int = Progression.score()
	check(terminal.buy(Progression.entries[&"buy_fan"]) == "" and Progression.score() == current_score - 35, "Store deducts exact score.")
	var new_fan: Node3D = world.get_child(world.get_child_count() - 1)
	check(new_fan.global_position.is_equal_approx(delivery.global_position) and new_fan.force == old_force * 1.25, "Purchased fan drops from the sky with upgraded force.")
	check(old_fan.force == old_force, "Mechanics upgrades never modify existing fans.")
	var old_plate: RigidBody3D = load("res://Scenes/Actors/steel_plate.tscn").instantiate()
	old_plate.position = Vector3(-20, 2, -20)
	world.add_child(old_plate)
	var bounce: float = old_plate.physics_material_override.bounce
	terminal.buy(Progression.entries[&"plate_bounce"])
	terminal.buy(Progression.entries[&"buy_steel_plate"])
	var new_plate: RigidBody3D = world.get_child(world.get_child_count() - 1)
	check(is_equal_approx(new_plate.physics_material_override.bounce, bounce + .1) and old_plate.physics_material_override.bounce == bounce, "Only future plates get a private upgraded physics material.")
	var old_item: Node3D = load("res://Scenes/test_object.tscn").instantiate()
	var value: int = physics_items.score_component(old_item).score
	world.add_child(old_item)
	terminal.buy(Progression.entries[&"item_value"])
	var future_item: Node3D = load("res://Scenes/test_object.tscn").instantiate()
	Progression.apply_spawned_value(future_item)
	world.add_child(future_item)
	check(physics_items.score_component(future_item).score == value * 2 and physics_items.score_component(old_item).score == value, "Value upgrades affect future items only.")
	var movement: Node = player.get_node("Controllers/Player_Move_Controller")
	# This isolated ability fixture has no audio pool until its later audio checks.
	movement.jump_sounds.clear()
	var base_speed: float = movement.move_speed
	terminal.buy(Progression.entries[&"run_speed"])
	check(is_equal_approx(movement.move_speed, base_speed * 1.15), "Self upgrade changes actual movement speed immediately.")
	Progression.apply_player(player)
	check(is_equal_approx(movement.move_speed, base_speed * 1.15), "Rebinding upgrades never double-applies multipliers.")
	terminal.buy(Progression.entries[&"jump"])
	current_score = Progression.score()
	check(terminal.buy(Progression.entries[&"jump"]) == "Upgrade complete." and Progression.score() == current_score, "Completed upgrades reject further spending.")
	for i in 10:
		movement._physics_process(1.0 / 60.0)
		await tick()
	Input.action_press("jump")
	movement._physics_process(1.0 / 60.0)
	check(movement.jump_enabled and player.velocity.y > 0 and player.position.y > 0, "Jump purchase enables actual grounded Space jump.")
	Input.action_release("jump")
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	terminal.buy(Progression.entries[&"multi_grab"])
	check(pickup.grab_capacity == 2, "Multi Grab adds one carrying slot.")
	player.position = Vector3(4, 0, 4)
	var bodies: Array[RigidBody3D] = []
	for i in 2:
		var body := RigidBody3D.new()
		body.add_to_group("pick-up")
		body.position = Vector3(4 + i * .4, .5, 3)
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		body.add_child(shape)
		world.add_child(body)
		bodies.append(body)
	await tick()
	check(pickup.pickup_object(bodies[0]) and pickup.extra_items.size() == 1 and bodies[1].freeze and bodies[1].collision_layer == 0, "Multi Grab carries nearby loose items with collisions off.")
	pickup._physics_process(.1)
	var state: Dictionary = pickup.extra_items[0]
	check(bodies[1].global_transform.is_equal_approx(bodies[0].global_transform * state.pose), "Group follows held item while preserving relative spacing.")
	pickup.throw_charge = pickup.charge_time
	pickup.throw_object()
	check(not bodies[1].freeze and bodies[1].collision_layer == 1 and bodies[1].linear_velocity.is_equal_approx(bodies[0].linear_velocity), "Group throws together and restores physics.")
	for i in 2:
		bodies[i].position = Vector3(4 + i * .4, .5, 3)
		bodies[i].linear_velocity = Vector3.ZERO
	await tick()
	pickup.pickup_object(bodies[0])
	check(pickup.extra_items.size() == 1, "Group can be picked up again after throwing.")
	pickup.drop_object()
	check(not bodies[1].freeze and bodies[1].collision_layer == 1 and pickup.extra_items.is_empty(), "F drop restores every extra item's normal physics.")
	Blackboard.store_data("score", 0)
	var count: int = world.get_child_count()
	check(terminal.buy(Progression.entries[&"buy_fan"]) == "Not enough score." and world.get_child_count() == count, "Unaffordable purchases produce neither deliveries nor debt.")
	Blackboard.store_data("score", 1000)
	var mouse_before: Input.MouseMode = Input.mouse_mode
	terminal.interact()
	await tick()
	var ui: computer_ui = terminal.interface
	check(ui.is_open and Blackboard.read_data("player_input_blocked") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "E opens terminal and blocks gameplay input.")
	check(ui.tabs.get_child(0).get_node("List").get_child_count() == 15 and ui.tabs.get_child(1).get_node("List").get_child_count() == 6 and ui.tabs.get_child(2).get_node("List").get_child_count() == 12 and ui.tabs.is_tab_hidden(3), "Computer presents expanded regular categories and locks Mulch until both purchases.")
	ui._buy(Progression.entries[&"buy_light"])
	check(Progression.score() == 990 and ui.score_label.text.contains("00000990"), "UI button buys a real delivery and refreshes credit.")
	ui.close()
	await get_tree().create_timer(terminal.return_seconds + .06).timeout
	check(not Blackboard.read_data("player_input_blocked") and Input.mouse_mode == mouse_before, "Closing restores gameplay and the previous mouse mode.")
	# Optional fan audio never calls play for an empty stream.
	old_fan._process(.01)
	check(not old_fan.fan_audio.playing and old_fan.fan_audio.stream == null, "Blank fan audio is safe and silent.")
	old_fan.fan_audio.stream = load("res://Audio/SFX/machine_run.wav")
	old_fan._process(.01)
	check(old_fan.fan_audio.playing and old_fan.fan_audio is AudioStreamPlayer3D, "Assigned fan sound plays through its local 3D player.")
	old_fan.hide()
	old_fan._process(.01)
	check(not old_fan.fan_audio.playing, "Hidden fan stops audio during ghost placement.")
	var light := OmniLight3D.new()
	light.set_script(load("res://Scripts/Level/light_flicker.gd"))
	world.add_child(light)
	light.set_process(false)
	var empty_sounds: Array[AudioStream] = [null]
	light.flicker_sounds = empty_sounds
	light.remaining = 0
	light._process(.01)
	check(light.light_energy == 0, "Blank/null flicker sound arrays are safe while light still flickers.")
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	world.add_child(pool)
	var sound_bank: Array[AudioStream] = [load("res://Audio/SFX/Lever/Lever_Reset.wav")]
	light.flicker_sounds = sound_bank
	light.remaining = 0
	light.transitions_left = 0
	light.powered = true
	light._process(.001)
	check(pool.active.size() == 1 and (pool.active[0] as audio_player).audio_3d.stream == sound_bank[0] and (pool.active[0] as audio_player).audio_3d.bus == &"RoomSFX", "Configured flicker bank plays one pooled 3D sound on outages.")
	world.queue_free()
	await tick()
	Blackboard.remove_data("game_root")
	Blackboard.remove_data("audio_pool")
	Blackboard.store_data("player_input_blocked", false)
	Progression.levels.clear()
	print("Computer purchases/upgrades/abilities/audio: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
