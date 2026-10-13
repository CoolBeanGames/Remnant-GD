extends Node

## Repeatable local microbenchmarks, not a claim about whole-game frame rates.
func old_pick(pool: item_spawn_pool) -> PackedScene:
	var choices: Array[PackedScene] = []
	for scene in pool.items:
		if scene != null:
			choices.append(scene)
	return choices.pick_random() if not choices.is_empty() else null

func analytical_bounds(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		return AABB(-shape.size * .5, shape.size)
	return shape.get_debug_mesh().get_aabb()

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	var pool: item_spawn_pool = load("res://Data/Items/default_spawn_pool.tres")
	var shape := BoxShape3D.new()
	shape.size = Vector3(.24, .33, .42)
	var samples: Dictionary = {"pool_old_us": [], "pool_new_us": [], "bounds_old_us": [], "bounds_new_us": []}
	for repeat in 5:
		var start: int = Time.get_ticks_usec()
		for i in 100000:
			old_pick(pool)
		samples.pool_old_us.append(Time.get_ticks_usec() - start)
		start = Time.get_ticks_usec()
		for i in 100000:
			pool.pick_item()
		samples.pool_new_us.append(Time.get_ticks_usec() - start)
		start = Time.get_ticks_usec()
		for i in 100000:
			shape.get_debug_mesh().get_aabb()
		samples.bounds_old_us.append(Time.get_ticks_usec() - start)
		start = Time.get_ticks_usec()
		for i in 100000:
			analytical_bounds(shape)
		samples.bounds_new_us.append(Time.get_ticks_usec() - start)
	var medians: Dictionary = {}
	for key in samples:
		samples[key].sort()
		medians[key] = samples[key][2]
	var result: Dictionary = {"calls_per_sample": 100000, "samples": 5, "medians_us": medians, "engine": Engine.get_version_info().string}
	var file := FileAccess.open("res://.godot/trip_hotpath_benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("Trip hot-path microbenchmarks: ", JSON.stringify(result))
	get_tree().quit()
