extends Node

class SilentPlayer extends audio_player:
	func _ready() -> void:
		pass
	func play_global(_stream: AudioStream, _volume: float = 1.0, _pitch: float = 1.0, _bus: StringName = &"Master") -> void:
		playback_finished.emit()
class SilentPool extends object_pool:
	func _create_object() -> Node:
		var sound := SilentPlayer.new()
		add_child(sound)
		return sound

var failures: Array[String] = []
var world: Node3D
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func tick(count: int = 2) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame
func item(point: Vector3) -> RigidBody3D:
	var rigid := RigidBody3D.new()
	rigid.position = point
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * .25
	collision.shape = shape
	rigid.add_child(collision)
	world.add_child(rigid)
	return rigid
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var pool := SilentPool.new()
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	ScoreRewards.reset()
	ScoreRewards.set_process(false)
	Blackboard.store_data("score", 0)
	ScoreRewards.enqueue(6)
	check(Blackboard.read_data("score") == 1 and ScoreRewards.pending_points == 5, "A bulk reward must immediately award only one point.")
	ScoreRewards._process(.25)
	check(Blackboard.read_data("score") == 1, "Points must wait for their interval.")
	ScoreRewards._process(.25)
	check(Blackboard.read_data("score") == 2 and is_equal_approx(ScoreRewards.current_interval, .48), "Next point shortens the interval by .02.")
	ScoreRewards.enqueue(3)
	check(Blackboard.read_data("score") == 2 and ScoreRewards.pending_points == 7 and is_equal_approx(ScoreRewards.current_interval, .48), "New rewards extend an active queue without resetting speed or paying instantly.")
	ScoreRewards._process(.48)
	check(Blackboard.read_data("score") == 3 and is_equal_approx(ScoreRewards.current_interval, .46), "Each point continues to accelerate.")
	ScoreRewards.current_interval = .01
	ScoreRewards._process(.5)
	check(Blackboard.read_data("score") == 9 and ScoreRewards.pending_points == 0 and ScoreRewards.current_interval == .5, "At zero interval, flush remaining score and reset.")
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, .2, 80)
	collision.shape = box
	floor_body.position.y = -.1
	floor_body.add_child(collision)
	world.add_child(floor_body)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(player)
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var placement: prop_placement = player.get_node("Controllers/Prop_Placement")
	var basket: RigidBody3D = load("res://Scenes/Actors/basket.tscn").instantiate()
	basket.freeze = true
	basket.position = Vector3(-10, 2, 0)
	world.add_child(basket)
	var first: RigidBody3D = item(basket.to_global(Vector3(-.3, .6, 0)))
	var second: RigidBody3D = item(basket.to_global(Vector3(.3, .6, 0)))
	await tick(70)
	check(pickup.pickup_object(basket) and basket.contents.size() == 2, "Basket must collect multiple settled bodies.")
	var first_position: Vector3 = first.global_position
	var second_position: Vector3 = second.global_position
	basket.empty_contents()
	check(first.global_position == first_position and second.global_position == second_position and first.linear_velocity == Vector3.ZERO and second.linear_velocity == Vector3.ZERO, "Emptying must not teleport or launch contents.")
	await tick(45)
	check(first.global_position.y < first_position.y - .3 and second.global_position.y < second_position.y - .3, "Released bodies must fall through the basket bottom under gravity.")
	check(basket.falling_contents.is_empty(), "Basket collision exceptions must clear after the bodies leave.")
	pickup.drop_object()
	for id in ["upgraded_fan", "upgraded_steel_plate"]:
		var prop: rotatable_item = load("res://Scenes/Actors/%s.tscn" % id).instantiate()
		prop.position = Vector3(5, 4, 5)
		prop.rotation = Vector3(.2, .4, .6)
		world.add_child(prop)
		pickup.pickup_object(prop)
		var pose: Transform3D = prop.global_transform
		var build := InputEventKey.new()
		build.physical_keycode = KEY_V
		build.pressed = true
		placement._unhandled_input(build)
		check(prop.placed and prop.freeze and prop.global_transform.is_equal_approx(pose) and not pickup.is_holding_object() and not placement.is_building(), "V must lock the upgrade at its exact held pose: " + id)
		await tick()
		check(prop.global_transform.is_equal_approx(pose), "Air placement must remain stable without a support.")
		pickup.pickup_object(prop)
		pickup.drop_object()
		check(not prop.freeze, "Retrieved upgrades must return to normal loose physics.")
		prop.queue_free()
	var broom: RigidBody3D = load("res://Scenes/Actors/push_broom.tscn").instantiate()
	world.add_child(broom)
	pickup.pickup_object(broom)
	pickup._physics_process(1.0 / 60.0)
	check(absf(broom.position.y - .02) < .01, "Equipped broom must stay against the ground in front of the player.")
	var a: RigidBody3D = item(broom.to_global(Vector3(-.3, .2, -.3)))
	var b: RigidBody3D = item(broom.to_global(Vector3(.3, .2, -.3)))
	await tick(3)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	broom._unhandled_input(click)
	for i in 8:
		pickup._physics_process(1.0 / 60.0)
		await tick(1)
	check(a.linear_velocity.dot(Vector3.FORWARD) > .3 and b.linear_velocity.dot(Vector3.FORWARD) > .3, "LMB broom stroke must push multiple loose items.")
	pickup.throw_object()
	check(pickup.held_object == broom, "Broom cannot be thrown.")
	check(not placement.start_building(), "Broom cannot use building placement.")
	pickup.drop_object()
	check(not broom.held and not broom.freeze, "F must put down the broom as a physical object.")
	world.queue_free()
	await tick()
	print("Basket, broom, air upgrades and score queue: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
