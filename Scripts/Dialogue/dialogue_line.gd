class_name dialogue_line
extends Resource

@export_multiline var text: String
@export var voiceover: AudioStream
@export_range(1.0, 100.0, 1.0) var characters_per_second: float = 28.0
@export var hold_seconds: float = 1.6
@export var fade_seconds: float = 0.5
@export var wait_for_voice: bool = true
@export var voice_volume: float = 1.0
