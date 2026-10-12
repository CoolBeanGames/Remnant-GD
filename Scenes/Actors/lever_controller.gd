class_name lever
extends Node3D
signal pulled
@export var enabled: bool = true
@export_group("Lever Upgrades")
@export_range(.05, 1, .05) var cycle_time_multiplier: float = 1.0
@export_range(.05, 1, .05) var minimum_cycle_multiplier: float = .25
@export_range(1, 16, 1) var items_per_pull: int = 1
@export var automatic: bool = false
@export_range(.1, 30, .1) var automatic_delay: float = 2.0
@export var output_multiplier: float = 1.0
var automatic_remaining: float = 0.0
var automation_paused: bool = false
var look_prompts: prompt_set
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
	automation_paused = Blackboard.read_data("lever_auto_paused") == true


func interact() -> void:
	if not enabled:
		return
	if automatic:
		automation_paused = not automation_paused
		Blackboard.store_data("lever_auto_paused", automation_paused)
		DevTools.log_info("Automatic lever paused" if automation_paused else "Automatic lever resumed", "lever")
		return
	_pull()

func _pull() -> void:
	if not enabled or state != 0:
		return
	
	green_light.light_energy = 0
	red_light.light_energy = 1
	state = 1
	pending_pull_items = clampi(roundi(items_per_pull * maxf(1, output_multiplier)), 1, 256)
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
			automatic_remaining = maxf(.1, automatic_delay)

func _physics_process(delta: float) -> void:
	if not enabled or not automatic or automation_paused or state != 0:
		return
	automatic_remaining = maxf(0, automatic_remaining - delta)
	if automatic_remaining <= 0:
		# Finish the last staggered batch before adding another automated pull.
		if is_instance_valid(chute) and chute.queued_spawns > 0:
			return
		_pull()

func get_look_prompts() -> prompt_set:
	# Keep manual lever wording resource-authored; automation supplies its state.
	var provider: object_prompts = get_node_or_null("Prompts")
	if not automatic and provider != null and provider.prompts != null:
		return provider.prompts
	if look_prompts == null:
		look_prompts = prompt_set.new()
		var entry := prompt_entry.new()
		entry.action = &"confirm"
		look_prompts.entries.append(entry)
	look_prompts.entries[0].text = ("Resume Automatic Lever" if automation_paused else "Pause Automatic Lever") if automatic else "Pull Lever"
	return look_prompts

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
