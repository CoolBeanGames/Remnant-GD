extends Node

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick(count: int = 2) -> void:
	for _i in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	SaveGame.enabled = false
	SaveGame.save_path = "res://.godot/approved_upgrades_test.save"
	Progression.entries.clear()
	Progression.levels.clear()
	Progression.restored_levels = true
	Blackboard.store_data("score", 100000)
	Blackboard.store_data("spawned_items", [])
	Progression.register_catalog(load("res://Data/Computer/default_catalog.tres"))
	var world := Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(player)
	WorldState.begin(world, player)
	await tick()
	var delivery := Marker3D.new()
	delivery.position = Vector3(10, 8, 10)
	world.add_child(delivery)
	var old_fan: Node3D = load("res://Scenes/Actors/fan.tscn").instantiate()
	world.add_child(old_fan)
	check(not Progression.entries.has(&"buy_upgraded_fan") and not Progression.entries.has(&"buy_upgraded_steel_plate"), "Air fan/plate are removed from store stock")
	for id in [&"buy_fan", &"buy_steel_plate", &"buy_push_broom", &"buy_light"]:
		check(Progression.purchase(Progression.entries[id], world, delivery, player).is_empty(), "Buy starter tool before upgrading: " + str(id))
	var count: int = world.get_child_count()
	for id in [&"fan_air_placement", &"plate_air_placement", &"vacuum_head", &"fan_swivel", &"broom_side_skirt", &"light_beam_hood", &"light_coloured_lens"]:
		var entry: computer_entry = Progression.entries[id]
		var before: int = Progression.score()
		check(entry.tab == computer_entry.Tab.MECHANICS and entry.max_level == 1, "%s is a one-time mechanics upgrade" % id)
		check(Progression.purchase(entry, world, delivery, player).is_empty(), "Buy %s" % id)
		check(Progression.score() == before - entry.base_cost and world.get_child_count() == count, "Upgrade spends score without delivering a separate item")
		check(Progression.purchase(entry, world, delivery, player) == "Upgrade complete.", "Cannot buy completed upgrade again")
	check(Progression.entries[&"fan_air_placement"].base_cost == 600 and Progression.entries[&"plate_air_placement"].base_cost == 450, "Air upgrades cost substantially more than retired separate props")
	check(not old_fan.air_placeable and not old_fan.vacuum_enabled and not old_fan.swivel_enabled, "Existing fan keeps its purchased mechanics snapshot")
	check(Progression.purchase(Progression.entries[&"buy_fan"], world, delivery, player).is_empty(), "Buy normal fan after upgrades")
	var fan: Node3D = world.get_child(world.get_child_count() - 1)
	check(fan.air_placeable and fan.vacuum_enabled and fan.swivel_enabled, "Normal future fan gets purchased upgrades")
	check(fan.get_carry_prompts().entries.any(func(entry: prompt_entry) -> bool: return entry.action == &"place_in_air"), "Air capability adds a live V prompt to base fan")
	fan.place_on(null)
	Progression.purchase(Progression.entries[&"buy_steel_plate"], world, delivery, player)
	var plate: rotatable_item = world.get_child(world.get_child_count() - 1)
	check(plate.air_placeable, "Base future plate supports both ghost placement and air locking")
	plate.place_on(null)
	Progression.purchase(Progression.entries[&"buy_push_broom"], world, delivery, player)
	var broom: Node3D = world.get_child(world.get_child_count() - 1)
	check(broom.side_skirt_enabled, "Normal broom receives side-skirt upgrade")
	Progression.purchase(Progression.entries[&"buy_light"], world, delivery, player)
	var light: Node3D = world.get_child(world.get_child_count() - 1)
	check(light.beam_hood_enabled and light.coloured_lens_enabled and light.beam is SpotLight3D, "Future light gets real directional illumination and lens choices")
	check(light.beam.visible and not light.get_node("OmniLight3D").visible, "Hood directs illumination instead of adding a second omnidirectional source")
	light.cycle_lens()
	var colour: Color = light.beam.light_color
	check(light.lens_index == 1 and colour.is_equal_approx(light.LENS_COLOURS[1]), "Lens changes emitted light colour")
	light.set_powered(false)
	check(not light.beam.visible, "Existing E power toggle affects upgraded beam")
	light.place_on(fan)
	WorldState.capture()
	var records: Array = Blackboard.read_data("spawned_items").duplicate(true)
	var fan_id: String = fan.get_meta("persistent_item_id")
	var light_id: String = light.get_meta("persistent_item_id")
	check(SaveGame.save_now(), "Upgrade snapshots and custom states serialize through full disk save")
	for record in records:
		var actor: Node3D = WorldState._actor(record.id)
		if actor != null:
			actor.queue_free()
	await tick()
	WorldState.items.clear()
	WorldState.body_cache.clear()
	check(SaveGame.load_now(), "Reload saved upgrade run")
	WorldState._restore(Blackboard.read_data("spawned_items"))
	var restored_fan: Node3D = WorldState._actor(fan_id)
	var restored_light: Node3D = WorldState._actor(light_id)
	check(restored_fan != null and restored_fan.air_placeable and restored_fan.vacuum_enabled and restored_fan.swivel_enabled and restored_fan.placed, "Saved base fan retains all upgraded capabilities and air support")
	check(restored_light != null and restored_light.lens_index == 1 and not restored_light.powered and restored_light.support.get_ref() == restored_fan, "Saved light retains lens, power and attachment")
	check(restored_light.beam.light_color.is_equal_approx(colour), "Reload applies saved lens to real light")
	var portal_light: Node3D = load("res://Scenes/Actors/light.tscn").instantiate()
	portal_light.beam_hood_enabled = true
	portal_light.coloured_lens_enabled = true
	portal_space.apply_actor(portal_light, true)
	world.add_child(portal_light)
	check(portal_light.beam.light_cull_mask == portal_space.ROOM_LAYER, "Light created inside portal illuminates that space")
	portal_space.apply_actor(portal_light, false)
	check(portal_light.beam.light_cull_mask & 1 != 0 and portal_light.beam.light_cull_mask & portal_space.ROOM_LAYER == 0, "Returning portal-created hood restores workshop illumination")
	WorldState.tracking = false
	world.queue_free()
	await tick()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.save_path))
	print("Approved upgrades / unified props / lighting / disk restoration: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
