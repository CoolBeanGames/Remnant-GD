class_name grind_debris_pool
extends Node3D

@export var particle_scene: PackedScene = preload("res://Scenes/Effects/grind_debris.tscn")
@export_range(1, 256, 1) var capacity: int = 64
@export_range(1, 24, 1) var particles_per_item: int = 6
@export_range(.1, 10, .1) var lifetime: float = 1.8
var pool: object_pool
var requests: Array[Dictionary] = []
var dispatch_pending: bool = false

func _ready() -> void:
	pool = object_pool.new()
	pool.pooled_scene = particle_scene
	pool.reset_method = &"reset"
	pool.initial_size = mini(capacity, 16)
	add_child(pool)
	set_physics_process(false)

func burst(point: Vector3, inside: bool = false) -> void:
	# Requests during a physics flush are deferred and bounded as well as bodies.
	if requests.size() * particles_per_item >= capacity:
		return
	requests.append({"point": point, "inside": inside})
	if not dispatch_pending:
		dispatch_pending = true
		_dispatch.call_deferred()

func _dispatch() -> void:
	dispatch_pending = false
	for request in requests:
		for index in particles_per_item:
			if pool.active.size() >= capacity:
				break
			var particle: grind_debris = pool.get_object() as grind_debris
			var collision_space: int = portal_space.ROOM_LAYER if request.inside else 1
			(particle.get_node("Mesh") as MeshInstance3D).layers = collision_space
			var pose := Transform3D(Basis.from_euler(Vector3(randf(), randf(), randf())), request.point + Vector3(randf_range(-.15, .15), .08, randf_range(-.15, .15)))
			particle.launch(pose, Vector3(randf_range(-1.3, 1.3), randf_range(1.4, 2.8), randf_range(-1.3, 1.3)), lifetime, 0, collision_space)
	requests.clear()
	set_physics_process(not pool.active.is_empty())

func _physics_process(delta: float) -> void:
	for index in range(pool.active.size() - 1, -1, -1):
		var particle: grind_debris = pool.active[index] as grind_debris
		particle.remaining -= delta
		if particle.remaining <= 0:
			pool.release_object(particle)
	if pool.active.is_empty():
		set_physics_process(false)
