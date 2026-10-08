class_name footstep_audio
extends Node3D


@export_category("Footstep Sounds")
@export var right_foot_sounds: Array[AudioStream]
@export var left_foot_sounds: Array[AudioStream]

@export_category("Foot Positions")
@export var left_player: Node3D
@export var right_player: Node3D

@export_category("Footstep Timing")
@export var footstep_timer: Timer
@export var sprint_timer: float = 0.25
@export var walk_timer: float = 0.5

@export_category("Audio")
@export_range(0.0, 1.0, 0.01) var volume: float = 1.0
@export var pitch: float = 1.0
@export var bus: StringName = &"Master"

@export_category("State")
@export var enabled: bool = false


var left_next: bool = true
var sprinting: bool = false


func _ready() -> void:
	footstep_timer.timeout.connect(_on_footstep_timer_timeout)


func start(is_sprinting: bool = false) -> void:
	sprinting = is_sprinting

	_update_timer()

	if enabled:
		return

	enabled = true
	left_next = true
	footstep_timer.start()


func stop() -> void:
	if not enabled:
		return

	enabled = false
	footstep_timer.stop()


func _update_timer() -> void:
	if sprinting:
		footstep_timer.wait_time = sprint_timer
	else:
		footstep_timer.wait_time = walk_timer


func _on_footstep_timer_timeout() -> void:
	if not enabled:
		return

	if left_next:
		play_L()
	else:
		play_R()

	left_next = not left_next

	_update_timer()


func play_L() -> void:
	play(left_player, left_foot_sounds)


func play_R() -> void:
	play(right_player, right_foot_sounds)


func play(
	position_node: Node3D,
	sounds: Array[AudioStream]
) -> void:

	if position_node == null:
		return

	if sounds.is_empty():
		return

	var sound: AudioStream = sounds.pick_random()

	audio_global.play_3d(
		sound,
		position_node.global_position,
		volume,
		pitch,
		bus
	)
