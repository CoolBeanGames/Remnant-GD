extends Node
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	DevConsole.execute('Set flag "console test"')
	check(Flags.check_flag("console test"), "Quoted flag set")
	DevConsole.execute('set flag "console test" false')
	check(not Flags.check_flag("console test"), "Flag can be unset")
	DevConsole.execute('Set BB "test text" "hello world"')
	check(Blackboard.read_data("test text") == "hello world", "Quoted value retains spaces")
	DevConsole.execute('set bb "number" 12')
	DevConsole.execute('set bb "list" [1, 2, {"name": "fan"}]')
	check(Blackboard.read_data("number") == 12 and Blackboard.read_data("list")[2].name == "fan", "Typed JSON values supported")
	DevConsole.execute('Set score 456')
	DevConsole.execute('set score -1')
	check(Blackboard.read_data("score") == 456, "Score validates nonnegative integer")
	check(DevConsole.execute("tp 1 2 3").contains("No active player"), "Title missing player handled")
	var player := CharacterBody3D.new()
	player.collision_layer = 1
	player.collision_mask = 1
	add_child(player)
	var collider := CollisionShape3D.new()
	collider.shape = CapsuleShape3D.new()
	collider.shape.radius = .3
	collider.shape.height = 1.0
	player.add_child(collider)
	var controllers := Node.new()
	controllers.name = "Controllers"
	player.add_child(controllers)
	var movement = load("res://Scripts/Player/player_move_controller.gd").new()
	movement.name = "Player_Move_Controller"
	movement.body = player
	movement.character_body = player
	controllers.add_child(movement)
	movement.set_physics_process(false)
	WorldState.player = player
	DevConsole.execute("TP 1 2 3")
	check(player.global_position == Vector3(1,2,3) and Blackboard.read_data("player_position") == Vector3(1,2,3), "Teleport updates actual pose and Blackboard")
	check(DevConsole.execute("tp nope 2 3").contains("finite") and player.global_position == Vector3(1,2,3), "Invalid teleport doesn't move player")
	DevConsole.execute("Fly")
	check(movement.debug_fly and player.collision_mask == 1, "Fly keeps collisions")
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 0, -2)
	add_child(wall)
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, .4)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	await get_tree().physics_frame
	player.global_position = Vector3.ZERO
	Blackboard.store_data("player_input_blocked", false)
	Input.action_press("forward")
	for i in 120:
		movement._debug_move(.1)
	Input.action_release("forward")
	check(player.global_position.z > -1.6, "Fly is stopped by physical wall")
	DevConsole.execute("Noclip on")
	check(movement.debug_noclip and player.collision_layer == 0 and player.collision_mask == 0, "Noclip disables physics and sensor participation")
	player.global_position = Vector3.ZERO
	Blackboard.store_data("player_input_blocked", false)
	Input.action_press("forward")
	movement._debug_move(.5)
	Input.action_release("forward")
	check(player.global_position.z < -4.9, "Noclip performs free flight")
	DevConsole.execute("noclip off")
	DevConsole.execute("fly off")
	check(not movement.debug_noclip and not movement.debug_fly and player.collision_layer == 1 and player.collision_mask == 1, "Collision masks restored and modes disabled")
	DevConsole.open_console()
	DevConsole.execute('set bb "player_input_blocked" false')
	check(get_tree().paused and Blackboard.read_data("player_input_blocked"), "Console retains input ownership while editing lock")
	DevConsole.close_console()
	check(not get_tree().paused and not Blackboard.read_data("player_input_blocked"), "Edited input lock restored on close")
	get_tree().paused = true
	DevConsole.open_console()
	DevConsole.close_console()
	check(get_tree().paused, "Existing pause retained")
	get_tree().paused = false
	check(DevConsole.tokenize('set bb "bad').is_empty(), "Unmatched quotes rejected")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_QUOTELEFT
	event.pressed = true
	DevConsole._input(event)
	check(DevConsole.is_open, "Tilde key opens console")
	DevConsole._input(event)
	check(not DevConsole.is_open, "Tilde key closes console")
	DevConsole.maximum_history = 3
	DevConsole.maximum_output_characters = 128
	for index in 10:
		DevConsole._submit("echo bounded-console-output-%s" % index)
	check(DevConsole.history.size() == 3, "Console command history stays bounded")
	check(DevConsole.output.text.length() <= 128 and DevConsole.output.text.contains("bounded-console-output-9"), "Console output is bounded and retains recent results")
	player.queue_free()
	print("Console parsing, state commands, teleport, fly/noclip and modal ownership: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
