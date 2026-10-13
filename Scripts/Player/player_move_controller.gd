extends Node

@export var velocity_target: Vector3
@export_category("Movement")
@export var move_speed: float = 10.0
@export var sprint_speed_mult: float = 2.0
@export var acceleration: float = 40.0
@export var deceleration: float = 40.0
@export var gravity: float = 9.8
@export var terminal_speed: float = 40.0
@export var step_height: float = 0.3
@export var jump_enabled: bool = false
@export var jump_speed: float = 5.0
@export_category("Voice")
@export var jump_sounds: Array[AudioStream] = [preload("res://Audio/Vocals/vo__jump_1.wav"), preload("res://Audio/Vocals/vo__jump_2.wav"), preload("res://Audio/Vocals/vo__jump_3.wav"), preload("res://Audio/Vocals/vo__jump_4.wav"), preload("res://Audio/Vocals/vo__jump_5.wav"), preload("res://Audio/Vocals/vo__jump_6.wav")]
@export var heavy_breathing: AudioStream = preload("res://Audio/Vocals/vo__out of breath.wav")
@export var sprint_breath_seconds: float = 5.0
@export var voice_bus: StringName = &"Vocals"
var sprint_elapsed: float = 0.0
var breath_voice: WeakRef
var breath_playback_id: int = -1
@export_category("References")
@export var body: Node3D
@export var character_body: CharacterBody3D
@export var footstep_player: footstep_audio
var debug_fly: bool = false
var debug_noclip: bool = false
var debug_collision_layer: int
var debug_collision_mask: int
var step_grace: float = 0.0
var wind_velocity: Vector3 = Vector3.ZERO
var applied_wind: Vector3 = Vector3.ZERO
var step_ceiling := KinematicCollision3D.new()
var step_obstacle := KinematicCollision3D.new()
@export var wind_drag: float = 3.0
var platform_reset_pending: bool = false
var previous_rail_platform: bool = false
var last_movement_position: Vector3
var movement_position_valid: bool = false


func apply_wind(direction: Vector3, force: float, maximum_speed: float, delta: float) -> void:
	direction = direction.normalized()
	var increase: float = minf(maxf(0.0, maximum_speed - wind_velocity.dot(direction)), maxf(0.0, force) * delta)
	wind_velocity += direction * increase


func _ready() -> void:
	if character_body != null:
		character_body.floor_snap_length = step_height + 0.05
		last_movement_position = character_body.global_position
		movement_position_valid = true


