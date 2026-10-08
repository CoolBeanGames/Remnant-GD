class_name collision_sound_entry
extends Resource

@export var name: StringName

@export_category("Target Group")
@export var group: StringName

@export_category("Audio")
@export_range(0.0, 1.0, 0.01) var volume: float = 1.0
@export var sounds: Array[AudioStream]
