class_name start_room_door
extends Node3D

signal opened
signal closed
@export var open_animation: StringName = &"4_open_left"
@export var close_animation: StringName = &"4_close_left"
@export_category("Audio")
@export var open_sound: AudioStream
@export_range(0.0, 2.0, 0.01) var open_sound_volume: float = 1.0
@export var open_sound_pitch: float = 1.0
@export var open_sound_bus: StringName = &"SFX"
@export var close_sound: AudioStream
@export_range(0.0, 2.0, 0.01) var close_sound_volume: float = 1.0
@export var close_sound_pitch: float = 1.0
@export var close_sound_bus: StringName = &"SFX"
var is_open: bool = false
var is_strange: bool = false
var animation: AnimationPlayer
var prompt_component: object_prompts
var close_requested: bool = false

func request_close() -> void:
	close_requested = true
	_process(0.0)

func _process(_delta: float) -> void:
	if close_requested and animation != null and not animation.is_playing():
		close_requested = false
		if is_open:
			interact()

func _ready() -> void:
	add_to_group("interact")
	animation = find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for mesh in find_children("*", "MeshInstance3D", true, false):
		mesh.create_trimesh_collision()
	prompt_component = object_prompts.new()
	add_child(prompt_component)
	is_strange = Flags.check_flag("exited room")
	Flags.connect_to_flag("exited room", [mark_strange])
	_update_prompt()
	animation.animation_finished.connect(_on_animation_finished)
	animation.play("0_idle_closed")
	animation.advance(0)
	animation.stop(true)

func interact() -> void:
	if animation.is_playing():
		return
	is_open = not is_open
	animation.play(open_animation if is_open else close_animation)
	_update_prompt()
	if is_open:
		opened.emit()
		DevTools.log_info("Strange door opened." if is_strange else "Start-room door opened.", "door")
		# Opening listeners restore SFX before the first door sound is dispatched.
		if open_sound != null:
			audio_global.play_3d(open_sound, global_position, open_sound_volume, open_sound_pitch, open_sound_bus)

func _on_animation_finished(entry_name: StringName) -> void:
	if entry_name == close_animation and not is_open:
		var sound: AudioStream = close_sound if close_sound != null else open_sound
		if sound != null:
			audio_global.play_3d(sound, global_position, close_sound_volume, close_sound_pitch, close_sound_bus)
		closed.emit()
		DevTools.log_info("Door finished closing.", "door")

func mark_strange() -> void:
	is_strange = true
	_update_prompt()

func _update_prompt() -> void:
	var entry := prompt_entry.new()
	entry.text = ("Close " if is_open else "Open ") + ("Strange Door" if is_strange else "Door")
	entry.action = &"confirm"
	var prompts := prompt_set.new()
	prompts.entries.append(entry)
	prompt_component.prompts = prompts
