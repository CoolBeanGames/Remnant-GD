extends Node
var capture_directory: String = "res://Reports/RailStations"
var failures: Array[String] = []
var world: Node3D
var camera: Camera3D
func _ready() -> void:
	run.call_deferred()
func tick(count: int = 6) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func capture(entry_name: String, eye: Vector3, target: Vector3) -> void:
	camera.global_position = eye
	camera.look_at(target)
	await tick()
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory+"/"+entry_name+".png") == OK,"Rendered capture saved")
func spawn_art(scene: String, at: Vector3) -> RigidBody3D:
	var actor: Node3D = WorldState.spawn_item(load(scene),world,Transform3D(Basis.IDENTITY,at))
	return physics_items.rigid_body(actor) if actor is RigidBody3D else WorldState._bodies(actor)[0]
func run() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	SaveGame.saving_disabled = true
	SaveGame.enabled = false
	Blackboard.store_data("spawned_items",[])
	Blackboard.store_data("score",50000)
	Blackboard.store_data("player_input_blocked",false)
	Flags.set_flag("mulcher purchased",true)
	Flags.set_flag("mulch bin purchased",true)
	SaveGame.profile["mulch_coins"] = 500
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root",world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.12,.14,.15)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.72,.76,.8)
	environment.environment.ambient_light_energy = .65
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-25,0)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60,.2,60)
	shape.shape = box
	floor_body.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.25,.27,.24)
	mat.roughness = .95
	mesh.material = mat
	floor_mesh.mesh = mesh
	floor_body.add_child(floor_mesh)
	floor_body.position.y = -.1
	world.add_child(floor_body)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.position = Vector3(20,0,0)
	world.add_child(player)
	camera = player.get_node("Camera3D")
	camera.make_current()
	WorldState.begin(world,player)
	await tick()
	var rail: train_rail = spawn_art("res://Scenes/Actors/train_rail.tscn",Vector3(0,.015,0))
	rail.rail_length = 8
	rail.refresh_geometry()
	rail.place_on(floor_body)
	var loader: rail_station = spawn_art("res://Scenes/Actors/rail_loader.tscn",Vector3.ZERO)
	loader.global_transform = loader.get_placement_pose(rail,rail.endpoint(1),Vector3.UP,Basis.IDENTITY).transform
	loader.place_on(rail)
	var unloader: rail_station = spawn_art("res://Scenes/Actors/rail_unloader.tscn",Vector3.ZERO)
	unloader.global_transform = unloader.get_placement_pose(rail,rail.endpoint(-1),Vector3.UP,Basis.IDENTITY).transform
	unloader.place_on(rail)
	var car: rail_slider = spawn_art("res://Scenes/Actors/rail_slider.tscn",rail.carriage_pose(0).origin)
	car.place_on(rail)
	var fan: switchable_prop = spawn_art("res://Scenes/Actors/fan.tscn",car.to_global(Vector3(.65,.12,0)))
	fan.powered = false
	fan.place_on(car)
	var bottle: RigidBody3D = spawn_art("res://Scenes/Items/beer_bottle.tscn",loader.to_global(Vector3(-.4,.8,1.4)))
	var book: RigidBody3D = spawn_art("res://Scenes/Items/book.tscn",loader.to_global(Vector3(.4,.8,1.7)))
	await tick(20)
	check(loader.queue.size() == 2,"Actual imported items enter loader")
	await capture("overview",Vector3(9,8,13),Vector3(0,.5,0))
	await capture("loader_waiting",Vector3(3.5,3.6,9),loader.to_global(Vector3(0,.65,1.3)))
	car.apply_drive_impulse(Vector3(0,0,100))
	await tick(65)
	check(car.cargo.size() == 2 and loader.queue.is_empty(),"Rendered docking transfers original models")
	await capture("car_loaded",Vector3(3.8,3.1,6.3),car.to_global(Vector3(0,.5,0)))
	car.apply_drive_impulse(Vector3(0,0,-100))
	# Capture just after real dock ejection so the original item is still airborne.
	var deadline: int = Time.get_ticks_msec()+3500
	while car.cargo.size() == 2 and Time.get_ticks_msec() < deadline:
		await tick(1)
	check(car.cargo.size() < 2,"Unloader emits the actual cargo")
	await capture("unloader_ejecting",Vector3(-3.5,3.2,-9),unloader.to_global(Vector3(0,.55,1.3)))
	await tick(20)
	check(not bottle.freeze and not book.freeze,"Visible cargo resumes physics")
	var pc: computer_terminal = load("res://Scenes/Computer/computer_terminal.tscn").instantiate()
	pc.player = player
	pc.delivery_point = Marker3D.new()
	world.add_child(pc.delivery_point)
	pc.position = Vector3(10,0,0)
	world.add_child(pc)
	pc.interact()
	await get_tree().create_timer(.8).timeout
	check(pc.interface != null,"Actual in-world PC catalog opens")
	pc.interface.tabs.current_tab = 0
	await tick(10)
	var mechanics: ScrollContainer = pc.interface.tabs.get_child(0)
	mechanics.ensure_control_visible(mechanics.get_node("List").get_child(mechanics.get_node("List").get_child_count()-1))
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory+"/lever_upgrades.png") == OK,"PC mechanics capture")
	pc.interface.tabs.current_tab = 3
	await tick(10)
	var mulch: ScrollContainer = pc.interface.tabs.get_child(3)
	mulch.ensure_control_visible(mulch.get_node("List").get_child(mulch.get_node("List").get_child_count()-1))
	await tick(4)
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(capture_directory+"/prestige_unlock.png") == OK,"PC prestige capture")
	pc.close_interface(true)
	WorldState.tracking = false
	world.queue_free()
	await tick()
	print("Rendered rail stations / imported cargo / lever and prestige PC displays: ","PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
