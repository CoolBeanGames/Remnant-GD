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
@export var wind_drag: float = 3.0


func apply_wind(direction: Vector3, force: float, maximum_speed: float, delta: float) -> void:
	direction = direction.normalized()
	var increase: float = minf(maxf(0.0, maximum_speed - wind_velocity.dot(direction)), maxf(0.0, force) * delta)
	wind_velocity += direction * increase


func _ready() -> void:
	if character_body != null:
		character_body.floor_snap_length = step_height + 0.05


func _physics_process(delta: float) -> void:
	if character_body == null or body == null:
		return
	if debug_fly or debug_noclip:
		_debug_move(delta)
		return
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
	var stepped: bool = character_body.velocity.y <= 0.1 and _try_step(horizontal * delta)
	if stepped:
		character_body.velocity.x = 0.0
		character_body.velocity.z = 0.0
	if not stepped:
		character_body.move_and_slide()
	if stepped:
		character_body.velocity.x = horizontal.x
		character_body.velocity.z = horizontal.z
	if footstep_player != null:
		if character_body.is_on_floor() and horizontal.length() > 0.1:
			footstep_player.start(sprinting)
		else:
			footstep_player.stop()


func _try_step(motion: Vector3) -> bool:
	if (not character_body.is_on_floor() and step_grace <= 0.0) or motion.is_zero_approx() or step_height <= 0.0:
		return false
	var pose: Transform3D = character_body.global_transform
	var obstruction := KinematicCollision3D.new()
	if not character_body.test_move(pose, motion, obstruction):
		return false
	var up: Vector3 = Vector3.UP * step_height
	var ceiling := KinematicCollision3D.new()
	if character_body.test_move(pose, up, ceiling) and ceiling.get_normal().dot(Vector3.DOWN) > 0.5:
		return false
	pose.origin += up
	if character_body.test_move(pose, motion):
		return false
	pose.origin += motion
	var landing := KinematicCollision3D.new()
	if not character_body.test_move(pose, -up * 1.1, landing):
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
	return Audio.play_global(jump_sounds.pick_random(), 1.0, 1.0, voice_bus) if not jump_sounds.is_empty() else null

func _update_sprint_audio(delta: float, sprinting: bool) -> void:
	sprint_elapsed = sprint_elapsed + delta if sprinting else 0.0
	if sprint_elapsed < sprint_breath_seconds or heavy_breathing == null:
		return
	var audio: audio_player = breath_voice.get_ref() as audio_player if breath_voice != null else null
	if is_instance_valid(audio) and audio.audio_global.playing and audio.audio_global.stream == heavy_breathing:
		return
	audio = Audio.play_global(heavy_breathing, 1.0, 1.0, voice_bus)
	breath_voice = weakref(audio) if audio != null else null

func reset_audio() -> void:
	sprint_elapsed = 0.0
	var audio: audio_player = breath_voice.get_ref() as audio_player if breath_voice != null else null
	if is_instance_valid(audio) and audio.audio_global.playing and audio.audio_global.stream == heavy_breathing:
		audio.stop()
		audio.playback_finished.emit()
	breath_voice = null

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
		character_body.move_and_slide()
