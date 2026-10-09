class_name staged_light
extends Light3D

@export var unlock_flag: String = "level enabled"
@export var power_on_sound: AudioStream = preload("res://Audio/SFX/light_power_on.wav")
@export var sound_volume: float = 1.0
@export var sound_bus: StringName = &"SFX"
var authored_energy: float = 1.0
var powered: bool = false

func _ready() -> void:
	authored_energy = light_energy
	powered = Flags.check_flag(unlock_flag)
	light_energy = authored_energy if powered else 0.0
	Flags.connect_to_flag(unlock_flag, [turn_on])

func turn_on() -> void:
	if powered:
		return
	powered = true
	light_energy = authored_energy
	if power_on_sound != null:
		audio_global.play_3d(power_on_sound, global_position, sound_volume, 1.0, sound_bus)
