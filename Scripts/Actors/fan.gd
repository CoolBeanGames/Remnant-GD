extends switchable_prop

@export var force: float = 18.0
@export var maximum_speed: float = 12.0
@export var player_acceleration: float = 22.0
@export_category("Attachments")
@export var vacuum_enabled: bool = false
@export var vacuum_mode: bool = false
@export var swivel_enabled: bool = false
@export var swivel_active: bool = false
@export_range(0, 2, 1) var swivel_axis: int = 1
@export_range(0.0, 80.0) var swivel_stop_degrees: float = 35.0
@export_range(0.5, 30.0) var swivel_period: float = 6.0
@export var reaction_force: float = 8.0
var swivel_phase: float = 0.0
var swivel_base_pose: Transform3D = Transform3D.IDENTITY
@onready var vacuum: fan_vacuum = get_node_or_null("Vacuum")
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
	_refresh_attachments()
	if fan_audio != null:
		if fan_sound != null:
			fan_audio.stream = fan_sound
		fan_audio.volume_db = fan_sound_volume_db
		fan_audio.bus = fan_sound_bus

func _process(delta: float) -> void:
	if powered and is_visible_in_tree() and blade_pivot != null and not blade_axis.is_zero_approx():
		blade_pivot.rotate(blade_axis.normalized(), deg_to_rad(blade_speed_degrees) * delta)
	audio_global.set_spatial_active(fan_audio, powered and is_visible_in_tree())


func on_held_transform_updated() -> void:
	# Pickup disables solid collisions; keep the wind sensor live for loose items.
	$Wind.collision_mask = int(get_meta("collision_space_mask", 1)) if powered and visible and not _suction_active() else 0
	if vacuum != null:
		vacuum.intake.collision_mask = int(get_meta("collision_space_mask", 1)) if powered and visible and _suction_active() else 0
		vacuum._follow_contents()

func _apply_power() -> void:
	on_held_transform_updated()
	$Airflow.emitting = powered and visible and not _suction_active()
	audio_global.set_spatial_active(fan_audio, powered and is_visible_in_tree())


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_swivel(delta)
	_refresh_attachments()
	if not visible or not powered:
		return
	if _suction_active():
		vacuum.pull(delta)
		return
	var direction: Vector3 = -global_basis.z.normalized()
	var drive: Node3D = _drive_host() if placed else null
	if placed and not held and not get_meta("carried_by_player", false):
		if drive != null:
			drive.apply_drive_impulse(-direction * reaction_force * delta)
	var seen: Dictionary = {}
	for collider in $Wind.get_overlapping_bodies():
		if collider is CharacterBody3D:
			if held or get_meta("carried_by_player", false):
				continue
			var movement: Node = collider.get_node_or_null("Controllers/Player_Move_Controller")
			if movement != null and movement.has_method("apply_wind"):
				movement.apply_wind(direction, player_acceleration, maximum_speed, delta)
			continue
		var body: RigidBody3D = physics_items.rigid_body(collider)
		if body == self or body == drive or not physics_items.is_loose(body) or seen.has(body.get_instance_id()):
			continue
		seen[body.get_instance_id()] = true
		if body.linear_velocity.dot(direction) < maximum_speed:
			body.sleeping = false
			body.apply_central_force(direction * force)

func _suction_active() -> bool:
	return vacuum_enabled and vacuum_mode and vacuum != null

func _refresh_attachments() -> void:
	if vacuum != null:
		vacuum.visible = vacuum_enabled
		if not vacuum_enabled and not vacuum.contents.is_empty():
			vacuum.empty()
	on_held_transform_updated()
	$Airflow.emitting = powered and visible and not _suction_active()

func place_on(host: Node3D) -> void:
	super.place_on(host)
	swivel_base_pose = global_transform
	swivel_phase = 0.0

func _update_swivel(delta: float) -> void:
	if not swivel_enabled or not swivel_active or not placed or held or get_meta("carried_by_player", false):
		return
	if powered:
		swivel_phase = fmod(swivel_phase + delta * TAU / maxf(.5, swivel_period), TAU)
	var rest: Transform3D = swivel_base_pose
	var host: Node3D = support.get_ref() as Node3D if support != null else null
	if is_instance_valid(host):
		rest = host.global_transform * support_pose
	global_transform = Transform3D(rest.basis * Basis(Basis.IDENTITY[swivel_axis], sin(swivel_phase) * deg_to_rad(swivel_stop_degrees)), rest.origin)

