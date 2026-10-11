class_name player_wake_up
extends Node

signal started
signal finished
@export var player: CharacterBody3D
@export var camera: Camera3D
@export var duration: float = 12.8
@export var fade_in_seconds: float = 1.25
@export var dialogue_delay: float = 4.3
@export var first_dialogue: dialogue_sequence = preload("res://Data/Dialogue/first_spawn.tres")
@export var respawn_dialogue: dialogue_sequence = preload("res://Data/Dialogue/respawn.tres")
@export var slide_sounds: Array[AudioStream] = [preload("res://Audio/SFX/slide_1.wav"), preload("res://Audio/SFX/slide_2.wav")]
@export var effort_sounds: Array[AudioStream] = [preload("res://Audio/Vocals/vo__jump_1.wav"), preload("res://Audio/Vocals/vo__jump_2.wav")]
@export var death_sounds: Array[AudioStream] = [preload("res://Audio/Vocals/vo__death_1.wav"), preload("res://Audio/Vocals/vo__death_2.wav"), preload("res://Audio/Vocals/vo__death_3.wav"), preload("res://Audio/Vocals/vo__death_4.wav")]
@export var death_fade_seconds: float = .65
var cue_index: int = 0
var active: bool = false
var elapsed: float = 0.0
var standing: Transform3D
var previous_block: bool = false
var controller_states: Dictionary = {}
var selected_dialogue: dialogue_sequence
var dialogue_started: bool = false
var overlay: CanvasLayer
var black: ColorRect
var ui_states: Dictionary = {}
const TIMES: Array[float] = [0, 1.3, 2.15, 3.15, 3.65, 4.8, 5.35, 7.25, 10.15, 12.1, 12.8]
const POSITIONS: Array[Vector3] = [Vector3(.22,.17,.13), Vector3(.18,.28,.10), Vector3(.10,.63,.20), Vector3(-.04,1.12,.18), Vector3(.01,1.17,.22), Vector3(-.03,1.65,.04), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
const ANGLES: Array[Vector3] = [Vector3(-12,-8,90), Vector3(-18,-7,80), Vector3(-30,-5,52), Vector3(-12,-4,12), Vector3(-5,-2,8), Vector3(8,0,-3), Vector3.ZERO, Vector3(2,28,0), Vector3(-4,-30,0), Vector3.ZERO, Vector3.ZERO]

func _ready() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 40
	add_child(overlay)
	black = ColorRect.new()
	overlay.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.color = Color.BLACK
	overlay.hide()
	var level: Node = player.get_parent()
	if level is level_sequence and level.spawn_animation_enabled:
		overlay.show()
	set_process(false)

func start(is_respawn: bool = false) -> void:
	if active:
		_finish(false)
	var breathing: camera_breathing = player.get_node_or_null("Controllers/Camera_Breathing")
	if breathing != null:
		breathing.reset()
	standing = camera.transform
	previous_block = Blackboard.read_data("player_input_blocked") == true
	Blackboard.store_data("player_input_blocked", true)
	Blackboard.store_data("player_waking", true)
	player.velocity = Vector3.ZERO
	player.get_node("Controllers/Player_Move_Controller").reset_platform_motion()
	controller_states.clear()
	for name in ["Player_Look_Controller", "Player_Move_Controller", "Camera_Breathing"]:
		var controller: Node = player.get_node_or_null("Controllers/" + name)
		if controller != null:
			controller_states[controller] = {"process": controller.is_processing(), "physics": controller.is_physics_processing()}
			controller.set_process(false)
			controller.set_physics_process(false)
	player.get_node("footstep_sound_players").stop()
	ui_states.clear()
	for name in ["CenterContainer", "Prompt_Container"]:
		var ui: CanvasItem = player.get_parent().get_node_or_null(name)
		if ui != null:
			ui_states[ui] = ui.visible
			ui.hide()
	selected_dialogue = respawn_dialogue if is_respawn else first_dialogue
	dialogue_started = false
	elapsed = 0
	cue_index = 0
	active = true
	black.color.a = 1
	overlay.show()
	_apply_pose(0)
	set_process(true)
	started.emit()

func _position(index: int) -> Vector3:
	if index >= 6:
		return standing.origin
	var position: Vector3 = POSITIONS[index]
	position.y *= standing.origin.y / 1.887
	return position

func _apply_pose(time: float) -> void:
	var index: int = 0
	while index < TIMES.size() - 2 and time > TIMES[index + 1]:
		index += 1
	var weight: float = clampf((time - TIMES[index]) / (TIMES[index + 1] - TIMES[index]), 0, 1)
	weight = weight * weight * (3 - 2 * weight)
	camera.position = _position(index).lerp(_position(index + 1), weight)
	var angles: Vector3 = ANGLES[index].lerp(ANGLES[index + 1], weight)
	camera.basis = standing.basis * Basis.from_euler(angles * (PI / 180.0))

func _process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	black.color.a = 1.0 - smoothstep(0, maxf(.01, fade_in_seconds), elapsed)
	var pose_time: float = minf(12.8, elapsed * 12.8 / maxf(.1, duration))
	_apply_pose(pose_time)
	while cue_index < 2 and pose_time >= [1.3, 3.65][cue_index]:
		if slide_sounds.size() > cue_index:
			Audio.play_global(slide_sounds[cue_index], 1.0, 1.0, &"RoomSFX")
		if not effort_sounds.is_empty():
			Audio.play_global(effort_sounds.pick_random(), .7, 1.0, &"Vocals")
		cue_index += 1
	if not dialogue_started and elapsed >= dialogue_delay:
		dialogue_started = true
		Dialogue.play(selected_dialogue)
	if elapsed >= maxf(.1, duration):
		_finish(true)

func _finish(emit_finished: bool) -> void:
	camera.transform = standing
	var look: Node = player.get_node("Controllers/Player_Look_Controller")
	look.target_rotation = Vector2(camera.rotation_degrees.x, player.rotation_degrees.y)
	look.look_rotation = look.target_rotation
	look.mouse_input = Vector2.ZERO
	for controller in controller_states:
		if is_instance_valid(controller):
			controller.set_process(controller_states[controller].process)
			controller.set_physics_process(controller_states[controller].physics)
	controller_states.clear()
	for ui in ui_states:
		if is_instance_valid(ui):
			ui.visible = ui_states[ui]
	ui_states.clear()
	Blackboard.store_data("player_waking", false)
	Blackboard.store_data("player_input_blocked", previous_block)
	active = false
	overlay.hide()
	set_process(false)
	if emit_finished:
		finished.emit()

func _exit_tree() -> void:
	if active and is_instance_valid(camera) and is_instance_valid(player):
		_finish(false)

func fade_for_death() -> void:
	Dialogue.cancel()
	var movement: Node = player.get_node("Controllers/Player_Move_Controller")
	movement.reset_audio()
	movement.reset_platform_motion()
	var was_blocked: bool = Blackboard.read_data("player_input_blocked") == true
	Blackboard.store_data("player_input_blocked", true)
	var states: Dictionary = {}
	for name in ["Player_Move_Controller", "Player_Look_Controller", "Camera_Breathing"]:
		var controller: Node = player.get_node("Controllers/" + name)
		states[controller] = [controller.is_processing(), controller.is_physics_processing()]
		controller.set_process(false)
		controller.set_physics_process(false)
	player.get_node("footstep_sound_players").stop()
	player.velocity = Vector3.ZERO
	overlay.show()
	black.color.a = 0
	var stream: AudioStream = death_sounds.pick_random() if not death_sounds.is_empty() else null
	Audio.play_global(stream, 1.0, 1.0, &"Vocals")
	var tween: Tween = create_tween()
	tween.tween_property(black, "color:a", 1.0, maxf(.01, death_fade_seconds))
	await tween.finished
	if stream != null and stream.get_length() > death_fade_seconds:
		await get_tree().create_timer(stream.get_length() - death_fade_seconds).timeout
	for controller in states:
		controller.set_process(states[controller][0])
		controller.set_physics_process(states[controller][1])
	Blackboard.store_data("player_input_blocked", was_blocked)
