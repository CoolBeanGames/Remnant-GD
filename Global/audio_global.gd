class_name audio_global
extends Node


static func play_3d(
	stream: AudioStream,
	position: Vector3,
	volume: float = 1.0,
	pitch: float = 1.0,
	bus: StringName = &"Master"
) -> void:

	var pool: object_pool = Blackboard.read_data("audio_pool")

	if pool == null:
		push_warning("Audio pool not found on Blackboard under 'audio_pool'.")
		return

	var player: Node = pool.get_object()

	if player == null:
		return

	if not player is audio_player:
		push_warning("Object returned from audio_pool is not an audio_player.")
		pool.release_object(player)
		return

	var audio: audio_player = player as audio_player

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


static func play_global(
	stream: AudioStream,
	volume: float = 1.0,
	pitch: float = 1.0,
	bus: StringName = &"Master"
) -> void:

	var pool: object_pool = Blackboard.read_data("audio_pool")

	if pool == null:
		push_warning("Audio pool not found on Blackboard under 'audio_pool'.")
		return

	var player: Node = pool.get_object()

	if player == null:
		return

	if not player is audio_player:
		push_warning("Object returned from audio_pool is not an audio_player.")
		pool.release_object(player)
		return

	var audio: audio_player = player as audio_player

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


static func _on_audio_finished(
	pool: object_pool,
	audio: audio_player
) -> void:

	pool.release_object(audio)
