extends Node

var failures: Array[String] = []
var level: Node3D
var display: prompt_display
var pickup: player_pickup
var building: player_building
var ray: raycaster


func _ready() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func expect_prompts(expected: Array[String], message: String) -> void:
	display.refresh()
	check(display.displayed_texts == expected, message + " Got: " + str(display.displayed_texts))
	check(display.labels.size() == expected.size(), "Label scene count must match the selected prompts.")
	for i in mini(display.labels.size(), expected.size()):
		check(display.labels[i].text == expected[i], "Rendered labels must contain the selected prompt text.")
	check(display.visible == not expected.is_empty(), "An empty prompt list must hide the display.")


func _run() -> void:
	# Use the actual saved level to validate reference wiring and prefab configuration.
	level = load("res://Scenes/testing_level.tscn").instantiate()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("game_stage_base/MachineRun").autoplay = false
	Blackboard.store_data("game_root", level)
	get_tree().root.add_child(level)
	display = level.get_node("Prompt_Container/HBoxContainer")
	pickup = level.get_node("Player/Controllers/Player_Pickup")
	building = level.get_node("Player/Controllers/Player_Building")
	ray = level.get_node("Player/Camera3D/RayCast3D")
	check(display.pickup == pickup and display.building == building and display.ray == ray, "Prompt display references must be wired to the level's player.")
	check(not ray.debug_enabled, "Raycast debugging must be disabled in the player scene.")
	check(pickup.building == building, "Pickup must be wired to placement cancellation.")
	ray._set_looked_at(null)
	expect_prompts([], "Looking at nothing must show no prompts.")
	var lever_body: Node3D = level.get_node("Lever_Assembly/lever_body")
	ray._set_looked_at(lever_body)
	expect_prompts(["Pull Lever [E]"], "Lever prompts must resolve from its collider to its ancestor's component.")
	var first_label: prompt_label = display.labels[0]
	display.refresh()
	check(display.labels[0] == first_label, "Unchanged prompts must reuse their label scene instance.")
	var crate: packed_buildable = level.get_node("PackedLight")
	ray._set_looked_at(crate)
	expect_prompts(["Pickup Light [F]"], "Light crate look-at prompt must use its recipe.")
	var prop: Node3D = load("res://Scenes/test_object.tscn").instantiate()
	prop.get_node("RigidBody3D").disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	level.add_child(prop)
	ray._set_looked_at(prop.get_node("RigidBody3D"))
	expect_prompts(["Pickup Strange Object [F]"], "Strange-object prompt must be configured independently of the physics script.")
	pickup.pickup_object(crate)
	building._sync_package()
	expect_prompts(["[F] Drop", "[RMB] Throw", "[B] Build"], "Carrying prompts must override the looked-at object.")
	check(crate.visible and not building.is_building(), "Carrying prompts must correspond to a visible crate without a ghost.")
	await get_tree().physics_frame
	await get_tree().process_frame
	var prompt_rect: Rect2 = display.get_global_rect()
	check(prompt_rect.position.y >= 0 and prompt_rect.end.y <= display.get_viewport_rect().end.y + 1, "The authored bottom prompt container must keep its labels on screen.")
	Input.action_press("build")
	building._physics_process(0.0)
	Input.action_release("build")
	expect_prompts(["[B] Place", "[F] Cancel"], "Placement must replace carrying prompts immediately.")
	check(not crate.visible and building.is_building(), "Placement prompts must correspond to a hidden crate and active ghost.")
	Input.action_press("throw")
	pickup._process(0.25)
	Input.action_release("throw")
	pickup._process(0.0)
	check(pickup.held_object == crate and not pickup.charging_throw, "RMB must not throw while only Place/Cancel are shown.")
	await get_tree().process_frame
	Input.action_press("pickup")
	await get_tree().process_frame
	Input.action_release("pickup")
	pickup._process(0.0)
	check(pickup.held_object == crate and crate.visible and not building.is_building(), "F Cancel must restore visible carrying without dropping the crate.")
	expect_prompts(["[F] Drop", "[RMB] Throw", "[B] Build"], "Cancellation must restore carrying prompts immediately.")
	await get_tree().process_frame
	Input.action_press("pickup")
	await get_tree().process_frame
	Input.action_release("pickup")
	pickup._process(0.0)
	check(not pickup.is_holding_object(), "F in carrying mode must still drop the crate.")
	expect_prompts(["Pickup Strange Object [F]"], "Dropping must restore the current look-at prompts.")
	pickup.pickup_object(prop.get_node("RigidBody3D"))
	expect_prompts(["[F] Drop", "[RMB] Throw"], "Ordinary objects must show carrying prompts without Build.")
	pickup.drop_object()
	# Runtime configuration and key rebinding should be reflected without new UI code.
	var provider: object_prompts = object_prompts.find_for(lever_body)
	var custom := prompt_set.new()
	var entry := prompt_entry.new()
	entry.text = "Use Custom Machine"
	entry.action = &"confirm"
	custom.entries.append(entry)
	provider.prompts = custom
	# Prompt-only objects are targetable without a pickup/interaction script.
	var prompt_only := StaticBody3D.new()
	var custom_provider := object_prompts.new()
	custom_provider.prompts = custom
	prompt_only.add_child(custom_provider)
	level.add_child(prompt_only)
	check(ray._is_valid_target(prompt_only), "Prompt components must make their owner targetable through the look-prompt group.")
	ray._set_looked_at(prompt_only)
	expect_prompts(["Use Custom Machine [E]"], "Prompt-only objects must support configured look-at text.")
	ray._set_looked_at(lever_body)
	expect_prompts(["Use Custom Machine [E]"], "Changing an object's prompt resource must update its labels dynamically.")
	var previous_bindings: Array[InputEvent] = InputMap.action_get_events("confirm")
	InputMap.action_erase_events("confirm")
	var binding := InputEventKey.new()
	binding.physical_keycode = KEY_G
	InputMap.action_add_event("confirm", binding)
	expect_prompts(["Use Custom Machine [G]"], "Prompts must track InputMap binding changes.")
	InputMap.action_erase_events("confirm")
	for previous in previous_bindings:
		InputMap.action_add_event("confirm", previous)
	# Packages created by unbuilding use the same definition-driven look prompt.
	var repacked: packed_buildable = crate.definition.packed_scene.instantiate()
	repacked.definition = crate.definition
	level.add_child(repacked)
	ray._set_looked_at(repacked)
	expect_prompts(["Pickup Light [F]"], "Generic repacked crates must retain their recipe's prompts.")
	repacked.queue_free()
	await get_tree().process_frame
	expect_prompts([], "Freed targets must clear their prompts safely.")
	level.queue_free()
	await get_tree().process_frame
	print("Prompt system integration checks passed." if failures.is_empty() else "Prompt failures: " + str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
