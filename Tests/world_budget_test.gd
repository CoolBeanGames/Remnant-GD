extends Node3D

var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.save_path = "user://world_budget.save"
	Blackboard._data.clear()
	Blackboard.store_data("spawned_items", [])
	var player := CharacterBody3D.new()
	add_child(player)
	WorldState.begin(self, player)
	WorldState.set_physics_process(false)
	await tick()
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30, 1, 30)
	collision.shape = shape
	floor_body.position.y = -.5
	floor_body.add_child(collision)
	add_child(floor_body)
	var actors: Array[object_manager] = []
	for i in 80:
		var actor: object_manager = WorldState.spawn_item(load("res://Scenes/Items/book.tscn"), self, Transform3D(Basis.IDENTITY, Vector3((i % 10) - 5, 1, floorf(float(i) / 10) - 4))) as object_manager
		actor.rb.linear_damp = 2
		actor.rb.angular_damp = 2
		actors.append(actor)
	await tick(180)
	var sleeping: int = 0
	for actor in actors:
		if actor.rb.sleeping: sleeping += 1
	check(sleeping > 70, "Real dropped books settle naturally on their unchanged Jolt colliders")
	WorldState.capture()
	check(Blackboard.read_data("spawned_items").size() == 80, "Explicit capture contains every item")
	var previous: Array = Blackboard.read_data("spawned_items")
	WorldState.snapshot_items_per_tick = 2
	WorldState.capture_background()
	WorldState._physics_process(1.0 / 60.0)
	check(WorldState._snapshot_cursor == 2 and Blackboard.read_data("spawned_items") == previous, "Background snapshot obeys its item budget and publishes no partial list")
	var moving: object_manager = actors[0]
	var start: Vector3 = moving.rb.global_position
	moving.rb.apply_central_impulse(Vector3(.8, 0, 0))
	await tick(10)
	check(not moving.rb.sleeping and moving.rb.global_position.distance_to(start) > .01, "Sleeping objects still wake and move through real forces")
	moving.rb.linear_velocity = Vector3(.4, .2, 0)
	physics_items.score_component(moving).score = 17
	check(SaveGame.save_now(), "Normal disk save cancels an unfinished background snapshot and captures exact live data")
	var id: String = moving.get_meta("persistent_item_id")
	var saved: Dictionary = {}
	for record in Blackboard.read_data("spawned_items"):
		if record.id == id: saved = record
	check(saved.score == 17 and saved.bodies[0].transform == moving.rb.global_transform and saved.bodies[0].velocity == moving.rb.linear_velocity, "Forced save refreshes even changed values on a cached item")
	check(WorldState._snapshot_ids.is_empty(), "Explicit capture clears the old background generation")
	WorldState.capture_background()
	var removed_id: String = actors[1].get_meta("persistent_item_id")
	WorldState.untrack(actors[1])
	actors[1].queue_free()
	await tick()
	for i in 42:
		WorldState._physics_process(1.0 / 60.0)
	check(Blackboard.read_data("spawned_items").size() == 79 and not WorldState._record_cache.has(removed_id), "Removing an item during batching cannot publish a phantom record")
	for actor in actors:
		if is_instance_valid(actor): actor.rb.global_position.y = -15
	WorldState.cull_checks_per_tick = 4
	WorldState._physics_process(1.0 / 60.0)
	check(WorldState.items.size() >= 75, "Cleanup limits its work rather than scanning the entire pile in one frame")
	var arrivals: Array[Node3D] = []
	for i in 80:
		var arrival: Node3D = WorldState.spawn_item(load("res://Scenes/Items/book.tscn"), self, Transform3D(Basis.IDENTITY, Vector3(20, 10, 20)))
		arrival.rb.freeze = true
		arrivals.append(arrival)
		WorldState._physics_process(1.0 / 60.0)
		await tick(1)
	var survivors: int = 0
	for actor in actors:
		if is_instance_valid(actor): survivors += 1
	check(survivors == 0, "Continuous spawning cannot starve round-robin cleanup of fallen items")
	for arrival in arrivals:
		WorldState.untrack(arrival)
		arrival.queue_free()
	await tick()
	check(WorldState.items.is_empty(), "Removed bodies leave no registry aliases")
	WorldState.capture()
	check(Blackboard.read_data("spawned_items").is_empty(), "Saving an empty world clears stale records")
	WorldState.begin(self, player)
	await tick()
	check(WorldState._record_cache.is_empty() and WorldState._snapshot_ids.is_empty(), "Changing sessions invalidates old record and batching caches")
	WorldState.tracking = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.save_path))
	print("World budget: ", "PASS" if failures.is_empty() else str(failures), " / ", checks, " checks")
	get_tree().quit(0 if failures.is_empty() else 1)
