extends Node

var failures: Array[String] = []
var world: Node3D
var player: CharacterBody3D
var movement: Node
var rail: train_rail
var slider: rail_slider


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
	SaveGame.enabled = false
	Blackboard.store_data("player_input_blocked", false)
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, .4, 80)
	shape.shape = box
	floor_body.position.y = -.2
	floor_body.add_child(shape)
	world.add_child(floor_body)
	rail = load("res://Scenes/Actors/train_rail.tscn").instantiate()
	rail.rail_length = 12.0
	world.add_child(rail)
	rail.place_on(floor_body)
	slider = load("res://Scenes/Actors/rail_slider.tscn").instantiate()
	world.add_child(slider)
	slider.global_transform = rail.carriage_pose(-2.0)
	slider.place_on(rail)
	player = load("res://Scenes/Player/player.tscn").instantiate()
	player.position = slider.to_global(Vector3(0, .14, 0))
	world.add_child(player)
	movement = player.get_node("Controllers/Player_Move_Controller")
	movement.footstep_player = null
	movement.jump_sounds.clear()
	movement.jump_enabled = true
	await tick(20)
	check(player.is_on_floor(), "The real player must settle onto the physical carriage deck.")
	var before_slider := slider.global_position
	var before_player := player.global_position
	slider.apply_drive_impulse(Vector3(0, 0, 10))
	await tick(80)
	print("ride positions ", slider.global_position, " ", player.global_position, " velocity ", player.get_platform_velocity(), " relative ", slider.to_local(player.global_position))
	check((slider.global_position - before_slider).z > 1.0, "An impulse must move the occupied carriage.")
	check(absf((player.global_position - before_player).z - (slider.global_position - before_slider).z) < .15,
		"The player must move with the carriage without holding a movement key.")
	check(player.is_on_floor() and absf(slider.to_local(player.global_position).z) < .15,
		"Standing on a moving carriage must keep the player supported and centered.")
	await _check_built_floor()
	await _check_reverse_and_walk()
	await _check_jump_and_teleport()
	await _check_join()
	await _check_blocked_relay()
	world.queue_free()
	await tick()
	print("Player rail platform riding: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)


func _check_built_floor() -> void:
	player.global_position = Vector3(10, 1, 0)
	slider.linear_velocity = Vector3.ZERO
	slider.slider_position = -2.0
	slider.sync_support_pose()
	var plate: rotatable_item = load("res://Scenes/Actors/steel_plate.tscn").instantiate()
	world.add_child(plate)
	plate.global_transform = slider.global_transform * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, .5, 0))
	plate.place_on(slider)
	player.global_position = plate.global_position + Vector3(0, .08, 0)
	player.velocity = Vector3.ZERO
	await tick(20)
	var before_player := player.global_position
	var before_slider := slider.global_position
	slider.apply_drive_impulse(Vector3(0, 0, 10))
	await tick(80)
	print("plate ride ", slider.global_position, " ", player.global_position, " velocity ", player.get_platform_velocity(), " relative ", slider.to_local(player.global_position))
	check(absf((player.global_position - before_player).z - (slider.global_position - before_slider).z) < .15,
		"The player must also ride a flat plate attached to the carriage.")
	plate.queue_free()
	await tick()


func _reset_deck(position_on_rail: float = -2.0) -> void:
	player.global_position = Vector3(15, 1, 15)
	slider.linear_velocity = Vector3.ZERO
	slider.slider_position = position_on_rail
	slider.sync_support_pose()
	player.global_position = slider.to_global(Vector3(0, .14, 0))
	player.velocity = Vector3.ZERO
	movement.reset_platform_motion()
	await tick(20)


func _check_reverse_and_walk() -> void:
	await _reset_deck()
	slider.apply_drive_impulse(Vector3(0, 0, -8))
	await tick(30)
	check(player.is_on_floor() and absf(slider.to_local(player.global_position).z) < .1, "Reversing the carriage keeps its rider supported.")
	Input.action_press("right")
	await tick(6)
	Input.action_release("right")
	check(slider.to_local(player.global_position).x > .08 and absf(slider.to_local(player.global_position).z) < .15, "Walking remains relative to the moving deck.")
	Input.action_press("right")
	await tick(40)
	Input.action_release("right")
	await tick(30)
	var after_dismount: Vector3 = player.global_position
	await tick(20)
	check(player.is_on_floor() and absf(player.global_position.y) < .03 and absf(player.global_position.z - after_dismount.z) < .03, "Walking off a moving carriage returns to normal floor movement without sticky transport.")


