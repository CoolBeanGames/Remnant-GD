extends Node
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	var pool := object_pool.new()
	pool.pooled_scene = load("res://Scenes/audio_player.tscn")
	pool.reset_method = &"reset"
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	var stage: Node3D = load("res://Scenes/model_instances/game_stage_base.tscn").instantiate()
	add_child(stage)
	var drops: Array[RigidBody3D] = []
	for point in [Vector3(-5, 8, 0), Vector3(5, 8, 0), Vector3(0, 8, -6), Vector3(0, 8, 6)]:
		var drop: RigidBody3D = load("res://Scenes/Actors/note_drop.tscn").instantiate()
		stage.add_child(drop)
		drop.global_position = point
		drop.linear_velocity = Vector3.DOWN * 40
		drops.append(drop)
	await get_tree().create_timer(2.0).timeout
	for drop in drops:
		check(drop.global_position.y > .02 and drop.global_position.y < .3, "Fast note lands above floor in each of four floor sections")
	var exclude: Array[RID] = []
	var floor_body: StaticBody3D = stage.get_node("SolidFloor")
	for collider in stage.find_children("*", "CollisionObject3D", true, false):
		if collider != floor_body:
			exclude.append(collider.get_rid())
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 2, 0), Vector3(0, -2, 0), 1)
	query.exclude = exclude
	check(stage.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "Solid floor preserves original grinder opening")
	stage.queue_free()
	await get_tree().process_frame
	print("Thick floor / fast notes / grinder opening: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