func _physics_process(delta: float) -> void:
	if character_body == null or body == null:
		return
	if debug_fly or debug_noclip:
		reset_platform_motion()
		_debug_move(delta)
		return
	# A teleport can happen while this controller is disabled during wake-up.
	# Clear Godot's cached platform motion for the first move in the new space.
	if movement_position_valid and character_body.global_position.distance_to(last_movement_position) > .05:
		reset_platform_motion()
	var floor_platform: Dictionary = _rail_floor_platform()
	var rail_floor: bool = not floor_platform.is_empty()
	var floor_layers: int = character_body.platform_floor_layers
	var leave_mode: CharacterBody3D.PlatformOnLeave = character_body.platform_on_leave
	var relay_velocity := Vector3.ZERO
	if platform_reset_pending:
		character_body.platform_floor_layers = 0
	elif rail_floor and floor_platform.relay:
		# Frozen cargo and built props have no physics velocity of their own.
		# Relay their carriage's velocity through move_and_slide so walls and
		# ceilings still stop the rider, and avoid applying it a second time.
		character_body.platform_floor_layers = 0
		relay_velocity = floor_platform.slider.linear_velocity
	if rail_floor or previous_rail_platform or platform_reset_pending:
		character_body.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	character_body.velocity -= applied_wind
	wind_velocity = wind_velocity.move_toward(Vector3.ZERO, wind_drag * delta)
	step_grace = maxf(0.0, step_grace - delta)
	character_body.floor_snap_length = 0.0 if step_grace > 0.0 else step_height + 0.05
	var axis: Vector2 = make_axis()
	var sprinting: bool = Input.is_action_pressed("sprint")
	_update_sprint_audio(delta, sprinting and not axis.is_zero_approx() and character_body.is_on_floor())
	var speed: float = move_speed * (sprint_speed_mult if sprinting else 1.0)
	var desired: Vector3 = (body.global_basis.x * axis.x - body.global_basis.z * axis.y) * speed
	var horizontal: Vector3 = Vector3(character_body.velocity.x, 0, character_body.velocity.z)
	horizontal = horizontal.move_toward(desired, (acceleration if not axis.is_zero_approx() else deceleration) * delta)
	character_body.velocity.x = horizontal.x
	character_body.velocity.z = horizontal.z
	if not character_body.is_on_floor() and step_grace <= 0.0:
		character_body.velocity.y = maxf(character_body.velocity.y - gravity * delta, -terminal_speed)
	else:
		character_body.velocity.y = 0.0
	if jump_enabled and character_body.is_on_floor() and not Blackboard.read_data("player_input_blocked") and Input.is_action_just_pressed("jump"):
		play_jump_sound()
		character_body.velocity.y = jump_speed
		step_grace = 0.0
		character_body.floor_snap_length = 0.0
	applied_wind = wind_velocity
	character_body.velocity += applied_wind
	if applied_wind.y > 0.1:
		character_body.floor_snap_length = 0.0
	var own_velocity: Vector3 = character_body.velocity
	character_body.velocity += relay_velocity
	var stepped: bool = character_body.velocity.y <= 0.1 and _try_step((horizontal + relay_velocity) * delta)
	if stepped:
		character_body.velocity.x = 0.0
		character_body.velocity.z = 0.0
	if not stepped:
		character_body.move_and_slide()
	if stepped:
		character_body.velocity.x = horizontal.x
		character_body.velocity.z = horizontal.z
	elif not relay_velocity.is_zero_approx():
		# Do not subtract a velocity component that move_and_slide removed at
		# a wall: that would leave an unwanted backwards player velocity.
		character_body.velocity = own_velocity
		for index in character_body.get_slide_collision_count():
			var normal: Vector3 = character_body.get_slide_collision(index).get_normal()
			if character_body.velocity.dot(normal) < 0.0:
				character_body.velocity = character_body.velocity.slide(normal)
	character_body.platform_floor_layers = floor_layers
	character_body.platform_on_leave = leave_mode
	previous_rail_platform = rail_floor
	platform_reset_pending = false
	last_movement_position = character_body.global_position
	movement_position_valid = true
	if footstep_player != null:
		if character_body.is_on_floor() and horizontal.length() > 0.1:
			footstep_player.start(sprinting)
		else:
			footstep_player.stop()


## Call after respawn/teleport. No floor references or offsets survive the move.
func reset_platform_motion() -> void:
	platform_reset_pending = true
	previous_rail_platform = false
	if character_body != null:
		last_movement_position = character_body.global_position
		movement_position_valid = true


func _rail_floor_platform() -> Dictionary:
	if not character_body.is_on_floor() or character_body.velocity.y > .1:
		return {}
	var origin: Vector3 = character_body.global_position
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * .05,
		origin - Vector3.UP * maxf(.1, character_body.floor_snap_length), character_body.collision_mask)
	query.exclude = [character_body.get_rid()]
	var hit: Dictionary = character_body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.dot(character_body.up_direction) < cos(character_body.floor_max_angle):
		return {}
	var current: Node = hit.collider as Node
	var visited: Array[Node] = []
	while is_instance_valid(current) and not visited.has(current):
		visited.append(current)
		if current.get_meta("carried_by_player", false):
			return {}
		if current is rail_slider:
			return {"slider": current, "relay": hit.collider != current} if current.mounted_rail() != null and not current.held else {}
		var carry_owner: WeakRef = current.get_meta("rail_cargo_owner") as WeakRef if current.has_meta("rail_cargo_owner") else null
		if carry_owner != null:
			current = carry_owner.get_ref() as Node
		elif current is rotatable_item and current.support != null:
			current = current.support.get_ref() as Node
		else:
			current = current.get_parent()
	return {}