func _check_jump_and_teleport() -> void:
	await _reset_deck()
	slider.apply_drive_impulse(Vector3(0, 0, 8))
	await tick(15)
	Input.action_press("jump")
	await tick(1)
	Input.action_release("jump")
	await tick(6)
	check(not player.is_on_floor() and player.global_position.y > .7, "Jumping remains available from a moving carriage when unlocked.")
	var in_air: Vector3 = player.global_position
	await tick(12)
	check(absf(player.global_position.z - in_air.z) < .04, "Jumping off does not keep dragging or launch the player with carriage velocity.")
	player.global_position = Vector3(15, 1, 15)
	player.velocity = Vector3.ZERO
	await tick(35)
	check(player.global_position.distance_to(Vector3(15, .003667, 15)) < .04, "An external teleport cannot apply a stale carriage displacement.")
	await _reset_deck()
	slider.apply_drive_impulse(Vector3(0, 0, 8))
	await tick(12)
	player.global_position = Vector3(12, 1, 12)
	player.velocity = Vector3.ZERO
	movement.reset_platform_motion()
	await tick(35)
	check(absf(player.global_position.z - 12) < .03, "Explicit respawn and portal transport reset drops the previous platform velocity.")


func _check_join() -> void:
	var second: train_rail = load("res://Scenes/Actors/train_rail.tscn").instantiate()
	second.position = Vector3(0, 0, 7.5)
	world.add_child(second)
	second.place_on(rail.support.get_ref())
	var third: train_rail = load("res://Scenes/Actors/train_rail.tscn").instantiate()
	third.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, 10.5))
	world.add_child(third)
	third.place_on(rail.support.get_ref())
	await tick(4)
	slider.travel_damping = 0
	slider.linear_damp = 0
	slider.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	await _reset_deck(5.2)
	slider.apply_drive_impulse(Vector3(0, 0, 10))
	await tick(125)
	check(slider.mounted_rail() == third and player.is_on_floor() and absf(slider.to_local(player.global_position).z) < .12, "The real player crosses two rail joins, including a reversed section, without losing the deck.")
	slider.apply_drive_impulse(Vector3(0, 0, -20))
	await tick(140)
	check(slider.mounted_rail() == rail and player.is_on_floor() and absf(slider.to_local(player.global_position).z) < .12, "A player also rides back across joined rails in the opposite direction.")
	second.queue_free()
	third.queue_free()
	await tick(4)


func _check_blocked_relay() -> void:
	await _reset_deck()
	var plate: rotatable_item = load("res://Scenes/Actors/steel_plate.tscn").instantiate()
	world.add_child(plate)
	plate.global_transform = slider.global_transform * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, .5, 0))
	plate.place_on(slider)
	player.global_position = plate.global_position + Vector3(0, .08, 0)
	player.velocity = Vector3.ZERO
	movement.reset_platform_motion()
	await tick(20)
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(8, .5, .12)
	collider.shape = shape
	wall.add_child(collider)
	wall.position = Vector3(0, 1.8, player.global_position.z + 1.0)
	world.add_child(wall)
	slider.apply_drive_impulse(Vector3(0, 0, 10))
	await tick(30)
	check(player.global_position.z < wall.global_position.z - .3, "A wall blocks a rider on a frozen attached plate while the carriage continues beneath it.")
	slider.linear_velocity = Vector3.ZERO
	var stopped: Vector3 = player.global_position
	await tick(12)
	check(absf(player.global_position.z - stopped.z) < .03 and absf(player.velocity.z) < .03, "A blocked platform relay cannot leave backward drift after the carriage stops.")
	wall.queue_free()
	plate.queue_free()
	await tick(4)
