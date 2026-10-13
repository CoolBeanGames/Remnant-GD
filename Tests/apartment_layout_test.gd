extends Node3D

var failures: Array[String] = []
var capture_directory: String = ""
var checks: int = 0
var camera: Camera3D

func _ready() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func tick(count: int = 3) -> void:
	for index in count:
		await get_tree().physics_frame
		await get_tree().process_frame

func walk(body: CharacterBody3D, target: Vector3) -> bool:
	for index in 220:
		await get_tree().physics_frame
		var offset: Vector3 = target - body.position
		offset.y = 0
		if offset.length() < .1:
			return body.position.y > -.03
		body.velocity = offset.normalized() * 3 + Vector3.DOWN
		body.move_and_slide()
	return false

func capture(view_name: String, point: Vector3, target: Vector3) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	camera.position = point
	camera.look_at(target)
	await tick(5)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(capture_directory)
	check(get_viewport().get_texture().get_image().save_png(capture_directory.path_join(view_name + ".png")) == OK, "Captured " + view_name)

func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	var room: portal_room = load("res://Scenes/Environments/furnished_apartment.tscn").instantiate()
	add_child(room)
	var environment := WorldEnvironment.new()
	environment.environment = room.environment
	add_child(environment)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 75
	add_child(camera)
	await tick()
	# The former 102 mm gap is now timber at normal floor height in every row.
	var shell_body: CollisionObject3D = room.get_node("Art/Apartment shell/Solid")
	var furniture: Array[RID] = []
	for body: CollisionObject3D in room.find_children("*", "CollisionObject3D", true, false):
		if body != shell_body:
			furniture.append(body.get_rid())
	for x: float in [3.92, 3.95, 3.98]:
		for z: float in [-2.1, -.75, .75, 2.1]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(x, .2, z), Vector3(x, -.1, z))
			query.exclude = furniture
			var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and absf(hit.position.y) < .003, "Former floor gap has flush timber collision at " + str(Vector2(x, z)))
	var tv: memory_object = room.get_node("Art/TV")
	var phone: memory_object = room.get_node("Art/LandlinePhone")
	check(tv.position.is_equal_approx(Vector3(4.45, .658, 2.8)), "TV is in the marked position beside the coffee table")
	check(room.get_node("Art/EntertainmentCenter").position.is_equal_approx(Vector3(4.7, 0, 2.8)), "The original stand moves with the television")
	check(tv.story == load("res://Data/Dialogue/Memories/apartment_tv.tres"), "TV retains its authored look flavor")
	check(phone.story.interaction_flag == "memory 1 phone" and phone.get_look_prompts() != null, "Relocated phone retains its required E interaction and prompt")
	var tv_query := PhysicsRayQueryParameters3D.create(Vector3(4.45, 1.03, 1.3), Vector3(4.45, 1.03, 2.95))
	var tv_hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(tv_query)
	check(not tv_hit.is_empty() and tv.is_ancestor_of(tv_hit.collider), "TV remains an unobstructed ray target from the living room")
	var walker := CharacterBody3D.new()
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .35
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = .9
	walker.add_child(collision)
	add_child(walker)
	walker.position = Vector3(1.76, .03, 3.9)
	await tick()
	for point: Vector3 in [Vector3(1.76, .03, 1.25), Vector3(3.2, .03, .15), Vector3(5.65, .03, .15), Vector3(7, .03, .575), Vector3(8.8, .03, .575)]:
		check(await walk(walker, point), "Full player capsule reaches " + str(point) + " without blocking or falling")
	walker.queue_free()
	await capture("engine_living", Vector3(6.8, 1.65, .5), Vector3(2, 1.1, .5))
	await capture("engine_television", Vector3(3.1, 1.65, -.65), Vector3(4.55, .9, 2.8))
	await capture("engine_floor", Vector3(5.5, 1.0, .65), Vector3(3.9, .015, -.15))
	await capture("engine_doorway", Vector3(8.4, 1.65, .575), Vector3(5.5, 1.1, .575))
	room.queue_free()
	await tick()
	Audio.begin_shutdown()
	await get_tree().create_timer(.12).timeout
	print("Apartment layout: ", "PASS / %d checks" % checks if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
