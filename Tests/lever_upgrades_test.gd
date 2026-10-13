extends Node
var failures: Array[String] = []
var pulls: int = 0
var first_pending: int = -1
var first_items: int = -1
func _ready() -> void:
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func tick(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame
func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("upgrade_levels",{})
	Blackboard.store_data("score",100000)
	Blackboard.store_data("manual_spawn_queue",0)
	Blackboard.store_data("spawned_items",[])
	var world := Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root",world)
	var player := CharacterBody3D.new()
	player.add_child(Camera3D.new())
	world.add_child(player)
	WorldState.begin(world,player)
	await tick()
	var chute := ceiling_chute.new()
	chute.notes_catalog = null
	chute.note_drop_chance = 0
	chute.item_pool = item_spawn_pool.new()
	chute.item_pool.items = [load("res://Scenes/test_object.tscn")]
	chute.batch_spawn_spacing = .10
	var marker := Marker3D.new()
	chute.add_child(marker)
	chute.spawn_point = marker
	world.add_child(chute)
	marker.global_position = Vector3(0,12,0)
	var handle: lever = load("res://Scenes/Actors/lever_assembly.tscn").instantiate()
	handle.chute = chute
	handle.pull_sound = null
	handle.reset_sound = null
	world.add_child(handle)
	handle.pulled.connect(func() -> void:
		pulls += 1
		first_pending = chute.queued_spawns
		first_items = WorldState.items.size())
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	var speed: computer_entry = Progression.entries[&"lever_cooldown"]
	var output: computer_entry = Progression.entries[&"lever_output"]
	check(Progression.purchase(speed,world,marker,player).is_empty() and is_equal_approx(handle.anim.speed_scale,1.25), "Cooldown purchase immediately speeds the real pull/reset animation")
	check(Progression.purchase(output,world,marker,player).is_empty() and handle.items_per_pull == 2, "Output purchase immediately adds one drop per manual pull")
	handle.refresh_upgrade()
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	check(handle.items_per_pull == 2 and is_equal_approx(handle.cycle_time_multiplier,.8), "Refresh/catalog registration never compounds existing upgrade baselines")
	var began: int = Time.get_ticks_msec()
	handle.interact()
	handle.interact()
	await tick(14)
	check(pulls == 1 and first_pending == 1 and first_items == 1, "Successful pull counts once and starts only its first individual drop")
	await tick(7)
	check(WorldState.items.size() == 2 and chute.queued_spawns == 0 and Blackboard.read_data("manual_spawn_queue") == 0, "Remaining upgraded drop is emitted later and clears the saved queue")
	var last_deadline: int = Time.get_ticks_msec()+2000
	while handle.state != 0 and Time.get_ticks_msec() < last_deadline:
		await tick(1)
	var duration: float = (Time.get_ticks_msec()-began)/1000.0
	check(duration > .8 and duration < 1.2, "Actual animation cycle is shortened from 1.28 seconds to about 1.024")
	for i in 4:
		Progression.purchase(speed,world,marker,player)
		Progression.purchase(output,world,marker,player)
	check(handle.items_per_pull == 6 and is_equal_approx(handle.cycle_time_multiplier,pow(.8,5)), "Five editable tiers yield six drops and 20% shorter animations per tier")
	var score: int = Progression.score()
	check(Progression.purchase(output,world,marker,player) == "Upgrade complete." and Progression.score() == score, "Completed output tier rejects additional spending")
	# Restored tiers bind to a fresh live lever, and a pending queue survives reload.
	var tiers: Dictionary = Blackboard.read_data("upgrade_levels").duplicate(true)
	Progression.levels.clear()
	Progression.entries.clear()
	Progression.restored_levels = false
	Blackboard.store_data("upgrade_levels",tiers)
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	check(handle.items_per_pull == 6, "Saved lever tiers reapply from their original baseline")
	chute.spawn_batch(3)
	chute.set_process(false)
	chute.set_physics_process(false)
	var queued: int = chute.queued_spawns
	var restored := ceiling_chute.new()
	restored.enabled = false
	world.add_child(restored)
	check(queued == 2 and restored.queued_spawns == queued, "An unfinished batch restores its remaining count without replaying emitted items")
	WorldState.tracking = false
	world.queue_free()
	await tick()
	print("Lever upgrades / real animation / staggered random output / prices / persistence: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
