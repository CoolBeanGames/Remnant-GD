class_name lever
extends Node3D
signal pulled
@export var enabled: bool = true

# 0 = idle, 1 = pull, 2 = reset
var state: int = 0

@export var anim: AnimationPlayer
@export var chute : ceiling_chute
@export var pull_sound : AudioStream
@export var reset_sound : AudioStream
@export var green_light : OmniLight3D
@export var red_light : OmniLight3D


func _ready() -> void:
	green_light.light_energy = 1
	red_light.light_energy = 0
	anim.animation_finished.connect(_on_animation_finished)
	set_enabled(enabled)


func interact() -> void:
	if not enabled or state != 0:
		return
	
	green_light.light_energy = 0
	red_light.light_energy = 1
	state = 1
	anim.play("pull")
	Audio.play_3d(pull_sound, global_position, 1.0, 1.0, &"SFX")


func _on_animation_finished(animation_name: StringName) -> void:
	match animation_name:
		&"pull":
			if state != 1:
				return

			state = 2
			chute.spawn()
			pulled.emit()
			Audio.play_3d(reset_sound, global_position, 1.0, 1.0, &"SFX")
			anim.play("reset")

		&"reset":
			if state != 2:
				return

			anim.play("idle")
			green_light.light_energy = 1
			red_light.light_energy = 0
			state = 0

func set_enabled(value: bool) -> void:
	enabled = value
	set_meta("interaction_enabled", value)
	green_light.light_energy = 1 if value else 0
	red_light.light_energy = 0
	for light in find_children("*", "Light3D", true, false):
		if light == green_light or light == red_light:
			continue
		if not light.has_meta("enabled_energy"):
			light.set_meta("enabled_energy", light.light_energy)
		light.light_energy = light.get_meta("enabled_energy") if value else 0.0
