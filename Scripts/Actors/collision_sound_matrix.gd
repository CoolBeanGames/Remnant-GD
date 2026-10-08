class_name collision_sound_matrix
extends Node3D


@export var sound_matrix: Array[collision_sound_entry]


func collide(other: Node) -> void:
	if other == null:
		return

	var entry: collision_sound_entry = get_collision_entry(other)

	if entry == null:
		return

	if entry.sounds.is_empty():
		return

	var sound: AudioStream = entry.sounds.pick_random()

	audio_global.play_3d(
		sound,
		global_position,
		entry.volume
	)


func get_collision_entry(other: Node) -> collision_sound_entry:
	for entry: collision_sound_entry in sound_matrix:
		if entry.group == &"":
			continue

		if other.is_in_group(entry.group):
			return entry

	return null
