extends Node

class CountingWorld extends "res://Global/world_state.gd":
	var captures: int = 0
	func capture() -> void:
		captures += 1
		super.capture()

var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void:
	run.call_deferred()
func tick() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func avatar(world: Node3D) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	body.add_child(camera)
	world.add_child(body)
	return body

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard._data.clear()
	var tracker := CountingWorld.new()
	add_child(tracker)
	tracker.set_physics_process(false)
	var old_world := Node3D.new()
	var world := Node3D.new()
	add_child(old_world)
	add_child(world)
	# Two scene transitions before the deferred restoration may execute.
	Blackboard.store_data("spawned_items", [{"id": "old-run", "scene": "res://Tests/Fixtures/spawn_pool_item.tscn", "transform": Transform3D.IDENTITY}])
	tracker.begin(old_world, avatar(old_world))
	Blackboard.store_data("spawned_items", [])
	tracker.begin(world, avatar(world))
	await tick()
	check(tracker.tracking and tracker.items.is_empty(), "Stale deferred restore cannot add old-run items to a new level")
	check(tracker.captures == 1, "Only the current session completes restoration")

	var scene: PackedScene = load("res://Tests/Fixtures/spawn_pool_item.tscn")
	var actors: Array[Node3D] = []
	var previous_captures: int = tracker.captures
	for index in 30:
		var actor: Node3D = tracker.spawn_item(scene, world, Transform3D(Basis.IDENTITY, Vector3(index * 2, 5, 10)))
		actors.append(actor)
		for body in tracker._bodies(actor):
			body.freeze = true
	check(tracker.captures == previous_captures and tracker.items.size() == 30, "Burst spawn updates registry without rebuilding every snapshot")
	await tick()
	check(tracker.captures == previous_captures + 1 and Blackboard.read_data("spawned_items").size() == 30, "Burst spawn produces one complete deferred snapshot")
	previous_captures = tracker.captures
	for index in 10:
		tracker.untrack(actors[index])
		actors[index].queue_free()
	tracker.capture()
	check(Blackboard.read_data("spawned_items").size() == 20, "Forced capture immediately includes same-frame removals")
	await tick()
	check(tracker.captures == previous_captures + 1, "Forced save cancels the redundant pending snapshot")

	var survivor: Node3D = actors[10]
	var extra := RigidBody3D.new()
	extra.freeze = true
	survivor.add_child(extra)
	tracker.capture()
	check(tracker._bodies(survivor).has(extra), "Periodic snapshot refresh includes runtime-added rigid bodies")
	extra.reparent(world)
	check(not tracker._bodies(survivor).has(extra), "Cached body lookup ignores detached bodies immediately")
	extra.free()
	for body in tracker._bodies(survivor):
		body.global_position.y = -20
	tracker._physics_process(0)
	check(survivor.is_queued_for_deletion(), "Cached culling still checks nested rigid-body positions")
	await tick()

	# Journal lookups must neither clone nor expose mutable snapshots to callers.
	Blackboard.store_data("found_notes", [{"id": "one", "body": "original"}])
	var journal: Array[Dictionary] = Notes.all_notes()
	journal[0].body = "changed"
	check(Notes.has_note(&"one") and not Notes.has_note(&"missing") and Notes.all_notes()[0].body == "original", "Cheap journal existence checks preserve defensive snapshot semantics")

	var pickup_player: CharacterBody3D = avatar(world)
	var ray := raycaster.new()
	pickup_player.add_child(ray)
	var marker := Marker3D.new()
	pickup_player.add_child(marker)
	var pickup := player_pickup.new()
	pickup.ray = ray
	pickup.hold_position = marker
	pickup.player_body = pickup_player
	pickup_player.add_child(pickup)
	var carried := RigidBody3D.new()
	var visual := MeshInstance3D.new()
	visual.mesh = BoxMesh.new()
	visual.transparency = .2
	carried.add_child(visual)
	world.add_child(carried)
	check(pickup.pickup_object(carried) and carried.freeze and carried.collision_layer == 0, "Player removal regression begins with an ordinary held item")
	pickup_player.queue_free()
	await tick()
	check(not carried.freeze and carried.collision_layer == 1 and is_equal_approx(visual.transparency, .2) and not carried.has_meta("carried_by_player"), "Player teardown restores surviving held item's physics and visuals")
	var bin: mulch_bin = load("res://Scenes/Mulch/mulch_bin.tscn").instantiate()
	portal_space.apply_actor(bin, true)
	world.add_child(bin)
	bin._physics_process(0)
	check(bin.get_node("Deposit").collision_mask == portal_space.ROOM_LAYER, "Mulch bin senses pellets in the current portal physics space")
	bin.get_node("Deposit").collision_mask = 0
	bin.collision_layer = 0
	bin._physics_process(0)
	check(bin.get_node("Deposit").collision_mask == portal_space.ROOM_LAYER and bin.collision_layer == 0, "Held bin retains room sensing without re-enabling solid collisions")
	portal_space.apply_actor(bin, false)
	bin._physics_process(0)
	check(bin.get_node("Deposit").collision_mask == 1, "Returning bin restores workshop pellet sensing")
	check(bin.get_look_prompts() == bin.get_look_prompts(), "Stable mulch prompts reuse the same resource")

	benchmark(tracker)
	world.queue_free()
	old_world.queue_free()
	tracker.queue_free()
	await tick()
	print("Gameplay snapshots, cache lifetime and journal review: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)

func benchmark(tracker: CountingWorld) -> void:
	var actors: Array[Node3D] = []
	for index in 200:
		var actor := Node3D.new()
		var parent: Node = actor
		for depth in 20:
			var child := Node3D.new()
			parent.add_child(child)
			parent = child
			if depth in [7, 19]:
				var body := RigidBody3D.new()
				body.freeze = true
				parent.add_child(body)
		actors.append(actor)
		tracker._bodies(actor)
	var before_times: Array[int] = []
	var after_times: Array[int] = []
	for sample in 7:
		var start: int = Time.get_ticks_usec()
		for repetition in 20:
			for actor in actors:
				actor.find_children("*", "RigidBody3D", true, false)
		before_times.append(Time.get_ticks_usec() - start)
		start = Time.get_ticks_usec()
		for repetition in 20:
			for actor in actors:
				tracker._body_references(actor)
		after_times.append(Time.get_ticks_usec() - start)
	before_times.sort()
	after_times.sort()
	print("Body discovery benchmark / 200 actors, 20 nested nodes, 20 ticks / median legacy=%d us cached=%d us / %.2fx" % [before_times[3], after_times[3], float(before_times[3]) / maxf(1, after_times[3])])
	for actor in actors:
		actor.free()
