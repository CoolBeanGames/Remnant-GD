class_name audio_player
extends Node3D


@export var audio_3d: AudioStreamPlayer3D
@export var audio_global: AudioStreamPlayer

signal playback_finished


func _ready() -> void:
	audio_3d.finished.connect(_on_audio_finished)
	audio_global.finished.connect(_on_audio_finished)


func play_3d(
	stream: AudioStream,
	position: Vector3,
	volume: float = 1.0,
	pitch: float = 1.0,
	bus: StringName = &"Master"
) -> void:

	audio_global.stop()
	audio_3d.stop()

	global_position = position

	audio_3d.stream = stream
	audio_3d.volume_db = linear_to_db(volume)
	audio_3d.pitch_scale = pitch
	audio_3d.bus = bus

	audio_3d.play()


func play_global(
	stream: AudioStream,
	volume: float = 1.0,
	pitch: float = 1.0,
	bus: StringName = &"Master"
) -> void:

	audio_3d.stop()
	audio_global.stop()

	audio_global.stream = stream
	audio_global.volume_db = linear_to_db(volume)
	audio_global.pitch_scale = pitch
	audio_global.bus = bus

	audio_global.play()


func stop() -> void:
	audio_3d.stop()
	audio_global.stop()


func reset() -> void:
	stop()

	audio_3d.stream = null
	audio_global.stream = null

	audio_3d.volume_db = 0.0
	audio_global.volume_db = 0.0

	audio_3d.pitch_scale = 1.0
	audio_global.pitch_scale = 1.0

	audio_3d.bus = &"Master"
	audio_global.bus = &"Master"


func _on_audio_finished() -> void:
	playback_finished.emit()
