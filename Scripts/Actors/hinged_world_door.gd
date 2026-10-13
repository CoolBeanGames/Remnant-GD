@tool
class_name hinged_world_door
extends environment_art

## Ordinary memory doors share prompts/audio, without start-room flags or portals.
@export var locked: bool = false
@export var door_title: String = "Door"
@export_range(-170, 170, 1) var open_degrees: float = -96
@export_range(.1, 3, .1) var travel_seconds: float = .65
@export var open_sound: AudioStream
@export var close_sound: AudioStream
var is_open: bool = false
var leaf: Node3D
var motion: Tween
var prompts: object_prompts

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	leaf = find_child("DoorLeaf", true, false) as Node3D
	if leaf == null:
		return
	leaf.rotation.y = 0
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.create_trimesh_collision()
	portal_space.apply_actor(self, bool(get_meta("portal_inside", false)))
	if locked:
		return
	add_to_group("interact")
	prompts = object_prompts.new()
	add_child(prompts)
	_refresh_prompt()

func interact() -> void:
	if locked or leaf == null or (motion != null and motion.is_running()):
		return
	is_open = not is_open
	_refresh_prompt()
	motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(leaf, "rotation:y", deg_to_rad(open_degrees) if is_open else 0.0, travel_seconds)
	if is_open and open_sound != null:
		audio_global.play_3d(open_sound, global_position, 1, 1, &"SFX")
	if not is_open:
		motion.tween_callback(_closed)
	DevTools.log_info("%s / %s" % [door_title, "open" if is_open else "closing"], "door")

func _closed() -> void:
	if close_sound != null:
		audio_global.play_3d(close_sound, global_position, 1, 1, &"SFX")

func _refresh_prompt() -> void:
	var entry := prompt_entry.new()
	entry.action = &"confirm"
	entry.text = ("Close " if is_open else "Open ") + door_title
	var prompt_data := prompt_set.new()
	prompt_data.entries.append(entry)
	prompts.prompts = prompt_data
