class_name lever
extends Node3D
signal pulled
@export var enabled: bool = true
@export_group("Lever Upgrades")
@export_range(.05, 1, .05) var cycle_time_multiplier: float = 1.0
@export_range(.05, 1, .05) var minimum_cycle_multiplier: float = .25
@export_range(1, 16, 1) var items_per_pull: int = 1
var pending_pull_items: int = 1

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
	add_to_group("manual-lever")
	refresh_upgrade()


func interact() -> void:
	if not enabled or state != 0:
		return
	
	green_light.light_energy = 0
	red_light.light_energy = 1
	state = 1
	pending_pull_items = clampi(items_per_pull, 1, 16)
	anim.play("pull")
	Audio.play_3d(pull_sound, global_position, 1.0, 1.0, &"SFX")


func _on_animation_finished(animation_name: StringName) -> void:
	match animation_name:
		&"pull":
			if state != 1:
				return

			state = 2
			if is_instance_valid(chute):
				chute.spawn_batch(pending_pull_items)
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

func refresh_upgrade() -> void:
	Progression.apply_effects(self, "lever")
	cycle_time_multiplier = maxf(minimum_cycle_multiplier, cycle_time_multiplier)
	items_per_pull = clampi(items_per_pull, 1, 16)
	anim.speed_scale = 1.0 / maxf(.05, cycle_time_multiplier)
