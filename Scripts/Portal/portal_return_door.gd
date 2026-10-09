class_name portal_return_door
extends Node3D

var target: start_room_door
var animation: AnimationPlayer

func _ready() -> void:
	add_to_group("interact")
	for mesh in find_children("*", "MeshInstance3D", true, false):
		mesh.create_trimesh_collision()
	animation = find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var prompts := object_prompts.new()
	add_child(prompts)
	portal_space.apply_actor(self, true)
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
	animation.play(name_to_play)
	animation.seek(position_in_animation, true)
	animation.stop(true)

func get_look_prompts() -> prompt_set:
	return target.prompt_component.prompts if is_instance_valid(target) else null

func interact() -> void:
	if not is_instance_valid(target):
		return
	var was_open: bool = target.is_open
	target.interact()
	if was_open == target.is_open:
		return
	var sound: AudioStream = target.open_sound if target.is_open else (target.close_sound if target.close_sound != null else target.open_sound)
	var volume: float = target.open_sound_volume if target.is_open else target.close_sound_volume
	var pitch: float = target.open_sound_pitch if target.is_open else target.close_sound_pitch
	var bus: StringName = target.open_sound_bus if target.is_open else target.close_sound_bus
	Audio.play_3d(sound, global_position, volume, pitch, bus)
