extends switchable_prop

@export var force: float = 18.0
@export var maximum_speed: float = 12.0
@export var player_acceleration: float = 22.0
@export_category("Blades")
@export var blade_speed_degrees: float = 720.0
@export var blade_axis: Vector3 = Vector3.FORWARD
@onready var blade_pivot: Node3D = get_node_or_null("Model/BladePivot")
@export_category("Optional Audio")
@export var fan_sound: AudioStream
@export var fan_sound_volume_db: float = -12.0
@export var fan_sound_bus: StringName = &"SFX"
@onready var fan_audio: AudioStreamPlayer3D = get_node_or_null("FanSound")

func _ready() -> void:
	super._ready()
	if fan_audio != null:
		if fan_sound != null:
			fan_audio.stream = fan_sound
		fan_audio.volume_db = fan_sound_volume_db
		fan_audio.bus = fan_sound_bus

func _process(delta: float) -> void:
	if powered and is_visible_in_tree() and blade_pivot != null and not blade_axis.is_zero_approx():
		blade_pivot.rotate(blade_axis.normalized(), deg_to_rad(blade_speed_degrees) * delta)
	if fan_audio == null:
		return
	if powered and is_visible_in_tree() and fan_audio.stream != null:
		if not fan_audio.playing:
			fan_audio.play()
	elif fan_audio.playing:
		fan_audio.stop()


func on_held_transform_updated() -> void:
	# Pickup disables solid collisions; keep the wind sensor live for loose items.
	$Wind.collision_mask = int(get_meta("collision_space_mask", 1)) if powered and visible else 0

func _apply_power() -> void:
	on_held_transform_updated()
	$Airflow.emitting = powered and visible
	if not powered and fan_audio != null:
		fan_audio.stop()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not visible or not powered:
		return
	var direction: Vector3 = -global_basis.z.normalized()
	var seen: Array[int] = []
	for collider in $Wind.get_overlapping_bodies():
		if collider is CharacterBody3D:
			if held or get_meta("carried_by_player", false):
				continue
			var movement: Node = collider.get_node_or_null("Controllers/Player_Move_Controller")
			if movement != null and movement.has_method("apply_wind"):
				movement.apply_wind(direction, player_acceleration, maximum_speed, delta)
			continue
		var body: RigidBody3D = physics_items.rigid_body(collider)
		if body == self or not physics_items.is_loose(body) or seen.has(body.get_instance_id()):
			continue
		seen.append(body.get_instance_id())
		if body.linear_velocity.dot(direction) < maximum_speed:
			body.sleeping = false
			body.apply_central_force(direction * force)
