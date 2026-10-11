class_name portal_return_door
extends Node3D

var target: start_room_door
var animation: AnimationPlayer
var last_animation: StringName = &""
var last_animation_position: float = -1.0

func _ready() -> void:
	add_to_group("interact")
	for mesh in find_children("*", "MeshInstance3D", true, false):
		mesh.create_trimesh_collision()
	animation = find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var prompts := object_prompts.new()
	add_child(prompts)
	portal_space.apply_actor(self, true)
	if is_instance_valid(target):
		target.opened.connect(_play_open_sound)
		target.closed.connect(_play_close_sound)
	sync_animation()

func _process(_delta: float) -> void:
	sync_animation()

func sync_animation() -> void:
	if not is_instance_valid(target) or animation == null:
		return
	var name_to_play: StringName = target.open_animation if target.is_open else target.close_animation
	var position_in_animation: float = animation.get_animation(name_to_play).length
	if target.animation.is_playing():
		name_to_play = target.animation.current_animation
		position_in_animation = target.animation.current_animation_position
	if name_to_play == last_animation and is_equal_approx(position_in_animation, last_animation_position):
		return
	last_animation = name_to_play
	last_animation_position = position_in_animation
	animation.play(name_to_play)
	animation.seek(position_in_animation, true)
	animation.stop(true)

func get_look_prompts() -> prompt_set:
	return target.prompt_component.prompts if is_instance_valid(target) else null

func interact() -> void:
	if not is_instance_valid(target):
		return
	target.interact()

func _play_open_sound() -> void:
	Audio.play_3d(target.open_sound, global_position, target.open_sound_volume, target.open_sound_pitch, target.open_sound_bus)

func _play_close_sound() -> void:
	var sound: AudioStream = target.close_sound if target.close_sound != null else target.open_sound
	Audio.play_3d(sound, global_position, target.close_sound_volume, target.close_sound_pitch, target.close_sound_bus)
