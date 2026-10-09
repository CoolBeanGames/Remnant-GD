class_name automatic_spawner
extends rotatable_item

@export var item_pool: item_spawn_pool = preload("res://Data/Items/default_spawn_pool.tres")
@export var spawn_interval: float = 8.0
@export var minimum_interval: float = 0.5
@export var required_flag: String = "level enabled"
var remaining: float = 8.0

func _ready() -> void:
	super._ready()
	add_to_group("automatic-spawner")
	if not get_meta("restoring", false):
		remaining = spawn_interval

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not placed or held or get_meta("carried_by_player", false) or not visible or (not required_flag.is_empty() and not Flags.check_flag(required_flag)):
		return
	remaining -= delta
	if remaining <= 0:
		remaining = maxf(minimum_interval, spawn_interval)
		var scene: PackedScene = item_pool.pick_item() if item_pool != null else null
		WorldState.spawn_item(scene, get_parent(), $Output.global_transform, true, get_meta("portal_inside", false))

func refresh_upgrade() -> void:
	Progression.apply_effects(self, "spawner")
	spawn_interval = maxf(minimum_interval, spawn_interval)
	remaining = minf(remaining, spawn_interval)
