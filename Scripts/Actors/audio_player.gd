class_name audio_player
extends Node3D


@export var audio_3d: AudioStreamPlayer3D
@export var audio_2d: AudioStreamPlayer

signal playback_finished
## A pooled node can outlive many sounds; retain this ID when owning a clip.
var playback_id: int = 0
var playback_active: bool = false


func _ready() -> void:
	audio_3d.finished.connect(_on_audio_finished)
	audio_2d.finished.connect(_on_audio_finished)


func play_3d(
	stream: AudioStream,
	world_position: Vector3,
	volume: float = 1.0,
	pitch: float = 1.0,
	bus: StringName = &"Master"
) -> void:

	_stop_streams()
	playback_id += 1
	playback_active = true

	global_position = world_position

	audio_3d.stream = stream
	audio_3d.volume_db = linear_to_db(maxf(0.0, volume)) if volume > 0 else -80.0
	audio_3d.pitch_scale = maxf(0.01, pitch)
	audio_3d.bus = bus

	audio_3d.play()


func play_global(
	stream: AudioStream,
	volume: float = 1.0,
	pitch: float = 1.0,
	bus: StringName = &"Master"
) -> void:

	_stop_streams()
	playback_id += 1
	playback_active = true

	audio_2d.stream = stream
	audio_2d.volume_db = linear_to_db(maxf(0.0, volume)) if volume > 0 else -80.0
	audio_2d.pitch_scale = maxf(0.01, pitch)
	audio_2d.bus = bus

	audio_2d.play()


func _stop_streams() -> void:
	audio_3d.stop()
	audio_2d.stop()


func is_playback_active(id: int) -> bool:
	return playback_active and playback_id == id and (audio_3d.playing or audio_2d.playing)


## Explicit cancellation returns the player to its pool just like natural completion.
## Passing an ID prevents a previous owner from stopping a later reused sound.
func stop(id: int = -1) -> void:
	if id >= 0 and playback_id != id:
		return
	_stop_streams()
	_on_audio_finished()


func reset() -> void:
	_stop_streams()
	playback_active = false

	audio_3d.stream = null
	audio_2d.stream = null

	audio_3d.volume_db = 0.0
	audio_2d.volume_db = 0.0

	audio_3d.pitch_scale = 1.0
	audio_2d.pitch_scale = 1.0

	audio_3d.bus = &"Master"
	audio_2d.bus = &"Master"


func _on_audio_finished() -> void:
	if not playback_active:
		return
	playback_active = false
	playback_finished.emit()
