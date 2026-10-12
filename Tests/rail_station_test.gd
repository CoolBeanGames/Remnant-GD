extends Node
var failures: Array[String] = []
var world: Node3D
func _ready() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func tick(count: int = 3) -> void:
	for i in count:
		await get_tree().physics_frame
		await get_tree().process_frame
func item(id: String, pose: Vector3) -> Node3D:
	var actor: Node3D = load("res://Scenes/test_object.tscn").instantiate()
	actor.start_force = 0
	actor.get_node("RigidBody3D").contact_monitor = false
	world.add_child(actor)
	actor.get_node("RigidBody3D").global_position = pose
	WorldState.track(actor, id)
	return actor
func run() -> void:
	SaveGame.enabled = false
	SaveGame.saving_disabled = true
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("player_input_blocked", false)
	world = Node3D.new()
	add_child(world)
	Blackboard.store_data("game_root", world)
	var floor := StaticBody3D.new()
	floor.name = "Floor"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60,.2,60)
	shape.shape = box
	floor.add_child(shape)
	floor.position.y = -.1
	world.add_child(floor)
	var player: CharacterBody3D = load("res://Scenes/Player/player.tscn").instantiate()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.add_child(player)
	WorldState.begin(world, player)
	await tick()
	var rail: train_rail = load("res://Scenes/Actors/train_rail.tscn").instantiate()
	rail.rail_length = 8
	rail.position.y = .015
	world.add_child(rail)
	rail.place_on(floor)
	WorldState.track(rail,"rail")
	var loader: rail_station = load("res://Scenes/Actors/rail_loader.tscn").instantiate()
	world.add_child(loader)
	WorldState.track(loader,"loader")
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	var placement: prop_placement = player.get_node("Controllers/Prop_Placement")
	var camera: Camera3D = player.get_node("Camera3D")
	pickup.pickup_object(loader)
	camera.global_position = rail.to_global(Vector3(.28,4,3.7))
	camera.look_at(rail.to_global(Vector3(.28,.15,3.7)),Vector3.FORWARD)
	await tick()
	check(placement.start_building() and placement.placement_valid, "Loader ghost snaps to a real free rail end with valid clearance")
	check(placement.try_build() and loader.placed and loader.endpoint_end == 1, "B confirms the loader on its endpoint support")
	var unloader: rail_station = load("res://Scenes/Actors/rail_unloader.tscn").instantiate()
	world.add_child(unloader)
	var snap: Dictionary = unloader.get_placement_pose(rail,rail.endpoint(-1),Vector3.UP,Basis.IDENTITY)
	unloader.global_transform = snap.transform
	unloader.place_on(rail)
	WorldState.track(unloader,"unloader")
	check(unloader.endpoint_end == -1 and unloader.global_basis.z.dot(rail.global_basis.z) < -.99, "Front-end station faces outward automatically")
	var duplicate: rail_station = load("res://Scenes/Actors/rail_loader.tscn").instantiate()
	world.add_child(duplicate)
	check(not duplicate.get_placement_pose(rail,rail.endpoint(1),Vector3.UP,Basis.IDENTITY).valid, "A second station cannot claim an occupied end")
	var extra: train_rail = load("res://Scenes/Actors/train_rail.tscn").instantiate()
	world.add_child(extra)
	check(not extra.get_placement_pose(rail,rail.endpoint(1),Vector3.UP,Basis.IDENTITY).valid, "Rail chaining respects the station's reserved endpoint")
	extra.queue_free()
	duplicate.queue_free()
	player.global_position = Vector3(15,2,0)
	var car: rail_slider = load("res://Scenes/Actors/rail_slider.tscn").instantiate()
	world.add_child(car)
	car.global_transform = rail.carriage_pose(0)
	car.place_on(rail)
	WorldState.track(car,"car")
	var light: rotatable_item = load("res://Scenes/Actors/light.tscn").instantiate()
	world.add_child(light)
	light.global_position = car.to_global(Vector3(.75,.12,0))
	light.place_on(car)
	WorldState.track(light,"light")
	var first: Node3D = item("first",loader.to_global(Vector3(-.4,.85,1.5)))
	var second: Node3D = item("second",loader.to_global(Vector3(.4,.85,1.5)))
	var body: RigidBody3D = first.get_node("RigidBody3D")
	var other: RigidBody3D = second.get_node("RigidBody3D")
	await tick(20)
	check(loader.queue.size() == 2 and body.freeze and other.freeze and car.cargo.is_empty(), "Dropped cargo waits in the bin until a car actually arrives")
	# Deliberately fill all packing heights with a solid supported obstruction.
	var blocker := rotatable_item.new()
	var solid := CollisionShape3D.new()
	var full := BoxShape3D.new()
	full.size = Vector3(2,4,2)
	solid.shape = full
	blocker.add_child(solid)
	world.add_child(blocker)
	blocker.global_position = car.to_global(Vector3(0,2.12,0))
	blocker.place_on(car)
	car.apply_drive_impulse(Vector3(0,0,100))
	await tick(45)
	check(loader.queue.size() == 2 and car.cargo.is_empty(), "Full or obstructed deck keeps waiting cargo instead of deleting it")
	blocker.queue_free()
	await tick(15)
	check(loader.queue.is_empty() and car.cargo.size() == 2 and car.get_carried_bodies().has(body), "Dock sensor transfers the original queued bodies onto the car")
	check(body.global_position.distance_to(other.global_position) > .26, "A batch loads into separate free spaces")
	car.apply_drive_impulse(Vector3(0,0,-100))
	await tick(60)
	check(car.cargo.is_empty() and not body.freeze and not other.freeze and body.collision_layer == 1, "Unloader releases original cargo physics and collisions")
	check(light.placed and light.support.get_ref() == car, "Unloading retains built-on tools")
	check(unloader.to_local(body.global_position).z > 1.8 and unloader.to_local(other.global_position).z > 1.8, "Cargo exits outward beyond the car and station")
	light.queue_free()
	await tick()
	var basket: RigidBody3D = load("res://Scenes/Actors/basket.tscn").instantiate()
	world.add_child(basket)
	basket.global_position = loader.to_global(Vector3(0,.5,1.7))
	WorldState.track(basket,"basket")
	var inner: Node3D = item("inner",basket.to_global(Vector3(0,.45,0)))
	await tick(20)
	check(loader.queue.size() == 1 and loader.queue[0].body.get_ref() == basket and basket.contents.size() == 1, "A loaded basket stays nested inside the station queue")
	car.apply_drive_impulse(Vector3(0,0,100))
	await tick(60)
	check(loader.queue.is_empty() and car.cargo.size() == 1 and basket.contents.size() == 1, "Loading a basket carries its contained item with its original identity")
	car.apply_drive_impulse(Vector3(0,0,-100))
	await tick(60)
	check(car.cargo.is_empty() and not basket.freeze and not inner.get_node("RigidBody3D").freeze, "Unloading a basket releases its contents as ordinary physics too")
	# Put the same basket back in the bin to exercise the persisted waiting queue.
	basket.global_transform = Transform3D(Basis.IDENTITY,loader.to_global(Vector3(0,.5,1.7)))
	inner.get_node("RigidBody3D").global_transform = Transform3D(Basis.IDENTITY,basket.to_global(Vector3(0,.45,0)))
	basket.linear_velocity = Vector3.ZERO
	inner.get_node("RigidBody3D").linear_velocity = Vector3.ZERO
	await tick(20)
	await save_round_trip(rail,loader,basket,inner,player)
	WorldState.tracking = false
	world.queue_free()
	await tick()
	print("Rail stations / ghosts / real docking / capacity / ejection / nested cargo / save: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func save_round_trip(_rail: train_rail, _loader: rail_station, _basket: RigidBody3D, _inner: Node3D, _player: CharacterBody3D) -> void:
	WorldState.capture()
	var records: Array = SaveGame._decode(SaveGame._encode(Blackboard.read_data("spawned_items")))
	# A player can buy a station before its rail: support resolution must not depend on purchase order.
	records.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.id == "loader" and b.id != "loader")
	WorldState.tracking = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.position = Vector3(100,100,100)
	var restored := Node3D.new()
	add_child(restored)
	var anchor := StaticBody3D.new()
	anchor.name = "Floor"
	restored.add_child(anchor)
	var avatar := CharacterBody3D.new()
	avatar.add_child(Camera3D.new())
	restored.add_child(avatar)
	Blackboard.store_data("game_root",restored)
	Blackboard.store_data("spawned_items",records)
	WorldState.begin(restored,avatar)
	await tick(8)
	var loader: rail_station = WorldState._actor("loader") as rail_station
	var basket: RigidBody3D = WorldState._actor("basket") as RigidBody3D
	var inner: Node3D = WorldState._actor("inner")
	check(loader != null and loader.placed and loader.mounted_rail() != null and loader.queue.size() == 1, "WorldState restores waiting station before its later-purchased support rail")
	if loader != null and basket != null and inner != null:
		var body: RigidBody3D = inner.get_node("RigidBody3D")
		check(loader.get_carried_bodies().has(basket) and basket.contents.size() == 1 and body.freeze and body.collision_layer == 0, "Restored basket owns the original saved inner actor without a duplicate reward")
		# Carrying the entire rail includes its station's nested cargo and fades safely.
		check(loader.mounted_rail().get_carried_bodies().has(body), "Whole-rail assembly traversal includes queued basket contents")
		portal_space.apply_actor(loader,true)
		loader.portal_transform_contents(Transform3D.IDENTITY,true)
		check(not loader.has_meta("restoring"), "Restoration permission is cleared before normal building resumes")
		loader.release_cargo_body(basket)
		check(not basket.freeze and not body.freeze, "Restored queued basket and contents return to ordinary physics")
	WorldState.tracking = false
	restored.queue_free()
	await tick()
