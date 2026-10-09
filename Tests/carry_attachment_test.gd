extends Node
var failures: Array[String] = []
func check(ok: bool, text: String) -> void:
	if not ok:
		failures.append(text)
		push_error(text)
func tick() -> void:
	await get_tree().physics_frame
	await get_tree().process_frame
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var world := Node3D.new()
	add_child(world)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(player)
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var placement: prop_placement = player.get_node("Controllers/Prop_Placement")
	var basket: RigidBody3D = load("res://Scenes/Actors/basket.tscn").instantiate()
	basket.position = Vector3(0, 2, -2)
	world.add_child(basket)
	var light: rotatable_item = load("res://Scenes/Actors/light.tscn").instantiate()
	light.position = basket.position + Vector3(0, 1.1, 0)
	world.add_child(light)
	light.place_on(basket)
	var fan: rotatable_item = load("res://Scenes/Actors/fan.tscn").instantiate()
	fan.position = light.position + Vector3(0, 1.5, 0)
	world.add_child(fan)
	fan.place_on(light)
	var bottom: MeshInstance3D = basket.get_node("Bottom")
	bottom.transparency = .1
	var original_material: Material = bottom.mesh.surface_get_material(0)
	check(pickup.pickup_object(basket), "Basket pickup must succeed with placed props.")
	check(light.collision_layer == 0 and fan.collision_layer == 0 and light.freeze and fan.freeze, "Carrying must disable colliders of direct and nested attachments.")
	check(is_equal_approx(bottom.transparency, .415) and bottom.mesh.surface_get_material(0) == original_material, "Carry fade must compose 35% transparency without modifying shared materials.")
	var mesh: MeshInstance3D = fan.get_node("Model/Fan_Base")
	check(is_equal_approx(mesh.transparency, .35), "Attached geometry must also be 35% transparent.")
	player.position += Vector3(3, 0, 0)
	pickup._physics_process(1.0 / 60.0)
	check(light.global_transform.is_equal_approx(basket.global_transform * light.support_pose), "Lamp must follow the basket immediately.")
	check(fan.global_transform.is_equal_approx(light.global_transform * fan.support_pose), "Nested fan must follow its support in the same update.")
	check(fan.get_meta("carried_by_player", false) and fan.get_node("Wind").collision_mask == 1, "Attached fan keeps item airflow while suppressing player wind.")
	pickup.drop_object()
	check(light.collision_layer == 1 and fan.collision_layer == 1 and light.freeze and fan.freeze, "Dropping restores attachment colliders without detaching them.")
	check(is_equal_approx(bottom.transparency, .1) and mesh.transparency == 0.0 and not fan.get_meta("carried_by_player", false), "Drop restores original rendering and player wind eligibility.")
	# Upgrades retain normal ghost controls as well as the separate air option.
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, .2, 80)
	collider.shape = shape
	floor_body.position.y = -.1
	floor_body.add_child(collider)
	world.add_child(floor_body)
	var camera: Camera3D = player.get_node("Camera3D")
	player.position = Vector3(20, 2, 20)
	for id in ["upgraded_fan", "upgraded_steel_plate"]:
		var prop: rotatable_item = load("res://Scenes/Actors/%s.tscn" % id).instantiate()
		prop.position = Vector3(10, 2, 0)
		world.add_child(prop)
		pickup.pickup_object(prop)
		prop.held_rotation = Basis.IDENTITY
		camera.global_position = Vector3(10, 3, 3)
		camera.look_at(Vector3(10, 0, 0))
		await tick()
		var key := InputEventKey.new()
		key.physical_keycode = KEY_B
		key.pressed = true
		placement._unhandled_input(key)
		check(placement.is_building() and placement.placement_valid and pickup.held_object == prop, "B must start a ghost for the upgrade: " + id)
		placement._unhandled_input(key)
		check(prop.placed and prop.support.get_ref() == floor_body and not pickup.is_holding_object(), "Second B must surface-place the upgrade.")
		pickup.pickup_object(prop)
		var pose: Transform3D = prop.global_transform
		key.physical_keycode = KEY_V
		placement._unhandled_input(key)
		check(prop.placed and prop.support == null and prop.global_transform.is_equal_approx(pose), "V independently locks the exact held pose in air.")
		check(prop.get_node("Model/Fan_Base" if id == "upgraded_fan" else "Plate/Mesh_0").transparency == 0.0, "Placed upgrades must return to opaque rendering.")
		pickup.pickup_object(prop)
		prop.held_rotation = Basis.from_euler(Vector3(.3, .6, .7))
		pickup._update_held_object(1.0 / 60.0)
		pose = prop.global_transform
		placement.start_building()
		prop.rotate_held(1)
		placement._unhandled_input(key)
		check(prop.global_transform.is_equal_approx(pose), "V from a ghost preserves the original held pose rather than its anchor orientation.")
		prop.queue_free()
	var broom: RigidBody3D = load("res://Scenes/Actors/push_broom.tscn").instantiate()
	world.add_child(broom)
	check(broom.push_acceleration == 52.5 and broom.maximum_speed == 7.5, "Broom acceleration and maximum push speed must be 50% stronger.")
	world.queue_free()
	await tick()
	print("Carry attachments/transparency and dual placement: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