func _drive_host() -> Node3D:
	var current: Node3D = support.get_ref() as Node3D if support != null else null
	var seen: Array[Node3D] = []
	while is_instance_valid(current) and not seen.has(current):
		if current.has_method("apply_drive_impulse"):
			return current
		seen.append(current)
		var cargo_owner: WeakRef = current.get_meta("rail_cargo_owner") as WeakRef if current.has_meta("rail_cargo_owner") else null
		var cargo_host: Node3D = cargo_owner.get_ref() as Node3D if cargo_owner != null else null
		if is_instance_valid(cargo_host):
			current = cargo_host
		else:
			current = current.support.get_ref() as Node3D if current is rotatable_item and current.support != null else current.get_parent() as Node3D
	return null

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or Blackboard.read_data("player_input_blocked") or not _controls_targeted():
		return
	if swivel_enabled and event.is_action_pressed("toggle_fan_swivel"):
		swivel_active = not swivel_active
		WorldState.capture()
		get_viewport().set_input_as_handled()
	elif vacuum_enabled and event.is_action_pressed("toggle_fan_mode"):
		vacuum_mode = not vacuum_mode
		_apply_power()
		WorldState.capture()
		get_viewport().set_input_as_handled()
	elif vacuum_enabled and event.is_action_pressed("empty_tool") and vacuum != null and not vacuum.contents.is_empty():
		vacuum.empty()
		WorldState.capture()
		get_viewport().set_input_as_handled()

func _controls_targeted() -> bool:
	if held:
		return true
	if not is_instance_valid(WorldState.player):
		return false
	var pickup: player_pickup = WorldState.player.get_node_or_null("Controllers/Player_Pickup") as player_pickup
	return pickup != null and not pickup.is_holding_object() and pickup.ray != null and pickup.ray.get_looked_at() == self

func _append_vacuum_prompts(result: prompt_set) -> prompt_set:
	if not vacuum_enabled and not swivel_enabled:
		return result
	if result == null:
		result = prompt_set.new()
	else:
		var copy := prompt_set.new()
		copy.entries.assign(result.entries)
		result = copy
	if swivel_enabled:
		var swivel := prompt_entry.new()
		swivel.text = "Stop Sweep" if swivel_active else "Sweep"
		swivel.action = &"toggle_fan_swivel"
		result.entries.append(swivel)
	if vacuum_enabled:
		var mode := prompt_entry.new()
		mode.text = "Blow" if vacuum_mode else "Suction"
		mode.action = &"toggle_fan_mode"
		result.entries.append(mode)
	if vacuum_enabled and vacuum != null and not vacuum.contents.is_empty():
		var empty := prompt_entry.new()
		empty.text = "Empty Bag (%d)" % vacuum.contents.size()
		empty.action = &"empty_tool"
		result.entries.append(empty)
	return result

func get_carry_prompts() -> prompt_set:
	return _append_vacuum_prompts(super.get_carry_prompts())

func get_look_prompts() -> prompt_set:
	return _append_vacuum_prompts(super.get_look_prompts())

func get_carried_bodies() -> Array[RigidBody3D]:
	return vacuum.get_bodies() if vacuum != null else []

func portal_transform_contents(pose_map: Transform3D, inside: bool) -> void:
	if vacuum != null:
		vacuum.portal_transform_contents(pose_map, inside)
	swivel_base_pose = pose_map * swivel_base_pose

func get_tool_state() -> Dictionary:
	return {"vacuum_contents": vacuum.get_state() if vacuum != null else [],
		"swivel_phase": swivel_phase, "swivel_base_pose": swivel_base_pose, "swivel_support_pose": support_pose}

func restore_tool_state(state: Dictionary, actor_resolver: Callable) -> void:
	swivel_phase = float(state.get("swivel_phase", 0.0))
	swivel_base_pose = state.get("swivel_base_pose", global_transform)
	if state.has("swivel_support_pose"):
		support_pose = state.swivel_support_pose
	if vacuum != null:
		vacuum.restore_state(state.get("vacuum_contents", []), actor_resolver)
