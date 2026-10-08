class_name lever
extends Node3D

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


func interact() -> void:
	print("interact")
	
	if state != 0:
		return
	
	green_light.light_energy = 0
	red_light.light_energy = 1
	state = 1
	anim.play("pull")


func _on_animation_finished(animation_name: StringName) -> void:
	match animation_name:
		&"pull":
			if state != 1:
				return

			state = 2
			chute.spawn()
			Audio.play_3d(pull_sound,global_position,1,1,"SFX")
			Audio.play_3d(reset_sound,global_position,1,1,"SFX")
			anim.play("reset")

		&"reset":
			if state != 2:
				return

			anim.play("idle")
			green_light.light_energy = 1
			red_light.light_energy = 0
			state = 0
