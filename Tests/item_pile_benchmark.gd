extends Node3D

## Repeatable actual-item/Jolt workload. Run manually; not a pass/fail FPS promise.
var count: int = 800
var elapsed: float = 0.0
var output: String = "user://item_pile_benchmark.json"
var world_times: Array[float] = []
var physics_times: Array[float] = []
var frame_times: Array[float] = []
var previous_frame: int = 0
var bodies: Array[RigidBody3D] = []
var phase: String = "settled"
var sample_seconds: float = 4.0
var render_primitives: float = 0.0
var gpu_times: Array[float] = []
var lod: float = 1.0
var contacts: int = 10
var workshop: bool = false
var measure_fan: bool = false
var fan_node: RigidBody3D
var wind_times: Array[float] = []

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--count="): count = int(arg.get_slice("=", 1))
		elif arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		elif arg.begins_with("--phase="): phase = arg.get_slice("=", 1)
		elif arg.begins_with("--lod="): lod = float(arg.get_slice("=", 1))
		elif arg.begins_with("--contacts="): contacts = int(arg.get_slice("=", 1))
		elif arg == "--workshop": workshop = true
		elif arg == "--fan": measure_fan = true
	Engine.max_fps = 0
	get_viewport().mesh_lod_threshold = lod
	if DisplayServer.get_name() != "headless":
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	if DisplayServer.get_name() != "headless":
		get_tree().root.mode = Window.MODE_WINDOWED
		get_tree().root.size = Vector2i(1280, 720)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("spawned_items", [])
	var player := CharacterBody3D.new()
	add_child(player)
	WorldState.begin(self, player)
	WorldState.set_physics_process(false)
	var item_parent: Node3D = self
	var offset := Vector3.ZERO
	if workshop:
		for flag_name in ["exited room", "level enabled", "grinder enabled", "computer enabled"]:
			Flags.set_flag(flag_name, true)
		var audio_pool := object_pool.new()
		audio_pool.pooled_scene = load("res://Scenes/audio_player.tscn")
		audio_pool.reset_method = &"reset"
		audio_pool.register_with_blackboard = true
		audio_pool.blackboard_name = &"audio_pool"
		add_child(audio_pool)
		var stage: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
		stage.spawn_animation_enabled = false
		add_child(stage)
		# Keep the requested workload intact while retaining the staged lighting.
		stage.grinder.set_enabled(false)
		stage.player.process_mode = Node.PROCESS_MODE_DISABLED
		item_parent = stage
		offset = Vector3(5, 0, -1)
		AudioServer.set_bus_mute(0, true)
		WorldState.set_physics_process(false)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30, 1, 30)
	collision.shape = floor_shape
	floor_body.position.y = -.5
	floor_body.add_child(collision)
	add_child(floor_body)
	for side in [Vector3(15, 2, 0), Vector3(-15, 2, 0), Vector3(0, 2, 15), Vector3(0, 2, -15)]:
		var wall := StaticBody3D.new()
		var wall_collision := CollisionShape3D.new()
		var wall_shape := BoxShape3D.new()
		wall_shape.size = Vector3(1, 5, 30) if side.x != 0 else Vector3(30, 5, 1)
		wall_collision.shape = wall_shape
		wall.position = side
		wall.add_child(wall_collision)
		add_child(wall)
	var camera := Camera3D.new()
	camera.position = Vector3(11, 10, 13)
	add_child(camera)
	camera.position += offset
	camera.look_at(offset)
	camera.make_current()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -35, 0)
	add_child(light)
	var pool: item_spawn_pool = load("res://Data/Items/default_spawn_pool.tres")
	seed(81013)
	for index in count:
		var scene: PackedScene = pool.items[index % pool.items.size()]
		var pose := Transform3D(Basis.IDENTITY, Vector3((index % 20) * .48 - 4.8, .3 + floorf(float(index) / 400) * .7, (floori(float(index) / 20) % 20) * .48 - 4.8))
		pose.origin += offset
		var actor: Node3D = WorldState.spawn_item(scene, item_parent, pose)
		var body: RigidBody3D = actor.get_node("RigidBody3D") as RigidBody3D
		body.linear_damp = 2.0
		body.max_contacts_reported = contacts
		body.angular_damp = 2.0
		bodies.append(body)
	WorldState.tracking = true
	if measure_fan:
		fan_node = load("res://Scenes/Actors/fan.tscn").instantiate()
		fan_node.freeze = true
		fan_node.maximum_speed = -10000.0
		var wind_shape := BoxShape3D.new()
		wind_shape.size = Vector3(22, 22, 22)
		fan_node.get_node("Wind/Shape").shape = wind_shape
		item_parent.add_child(fan_node)
		fan_node.global_position = offset
		fan_node.set_physics_process(false)
	previous_frame = Time.get_ticks_usec()
	print("Pile benchmark warmup / ", count, " items / ", phase)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if phase == "moving":
		for body in bodies:
			if is_instance_valid(body):
				if body.sleeping: body.sleeping = false
				body.apply_central_force(Vector3(sin(elapsed * 2.0) * .5, 0, cos(elapsed) * .5))
	var start: int = Time.get_ticks_usec()
	WorldState._physics_process(delta)
	if elapsed >= 5.0:
		world_times.append((Time.get_ticks_usec() - start) / 1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if measure_fan:
		start = Time.get_ticks_usec()
		fan_node._physics_process(delta)
		if elapsed >= 5.0: wind_times.append((Time.get_ticks_usec() - start) / 1000.0)
	if elapsed >= 5.0 + sample_seconds:
		finish()

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	if elapsed >= 5.0:
		frame_times.append((now - previous_frame) / 1000.0)
		if DisplayServer.get_name() != "headless":
			gpu_times.append(RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()))
			render_primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	previous_frame = now

func stats(samples: Array[float]) -> Dictionary:
	if samples.is_empty(): return {}
	samples.sort()
	var total: float = 0
	for sample in samples: total += sample
	return {"mean_ms": total / samples.size(), "median_ms": samples[samples.size() >> 1], "p95_ms": samples[mini(samples.size() - 1, floori(samples.size() * .95))], "max_ms": samples.back(), "samples": samples.size()}

func finish() -> void:
	set_physics_process(false)
	set_process(false)
	var active: int = 0
	var live: int = 0
	for body in bodies:
		if is_instance_valid(body):
			live += 1
			if not body.sleeping: active += 1
	var result: Dictionary = {"count": count, "phase": phase, "lod_threshold": lod, "renderer": RenderingServer.get_current_rendering_method(), "headless": DisplayServer.get_name() == "headless", "world_state": stats(world_times), "physics_frame": stats(physics_times), "frame": stats(frame_times), "gpu": stats(gpu_times), "active_bodies": active, "physics_nodes": find_children("*", "PhysicsBody3D", true, false).size(), "render_primitives": render_primitives, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	var file := FileAccess.open(output, FileAccess.WRITE)
	result.reported_contacts_per_item = contacts
	result.live_items = live
	result.workshop = workshop
	result.fan_scan = stats(wind_times)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("Pile benchmark: ", JSON.stringify(result))
	if DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png(output.get_basename() + ".png")
	WorldState.tracking = false
	if live != count:
		push_error("Benchmark lost items; this is not a valid fixed-count workload")
	get_tree().quit(0 if live == count else 1)
