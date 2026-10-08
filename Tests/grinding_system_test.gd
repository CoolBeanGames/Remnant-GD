extends Node

# Audio timing/routing and real playback are covered by score_rewards_test.
class SilentPlayer extends audio_player:
	func _ready() -> void:
		pass

	func play_global(_stream: AudioStream, _volume: float = 1.0, _pitch: float = 1.0, _bus: StringName = &"Master") -> void:
		playback_finished.emit()

class SilentPool extends object_pool:
	func _create_object() -> Node:
		var player := SilentPlayer.new()
		add_child(player)
		return player

var failures: Array[String] = []
var world: Node3D
var grinder: grinding_area


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame


func _make_body(parent: Node, position: Vector3 = Vector3(20, 0, 0)) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.gravity_scale = 0
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.25, 0.25, 0.25)
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body


func _run() -> void:
	var pool := SilentPool.new()
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	ScoreRewards.point_interval = 0.01
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	Blackboard.remove_data("score")
	grinder = grinding_area.new()
	grinder.collision_layer = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2, 2, 2)
	collision.shape = shape
	grinder.add_child(collision)
	world.add_child(grinder)
	check(Blackboard.read_data("score") == 0, "The grinder must initialize missing Blackboard score to zero.")
	Blackboard.store_data("score", 10)
	var other := grinding_area.new()
	world.add_child(other)
	check(Blackboard.read_data("score") == 10, "Additional grinders must preserve existing score.")
	other.queue_free()
	var unmarked := _make_body(world)
	check(grinder.grind(unmarked), "Unmarked loose items must still be destroyed.")
	check(unmarked.is_queued_for_deletion() and Blackboard.read_data("score") == 10, "Unmarked items must not award points.")
	var default_item := _make_body(world)
	default_item.add_to_group("score")
	check(grinder.grind(default_item), "Scoring bodies must be accepted.")
	check(Blackboard.read_data("score") == 11, "Score-group items without a component must award one point.")
	check(not grinder.grind(default_item) and Blackboard.read_data("score") == 11, "Repeated events before deletion must not award twice.")
	var custom_item := _make_body(world)
	custom_item.add_to_group("score")
	var custom_score: score_object = load("res://Scenes/Actors/score_object.tscn").instantiate()
	custom_score.score = 7
	custom_item.add_child(custom_score)
	grinder.grind(custom_item)
	await _drain_rewards()
	check(Blackboard.read_data("score") == 18, "A child score component must override the default amount.")
	var component_only := _make_body(world)
	var ignored_score := score_object.new()
	ignored_score.score = 99
	component_only.add_child(ignored_score)
	grinder.grind(component_only)
	check(component_only.is_queued_for_deletion() and Blackboard.read_data("score") == 18, "A score component alone must not award points without the score group.")
	var wrapper := Node3D.new()
	wrapper.add_to_group("grindable")
	wrapper.add_to_group("score")
	world.add_child(wrapper)
	var first := _make_body(wrapper)
	var second := _make_body(wrapper, Vector3(22, 0, 0))
	var wrapper_score := score_object.new()
	wrapper_score.score = 4
	wrapper.add_child(wrapper_score)
	grinder.grind(first)
	check(wrapper.is_queued_for_deletion(), "Grinding a physics child must destroy its marked wrapper and all children.")
	check(not grinder.grind(second), "Multiple colliders belonging to an item must enqueue its score exactly once.")
	await _drain_rewards()
	check(Blackboard.read_data("score") == 22, "Wrapper rewards must all be awarded.")
	var imported: packed_buildable = load("res://Scenes/Building/packed_light.tscn").instantiate()
	imported.position = Vector3(25, 0, 0)
	imported.add_to_group("score")
	world.add_child(imported)
	var imported_collider: StaticBody3D = imported.find_child("StaticBody3D", true, false)
	check(is_instance_valid(imported_collider), "Imported crate fixture must contain its nested static collider.")
	if is_instance_valid(imported_collider):
		check(grinder.grind(imported_collider), "Nested imported colliders must resolve to their enclosing rigid item.")
		check(imported.is_queued_for_deletion(), "Imported crates must be destroyed as one complete item.")
		await _drain_rewards()
		check(Blackboard.read_data("score") == 23, "Imported crates must be scored as one complete item.")
	var scenery := StaticBody3D.new()
	world.add_child(scenery)
	var player := CharacterBody3D.new()
	world.add_child(player)
	check(not grinder.grind(scenery) and not grinder.grind(player), "Static scenery and characters must not be treated as dropped items.")
	check(not scenery.is_queued_for_deletion() and not player.is_queued_for_deletion(), "The grinder must preserve level geometry and the player.")
	# A scoring wrapper works without separately adding the grindable group.
	var scoring_wrapper := Node3D.new()
	scoring_wrapper.add_to_group("score")
	world.add_child(scoring_wrapper)
	var wrapped_body := _make_body(scoring_wrapper)
	var nested_component := score_object.new()
	nested_component.score = 0
	wrapped_body.add_child(nested_component)
	grinder.grind(wrapped_body)
	check(scoring_wrapper.is_queued_for_deletion() and Blackboard.read_data("score") == 23, "Scoring wrappers and nested zero-value components must be respected.")
	await _tick()
	check(not is_instance_valid(wrapper) and not is_instance_valid(first) and not is_instance_valid(second), "Wrapper deletion must free all physics children, leaving no orphan manager.")
	# Test actual Area3D body_entered delivery by moving an item into the volume.
	var entering := _make_body(world, Vector3(4, 0, 0))
	entering.add_to_group("score")
	await _tick()
	entering.global_position = Vector3.ZERO
	for i in 4:
		await _tick()
	check(not is_instance_valid(entering), "Entering the monitored area must destroy an item through the signal connection.")
	await _drain_rewards()
	check(Blackboard.read_data("score") == 24, "Actual area entry must increase the Blackboard score.")
	# Check wiring and wrapper configuration in the authored scenes.
	var level: Node = load("res://Scenes/testing_level.tscn").instantiate()
	check(level.get_node("grinding_area") is grinding_area, "The existing testing-level grinding area must use the new script.")
	level.free()
	var prop: Node = load("res://Scenes/test_object.tscn").instantiate()
	check(prop.is_in_group("grindable"), "Test props must be marked so their manager wrapper is removed with the rigid body.")
	prop.free()
	for player_audio in pool.active.duplicate():
		player_audio.playback_finished.emit()
	Blackboard.remove_data("audio_pool")
	pool.queue_free()
	world.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	print("Grinding system integration checks passed." if failures.is_empty() else "Grinding failures: " + str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)


func _drain_rewards() -> void:
	while ScoreRewards.pending_points > 0:
		await get_tree().process_frame