func _try_step(motion: Vector3) -> bool:
	if (not character_body.is_on_floor() and step_grace <= 0.0) or motion.is_zero_approx() or step_height <= 0.0:
		return false
	var pose: Transform3D = character_body.global_transform
	if not character_body.test_move(pose, motion, step_obstacle):
		return false
	# Authored continuous stair ramps use native slope motion. The forward
	# step probe otherwise samples higher up the ramp and teleports the capsule.
	var obstacle: Object = step_obstacle.get_collider()
	if obstacle is Node and obstacle.is_in_group("smooth-walking-surface"):
		return false
	var up: Vector3 = Vector3.UP * step_height
	if character_body.test_move(pose, up, step_ceiling) and step_ceiling.get_normal().dot(Vector3.DOWN) > 0.5:
		return false
	pose.origin += up
	if character_body.test_move(pose, motion):
		return false
	pose.origin += motion
	if not character_body.test_move(pose, -up * 1.1):
		return false
	# The capsule can meet a stair's edge with a diagonal normal. Verify the
	# actual top surface ahead so a rounded contact does not reject a step.
	var probe: Vector3 = pose.origin + motion.normalized() * 0.4 + Vector3.UP * 0.05
	var query := PhysicsRayQueryParameters3D.create(probe, probe - Vector3.UP * (step_height + 0.1), character_body.collision_mask)
	query.exclude = [character_body.get_rid()]
	var hit: Dictionary = character_body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.dot(Vector3.UP) < cos(character_body.floor_max_angle):
		return false
	if hit.position.y <= character_body.global_position.y + 0.01:
		return false
	var destination: Vector3 = pose.origin
	destination.y = hit.position.y + character_body.safe_margin + 0.004
	character_body.global_position = destination
	step_grace = 0.18
	return true


func make_axis() -> Vector2:
	if Blackboard.read_data("player_input_blocked"):
		return Vector2.ZERO
	return Vector2(Input.get_axis("left", "right"), Input.get_axis("back", "forward")).limit_length()

func play_jump_sound() -> audio_player:
	return audio_global.play_global(jump_sounds.pick_random(), 1.0, 1.0, voice_bus) if not jump_sounds.is_empty() else null

func _update_sprint_audio(delta: float, sprinting: bool) -> void:
	sprint_elapsed = sprint_elapsed + delta if sprinting else 0.0
	if sprint_elapsed < sprint_breath_seconds or heavy_breathing == null:
		return
	var audio: audio_player = breath_voice.get_ref() as audio_player if breath_voice != null else null
	if is_instance_valid(audio) and audio.is_playback_active(breath_playback_id):
		return
	audio = audio_global.play_global(heavy_breathing, 1.0, 1.0, voice_bus)
	breath_voice = weakref(audio) if audio != null else null
	breath_playback_id = audio.playback_id if audio != null else -1

func reset_audio() -> void:
	sprint_elapsed = 0.0
	var audio: audio_player = breath_voice.get_ref() as audio_player if breath_voice != null else null
	if is_instance_valid(audio):
		audio.stop(breath_playback_id)
	breath_voice = null
	breath_playback_id = -1

func _exit_tree() -> void:
	reset_audio()

func set_debug_noclip(enabled: bool) -> void:
	if enabled == debug_noclip or character_body == null:
		return
	if enabled:
		debug_collision_layer = character_body.collision_layer
		debug_collision_mask = character_body.collision_mask
		character_body.collision_layer = 0
		character_body.collision_mask = 0
	else:
		character_body.collision_layer = debug_collision_layer
		character_body.collision_mask = debug_collision_mask
	debug_noclip = enabled
	reset_platform_motion()
	wind_velocity = Vector3.ZERO
	applied_wind = Vector3.ZERO

func _debug_move(delta: float) -> void:
	if footstep_player != null:
		footstep_player.stop()
	reset_audio()
	wind_velocity = Vector3.ZERO
	applied_wind = Vector3.ZERO
	if Blackboard.read_data("player_input_blocked"):
		character_body.velocity = Vector3.ZERO
		return
	var axis := make_axis()
	var camera := character_body.get_node_or_null("Camera3D") as Camera3D
	var basis := camera.global_basis if camera != null else body.global_basis
	var direction := basis.x * axis.x - basis.z * axis.y
	if Input.is_action_pressed("jump"):
		direction += Vector3.UP
	if Input.is_physical_key_pressed(KEY_CTRL):
		direction += Vector3.DOWN
	var speed := move_speed * (sprint_speed_mult if Input.is_action_pressed("sprint") else 1.0)
	character_body.velocity = direction.normalized() * speed
	character_body.floor_snap_length = 0.0
	if debug_noclip:
		character_body.global_position += character_body.velocity * delta
	else:
		var floor_layers: int = character_body.platform_floor_layers
		var leave_mode: CharacterBody3D.PlatformOnLeave = character_body.platform_on_leave
		character_body.platform_floor_layers = 0
		character_body.platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
		character_body.move_and_slide()
		character_body.platform_floor_layers = floor_layers
		character_body.platform_on_leave = leave_mode
