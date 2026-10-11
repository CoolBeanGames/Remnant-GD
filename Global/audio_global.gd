class_name audio_global
extends Node

@export_range(1, 64, 1) var maximum_collision_sounds: int = 10

## Persistent spatial sources retain their local player and authored attenuation.
## They share null-safe start/stop policy without borrowing a transient pool slot.
static func set_spatial_active(player: AudioStreamPlayer3D, enabled: bool) -> void:
	if not is_instance_valid(player):
		return
	if enabled and player.stream != null:
		if not player.playing:
			player.play()
	elif player.playing:
		player.stop()

static func play_collision(stream: AudioStream, position: Vector3, volume: float = 1.0, pitch: float = 1.0) -> void:
	var pool: object_pool = Blackboard.read_data("audio_pool")
	if stream == null or not is_instance_valid(pool):
		return
	var active: int = 0
	for player in pool.active:
		if is_instance_valid(player) and player is audio_player and player.get_meta("audio_category", &"") == &"collision":
			if is_instance_valid(player.audio_3d) and player.audio_3d.playing:
				active += 1
	if active >= Audio.maximum_collision_sounds:
		return
	var audio: audio_player = play_3d(stream, position, volume, pitch, &"SFX")
	if audio != null:
		audio.set_meta("audio_category", &"collision")


static func play_3d(
	stream: AudioStream,
	position: Vector3,
	volume: float = 1.0,
	pitch: float = 1.0,
	bus: StringName = &"Master"
) -> audio_player:

	if stream == null:
		return null
	var pool: object_pool = Blackboard.read_data("audio_pool")

	if not is_instance_valid(pool):
		push_warning("Audio pool not found on Blackboard under 'audio_pool'.")
		DevTools.log_warning("Cannot play spatial audio: audio_pool is unavailable.", "audio")
		return null

	var player: Node = pool.get_object()

	if player == null:
		return null

	if not player is audio_player:
		push_warning("Object returned from audio_pool is not an audio_player.")
		pool.release_object(player)
		return null

	var audio: audio_player = player as audio_player
	audio.set_meta("audio_category", &"")

	audio.playback_finished.connect(
		_on_audio_finished.bind(pool, audio),
		CONNECT_ONE_SHOT
	)

	audio.play_3d(
		stream,
		position,
		volume,
		pitch,
		bus
	)
	return audio


static func play_global(
	stream: AudioStream,
	volume: float = 1.0,
	pitch: float = 1.0,
	bus: StringName = &"Master"
) -> audio_player:

	if stream == null:
		return null
	var pool: object_pool = Blackboard.read_data("audio_pool")

	if not is_instance_valid(pool):
		push_warning("Audio pool not found on Blackboard under 'audio_pool'.")
		DevTools.log_warning("Cannot play global audio: audio_pool is unavailable.", "audio")
		return null

	var player: Node = pool.get_object()

	if player == null:
		return null

	if not player is audio_player:
		push_warning("Object returned from audio_pool is not an audio_player.")
		pool.release_object(player)
		return null

	var audio: audio_player = player as audio_player
	audio.set_meta("audio_category", &"")

	audio.playback_finished.connect(
		_on_audio_finished.bind(pool, audio),
		CONNECT_ONE_SHOT
	)

	audio.play_global(
		stream,
		volume,
		pitch,
		bus
	)
	return audio


static func _on_audio_finished(
	pool: object_pool,
	audio: audio_player
) -> void:

	if is_instance_valid(pool):
		pool.release_object(audio)
