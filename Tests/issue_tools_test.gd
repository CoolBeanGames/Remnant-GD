extends Node3D

var failures: Array[String] = []
var checks: int = 0
var capture_directory: String = ""

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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_directory = arg.trim_prefix("--capture=")
	if DisplayServer.get_name() != "headless":
		get_tree().root.mode = Window.MODE_WINDOWED
		get_tree().root.size = Vector2i(1280, 720)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	run.call_deferred()

func capture(view_name: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await tick()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory + "/" + view_name + ".png") == OK, "Actual rendered control view saved")

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.save_path = "user://issue_tools.save"
	SaveGame.profile = {"mulch_coins": 1000, "mulch_upgrades": {}, "settings": {}}
	Blackboard._data.clear()
	Flags._flags.clear()
	Progression.entries.clear()
	Progression.levels.clear()
	Progression.restored_levels = false
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("score", 100000)
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	WorldState.begin(self, player)
	await tick()
	if not capture_directory.is_empty():
		var surface := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(30, 30)
		surface.mesh = plane
		add_child(surface)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-60, -30, 0)
		add_child(fill)
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var fan: RigidBody3D = load("res://Scenes/Actors/fan.tscn").instantiate()
	fan.swivel_enabled = true
	fan.vacuum_enabled = true
	fan.freeze = true
	fan.position = Vector3(.2, 0, -2)
	add_child(fan)
	pickup.held_object = fan
	fan.held = true
	var display: prompt_display = load("res://Scenes/UI/world_prompts.tscn").instantiate()
	display.camera = player.get_node("Camera3D")
	display.pickup = pickup
	add_child(display)
	var base_count: int = fan.carry_prompts.entries.size()
	for i in 240:
		display.refresh()
	check(display.labels.size() == base_count + 4, "Repeated held-fan HUD refresh stays bounded, including power and axis")
	check(fan.carry_prompts.entries.size() == base_count, "Fan controls never mutate the reusable carry Resource")
	check(display.displayed_texts.count("Sweep [J]") == 1, "Exactly one Sweep prompt is shown")
	await capture("fan_controls")
	var second: RigidBody3D = load("res://Scenes/Actors/fan.tscn").instantiate()
	second.position = Vector3(20, 0, 20)
	add_child(second)
	check(second.get_carry_prompts().entries.size() == base_count, "Unupgraded fan does not inherit another fan's attachment prompts")
	pickup.held_object = null
	var light: Node3D = load("res://Scenes/Actors/light.tscn").instantiate()
	Progression.levels[&"buy_light"] = 1
	Progression.levels[&"light_beam_hood"] = 1
	Progression.levels[&"light_coloured_lens"] = 1
	Progression.apply_new_prop(light, "light")
	light.freeze = true
	light.position = Vector3(0, .9, -1.8)
	add_child(light)
	light.held = true
	var other_light: Node3D = load("res://Scenes/Actors/light.tscn").instantiate()
	other_light.beam_hood_enabled = true
	other_light.freeze = true
	other_light.position = Vector3(20, 0, 20)
	add_child(other_light)
	check(light.beam.visible and not light.get_node("OmniLight3D").visible, "Hood starts with directional light")
	pickup.held_object = light
	await capture("light_cone")
	var toggle := InputEventAction.new()
	toggle.action = &"toggle_light_beam"
	toggle.pressed = true
	light._unhandled_input(toggle)
	check(not light.beam.visible and light.get_node("OmniLight3D").visible and not light.hood.visible, "Cone control restores omnidirectional illumination and removes hood")
	check(other_light.beam.visible and other_light.beam_hood_active, "Cone toggle affects only the held/targeted light")
	await capture("light_omni")
	check(light.get_carry_prompts().entries.any(func(e: prompt_entry) -> bool: return e.get_display_text() == "[K] Cone Light"), "Live prompt shows how to restore the cone")
	pickup.held_object = null
	light.set_powered(false)
	check(not light.beam.visible and not light.get_node("OmniLight3D").visible, "Power switch remains independent of beam selection")
	WorldState.track(light)
	var light_id: String = light.get_meta("persistent_item_id")
	check(SaveGame.save_now(), "Cone choice saves through normal world snapshots")
	light.queue_free()
	await tick()
	WorldState.items.clear()
	check(SaveGame.load_now(), "Saved cone choice reloads from disk")
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	WorldState._restore(Blackboard.read_data("spawned_items"))
	var restored: Node3D = WorldState._actor(light_id)
	check(restored != null and not restored.beam_hood_active and not restored.powered and restored.beam != null, "Reload keeps hood permission, omni choice and power separately")
	var flashlight: SpotLight3D = player.get_node("Camera3D/SpotLight3D")
	flashlight.process_mode = Node.PROCESS_MODE_ALWAYS
	flashlight.set_powered(false)
	await tick()
	check(flashlight.off_hint.visible and flashlight.off_hint.text.contains("[T]"), "Off flashlight has a visible in-world T hint")
	await capture("flashlight_off")
	Blackboard.store_data("flashlight_powered", true)
	await tick()
	check(flashlight.powered and flashlight.visible and not flashlight.off_hint.visible, "Blackboard edit immediately turns the real flashlight back on")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = true
	flashlight._unhandled_input(key)
	check(not flashlight.powered and not flashlight.visible, "T toggles the actual flashlight")
	Blackboard.store_data("player_input_blocked", true)
	flashlight._unhandled_input(key)
	await tick()
	check(not flashlight.powered and not flashlight.off_hint.visible, "Menus block flashlight input and its hint")
	Blackboard.store_data("player_input_blocked", false)
	flashlight.set_powered(true)
	Mulch.bind_level(self)
	Mulch.install()
	Mulch.install_bin()
	Mulch.set_process(false)
	var entry: computer_entry = Progression.entries[&"mulch_auto_repair"]
	var coins: int = Mulch.coins()
	check(Progression.purchase(entry, self, null, player).is_empty() and Mulch.automatic_repair and Mulch.coins() == coins - entry.cost(0), "Terminal purchases the permanent auto-repair upgrade")
	check(Progression.purchase(entry, self, null, player) == "Upgrade complete.", "Auto-repair can only be bought once")
	Mulch.damage = Mulch.maximum_damage
	Blackboard.store_data("score", 0)
	Mulch._process(.01)
	check(Mulch.repair_remaining == 0 and Mulch.broken(), "Unaffordable automatic repair waits without starting or charging")
	var cost: int = Mulch.repair_cost()
	Blackboard.store_data("score", cost + 500)
	Mulch._process(.01)
	check(Progression.score() == 500 and Mulch.repair_remaining > 0, "Adding score starts one normal paid repair automatically")
	if not capture_directory.is_empty():
		var camera: Camera3D = player.get_node("Camera3D")
		camera.fov = 50
		camera.global_position = Mulch.station.global_position + Vector3(0, .7, 2)
		camera.look_at(Mulch.station.global_position + Vector3(0, .5, 0))
		Mulch.station.refresh()
		await capture("automatic_repair")
	Mulch._process(.01)
	check(Progression.score() == 500 and Mulch.repair() == "Repair already in progress.", "Automatic and manual repair cannot double-charge")
	check(SaveGame.save_now() and SaveGame.load_now(), "In-progress automatic repair survives a disk round trip")
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	Mulch.bind_level(self)
	check(Mulch.automatic_repair and Mulch.repair_remaining > 0, "Reload restores permission and the existing repair countdown")
	Mulch._process(Mulch.repair_seconds + .1)
	check(not Mulch.broken() and Mulch.damage == 0 and Mulch.repair_cost() > cost, "Automatic completion restores durability and escalates the next price")
	check(SaveGame.new_game(), "New Game uses existing run/profile reset")
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	Mulch.bind_level(self)
	check(Mulch.automatic_repair and Mulch.upgrade_level(entry.id) == 1 and Mulch.damage == 0, "Permanent auto-repair survives New Game without old damage")
	WorldState.tracking = false
	Mulch.level = null
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.save_path))
	print("Issue tools: ", "PASS" if failures.is_empty() else str(failures), " / ", checks, " checks")
	get_tree().quit(0 if failures.is_empty() else 1)
