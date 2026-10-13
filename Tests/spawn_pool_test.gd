extends Node
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func run() -> void:
	seed(2468)
	Blackboard.store_data("found_notes", [])
	Blackboard.store_data("spawned_notes", [])
	Blackboard.store_data("spawned_items", [])
	var world := Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(player)
	WorldState.begin(world, player)
	await get_tree().process_frame
	var pool := item_spawn_pool.new()
	pool.items = [load("res://Scenes/test_object.tscn"), null, load("res://Tests/Fixtures/spawn_pool_item.tscn")]
	var chute := ceiling_chute.new()
	chute.item_pool = pool
	chute.note_drop_chance = 1.0
	var point := Marker3D.new()
	point.position = Vector3(10, 4, 10)
	chute.add_child(point)
	chute.spawn_point = point
	world.add_child(chute)
	var ids: Array[String] = []
	for i in 3:
		chute.spawn()
		var drop: note_drop = WorldState._actor(WorldState.items.keys().back()) as note_drop
		check(drop != null, "Unspawned note is selected at 100 percent chance")
		check(not ids.has(str(drop.note.id)), "Each note spawns once even before being picked up")
		ids.append(str(drop.note.id))
		drop.freeze = true
	check(Notes.all_notes().is_empty() and Blackboard.read_data("spawned_notes").size() == 3, "Spawn history is separate from found journal")
	check(chute.notes_catalog.available().is_empty(), "All spawned notes leave the pool")
	var variants: Dictionary = {}
	for i in 32:
		chute.spawn()
		var actor: Node3D = WorldState._actor(WorldState.items.keys().back())
		check(not actor is note_drop, "Exhausted note catalog always falls back to regular item")
		variants[actor.scene_file_path] = true
		check(physics_items.score_component(actor).score == 1, "Every pool item gets normal scoring behavior")
		physics_items.rigid_body(actor.get_node("RigidBody3D")).freeze = true
	check(variants.size() == 2, "Random spawns can select both configured item scenes")
	var first_id: String = WorldState.items.keys()[0]
	var first_note: note_drop = WorldState._actor(first_id) as note_drop
	first_note.queue_free()
	await get_tree().process_frame
	check(Notes.has_spawned(StringName(ids[0])) and chute.notes_catalog.available().is_empty(), "Deleting a note does not make it spawnable again")
	var empty := item_spawn_pool.new()
	empty.items = [null]
	check(empty.pick_item() == null, "Empty/null pool is safe")
	chute.item_pool = empty
	var before: int = world.get_child_count()
	chute.spawn()
	check(world.get_child_count() == before, "No orphan nodes are created for an empty pool")
	var automatic: automatic_spawner = load("res://Scenes/Actors/automatic_spawner.tscn").instantiate()
	automatic.item_pool = pool
	automatic.required_flag = ""
	world.add_child(automatic)
	automatic.place_on(world)
	automatic.remaining = 0
	automatic._physics_process(.1)
	var output: Node3D = WorldState._actor(WorldState.items.keys().back())
	check(variants.has(output.scene_file_path), "Automatic spawner uses the same item pool")
	Blackboard.store_data("spawned_notes", [])
	Blackboard.store_data("found_notes", [{"id": ids[0], "title": "Old save", "body": "Already found"}])
	check(Notes.has_spawned(StringName(ids[0])), "Older found-note saves suppress duplicates without spawn history")
	world.queue_free()
	await get_tree().process_frame
	print("Unique note drops and random item pools: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
