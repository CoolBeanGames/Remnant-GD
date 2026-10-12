extends Node

var failures: Array[String] = []

func _ready() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("player_input_blocked", false)
	Flags.set_flag("exited room", true)
	Flags.set_flag("level enabled", true)
	var level: Node3D = load("res://Scenes/testing_level.tscn").instantiate()
	level.set("spawn_animation_enabled", false)
	level.get_node("game_stage_base/MachineRun").autoplay = false
	add_child(level)
	level.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	var display: prompt_display = level.get_node("WorldPrompts")
	var camera: Camera3D = display.camera
	var lever: Node3D = level.get_node("Lever_Assembly/lever_body")
	camera.global_position = lever.global_position + Vector3(0, 1.2, 2.6)
	camera.look_at(lever.global_position + Vector3(0, .4, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	display.ray._physics_process(0)
	display.refresh()
	check(display.visible and not display.labels.is_empty(), "Actual look ray creates world labels")
	if display.labels.is_empty():
		get_tree().quit(1)
		return
	var label: world_prompt_label = display.labels[0]
	check(not label.no_depth_test and not label.shaded, "World lettering respects depth and needs no extra light")
	var lettering_basis: Basis = display.global_basis.orthonormalized()
	check(lettering_basis.z.dot(camera.global_basis.z) > .97, "Subtle prompt angle keeps the face readable from the gameplay camera")
	check(lettering_basis.y.is_equal_approx(camera.global_basis.y), "Prompt tilt stays on its local Y axis without rolling the text")
	var previous_position: Vector3 = display.global_position
	var provider: object_prompts = object_prompts.find_for(lever)
	var assembly: Node3D = provider.get_parent()
	var assembly_pose: Transform3D = assembly.global_transform
	# Include depth motion: a narrow viewport may legitimately clamp lateral text.
	assembly.global_position = assembly.global_position + Vector3(.2, 0, .15)
	display.refresh()
	check(not display.global_position.is_equal_approx(previous_position), "Moving model updates the world pose even when lateral placement is clamped")
	check(display.labels[0] == label, "Moving model reuses unchanged glyphs")
	assembly.global_transform = assembly_pose
	var marker := Marker3D.new()
	provider.get_parent().add_child(marker)
	marker.global_position = lever.global_position + Vector3(.8, .6, 0)
	provider.world_anchor = marker
	display.refresh()
	check(camera.unproject_position(display.global_position).distance_to(camera.unproject_position(marker.global_position)) < 1.0, "Authored marker controls the prompt origin")
	provider.world_anchor = null
	marker.queue_free()
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, .1)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = camera.global_position - camera.global_basis.z
	wall.global_basis = camera.global_basis
	await get_tree().physics_frame
	await get_tree().physics_frame
	display.ray._physics_process(0)
	display.refresh()
	check(not display.visible and display.displayed_texts.is_empty(), "A wall blocks look prompts instead of revealing objects behind it")
	wall.queue_free()
	await get_tree().physics_frame
	var fan: rotatable_item = load("res://Scenes/Actors/fan.tscn").instantiate()
	level.add_child(fan)
	display.pickup.pickup_object(fan)
	display.pickup._update_held_object(1.0)
	display.refresh()
	check(display.visible and display.labels.size() == 6, "Held fan controls form a compact world layout")
	var viewport_size: Vector2 = camera.get_viewport().get_visible_rect().size
	var position_on_screen: Vector2 = camera.unproject_position(display.global_position)
	check(Rect2(Vector2.ZERO, viewport_size).has_point(position_on_screen), "Held controls remain inside the gameplay view")
	display.pickup.player_body.set_meta("collision_space_mask", 1 << 19)
	display.refresh()
	check(display.labels.all(func(item: world_prompt_label) -> bool: return item.layers == 1 << 19), "Portal-space prompts use the player's current space and stay out of the opposite portal view")
	display.pickup.player_body.set_meta("collision_space_mask", 1)
	check(display.placement.start_building(), "Ghost starts for spatial prompt test")
	display.placement.preview.visible = false
	display.refresh()
	check(display.visible and display.displayed_texts.has("[F] Cancel"), "Missing placement surface still exposes Cancel beside the hold position")
	Blackboard.store_data("player_input_blocked", true)
	display.refresh()
	check(not display.visible, "World controls hide during input-owned interfaces")
	Blackboard.store_data("player_input_blocked", false)
	get_tree().paused = true
	display.refresh()
	check(not display.visible, "World controls hide during pause")
	get_tree().paused = false
	display.refresh()
	check(display.visible, "Gameplay restores the current world controls")
	display.placement.cancel_building()
	display.pickup.drop_object()
	level.queue_free()
	await get_tree().process_frame
	print("World prompt spatial checks passed." if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
