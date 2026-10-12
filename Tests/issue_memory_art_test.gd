extends Node
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _ready() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	run.call_deferred()
func capture(camera: Camera3D, name: String, position: Vector3, target: Vector3) -> Image:
	camera.global_position = position
	camera.look_at(target)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://Reports/IssueBatch/game/" + name + ".png")
	return image
func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Flags._flags.clear()
	var world := Node3D.new()
	add_child(world)
	var camera := Camera3D.new()
	camera.fov = 75
	world.add_child(camera)
	camera.current = true
	# Exercise rendered background loading without instantiating unused rooms.
	var portal := door_portal.new()
	portal.destinations.assign([load("res://Data/Portal/apartment.tres"), load("res://Data/Portal/warehouse.tres"), load("res://Data/Portal/hospital.tres")])
	world.add_child(portal)
	var deadline := Time.get_ticks_msec()+30000
	while portal.warmed_scenes.size()<3 and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	check(portal.warmed_scenes.size()==3 and portal.get_child_count()==0, "All memory resources warm while no area is instantiated")
	for kind in ["apartment", "hospital", "warehouse"]:
		var destination: portal_destination = portal._destination(StringName(kind))
		var start := Time.get_ticks_usec()
		var room: portal_room = portal._loaded_scene(destination.scene_path).instantiate()
		world.add_child(room)
		print("WARMED_INSTANTIATION_MS=", kind, "/", (Time.get_ticks_usec()-start)/1000.0)
		camera.environment = room.environment
		if kind=="apartment":
			check(room.left_foot_sounds.size()==3 and room.right_foot_sounds.size()==3, "Apartment includes editable wood step banks")
			await capture(camera,"apartment",Vector3(2.35,1.65,2.4),Vector3(-.1,1.2,-1.1))
			await capture(camera,"apartment_details",Vector3(-1.1,1.65,-.65),Vector3(-1.25,.95,-2.65))
		else:
			check(room.find_children("*", "Light3D", true, false).is_empty() and room.suppress_player_light and room.environment.ambient_light_energy==0, "Memory has no built-in lights or automatic camera lamp: "+kind)
			var position := Vector3(0,1.65,10.4) if kind=="hospital" else Vector3(4.9,1.65,9)
			var target := Vector3(0,1.2,0) if kind=="hospital" else Vector3(9.55,2.2,3)
			var dark: Image = await capture(camera,kind+"_dark",position,target)
			check(dark.get_pixel(dark.get_width()/2,dark.get_height()/2).get_luminance()<.002, "Unlit memory is visibly black: "+kind)
			# Only this fixture uses diagnostic lighting to review collision/art.
			var lamp := OmniLight3D.new()
			lamp.omni_range = 30
			lamp.light_energy = 3
			world.add_child(lamp)
			lamp.position = position+Vector3(0,1,0)
			await capture(camera,kind+"_geometry",position,target)
			if kind=="hospital":
				lamp.position = Vector3(1,2.5,0)
				await capture(camera,"hospital_intersection",Vector3(0,1.65,3),Vector3(1.8,1.1,-1))
			else:
				lamp.position=Vector3(2.5,6,-8)
				await capture(camera,"warehouse_guard",Vector3(.2,5.85,-7),Vector3(2.2,4.9,-10.6))
			lamp.free()
		room.free()
		await get_tree().process_frame
	world.queue_free()
	await get_tree().process_frame
	print("Memory art / rendered preload / wood / amber room / black rooms / diagnostic geometry: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
