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

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func body(parent: Node, point: Vector3) -> RigidBody3D:
	var rigid := RigidBody3D.new()
	rigid.gravity_scale = 0
	rigid.position = point
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * .25
	shape.shape = box
	rigid.add_child(shape)
	parent.add_child(rigid)
	return rigid

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var pool := SilentPool.new()
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	GrindCombo.reset()
	GrindCombo.set_process(false)
	ScoreRewards.reset()
	ScoreRewards.set_process(false)
	Blackboard.store_data("score", 10)
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var grinder := grinding_area.new()
	grinder.collision_layer = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 2
	shape.shape = box
	grinder.add_child(shape)
	world.add_child(grinder)
	var unmarked: RigidBody3D = body(world, Vector3(20, 0, 0))
	check(grinder.grind(unmarked) and GrindCombo.item_count == 1 and GrindCombo.base_points == 0, "Unscored destroyed items advance the chain without base score.")
	var scored: RigidBody3D = body(world, Vector3(20, 0, 0))
	scored.add_to_group("score")
	check(grinder.grind(scored) and GrindCombo.base_points == 1, "A score-group item defaults to one point.")
	check(not grinder.grind(scored) and GrindCombo.item_count == 2, "Repeated callbacks cannot count the same item twice.")
	var wrapper := Node3D.new()
	wrapper.add_to_group("grindable")
	wrapper.add_to_group("score")
	world.add_child(wrapper)
	var first: RigidBody3D = body(wrapper, Vector3(20, 0, 0))
	var second: RigidBody3D = body(wrapper, Vector3(22, 0, 0))
	var value := score_object.new()
	value.score = 9
	wrapper.add_child(value)
	check(grinder.grind(first) and wrapper.is_queued_for_deletion() and not grinder.grind(second), "Scored wrappers are destroyed and counted once across colliders.")
	check(Blackboard.read_data("score") == 10 and GrindCombo.base_points == 10, "Grinding defers all points until combo expiry.")
	GrindCombo.finish_combo()
	while ScoreRewards.pending_points > 0:
		ScoreRewards._process(1.0)
	check(Blackboard.read_data("score") == 30, "Three-item chain banks ten base points at 2.0x together.")
	for scene in ["fan", "steel_plate", "basket"]:
		var tool: RigidBody3D = load("res://Scenes/Actors/%s.tscn" % scene).instantiate()
		tool.position = Vector3(30, 0, 0)
		world.add_child(tool)
		check(not grinder.grind(tool) and not tool.is_queued_for_deletion(), "Reusable prop cannot be ground: " + scene)
	var scenery := StaticBody3D.new()
	world.add_child(scenery)
	var player := CharacterBody3D.new()
	world.add_child(player)
	check(not grinder.grind(scenery) and not grinder.grind(player), "Grinder preserves static geometry and characters.")
	var entering: RigidBody3D = body(world, Vector3(4, 0, 0))
	entering.add_to_group("score")
	await get_tree().physics_frame
	await get_tree().process_frame
	entering.global_position = Vector3.ZERO
	for i in 5:
		await get_tree().physics_frame
		await get_tree().process_frame
	check(not is_instance_valid(entering) and GrindCombo.item_count == 1, "Actual Area entry destroys an item and starts a fresh chain.")
	GrindCombo.finish_combo()
	while ScoreRewards.pending_points > 0:
		ScoreRewards._process(1.0)
	check(Blackboard.read_data("score") == 31, "Fresh one-point chain pays once.")
	GrindCombo.set_process(true)
	world.queue_free()
	await get_tree().process_frame
	print("Grinding integration: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
