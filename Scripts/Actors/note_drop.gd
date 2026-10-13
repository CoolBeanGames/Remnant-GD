class_name note_drop
extends RigidBody3D

@export var note: note_definition
@export var collision_sounds: collision_sound_entry
var collected: bool = false

func _ready() -> void:
	body_entered.connect(_on_collision)
	if note != null:
		Notes.mark_spawned(note.id)
		$Title.text = note.title.to_upper()

func _on_collision(_body: Node) -> void:
	if collision_sounds != null and not collision_sounds.sounds.is_empty():
		audio_global.play_collision(collision_sounds.sounds.pick_random(), global_position, collision_sounds.volume)

func on_culled() -> void:
	if not collected and note != null:
		Notes.release_spawned(note.id)

func read_note() -> void:
	if collected or note == null:
		return
	collected = true
	WorldState.untrack(self)
	Notes.collect(note)
	queue_free()
