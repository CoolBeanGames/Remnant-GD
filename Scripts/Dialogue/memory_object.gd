@tool
class_name memory_object
extends environment_art

## Assign this script to an existing art wrapper; its solid collision stays intact.
@export var story: memory_trigger_data
@export var prompt_anchor: Node3D

var _ray: WeakRef
var _look_time: float = 0.0
var _prompts := prompt_set.new()
var _surface_anchor: Marker3D

func _ready() -> void:
	super._ready()
	set_process(false)
	if Engine.is_editor_hint():
		return
	add_to_group("look-prompt")
	if story == null:
		return
	if not story.interaction_flag.is_empty():
		add_to_group("interact")
		var entry := prompt_entry.new()
		entry.text = story.prompt_text
		entry.action = &"confirm"
		_prompts.entries.append(entry)
	var provider := object_prompts.new()
	provider.name = "StoryPrompts"
	if prompt_anchor == null and not story.interaction_flag.is_empty():
		_surface_anchor = Marker3D.new()
		_surface_anchor.name = "FocusedPromptAnchor"
		add_child(_surface_anchor)
		prompt_anchor = _surface_anchor
	provider.world_anchor = prompt_anchor
	add_child(provider)

func get_look_prompts() -> prompt_set:
	if story == null or story.interaction_flag.is_empty() or Flags.check_flag(story.interaction_flag):
		return null
	if is_instance_valid(Dialogue.view) and Dialogue.view.blocks_confirm():
		return null
	return _prompts

func interact() -> void:
	if story == null or story.interaction_flag.is_empty() or Flags.check_flag(story.interaction_flag) or _input_blocked():
		return
	if is_instance_valid(Dialogue.view) and Dialogue.view.blocks_confirm():
		return
	# The objective is acknowledged by E, regardless of optional text/voice assignment.
	Flags.set_flag(story.interaction_flag, true)
	Dialogue.play(story.interaction_dialogue)
	DevTools.log_info("Inspected " + story.interaction_flag, "memories")
	_checkpoint.call_deferred()

## Called by the shared ray only when this becomes its actual unobstructed target.
func on_look_started(ray: raycaster) -> void:
	if story == null:
		return
	_ray = weakref(ray)
	_look_time = 0.0
	_update_anchor(ray)
	set_process(true)

func _process(delta: float) -> void:
	var ray: raycaster = _ray.get_ref() as raycaster if _ray != null else null
	if ray == null or ray.get_looked_at() != self:
		set_process(false)
		return
	_update_anchor(ray)
	if story.look_dialogue == null or story.look_id.is_empty() or _flavor_seen():
		return
	if _input_blocked() or not is_instance_valid(Dialogue.view) or Dialogue.view.blocks_confirm():
		_look_time = 0.0
		return
	_look_time += delta
	if _look_time < story.look_delay:
		return
	if Dialogue.play(story.look_dialogue):
		var seen: Array = _seen_flavor()
		seen.append(str(story.look_id))
		Blackboard.store_data("memory_flavor_seen", seen)
		DevTools.log_info("Looked at " + str(story.look_id), "memories")

func _update_anchor(ray: raycaster) -> void:
	if _surface_anchor != null and ray.is_colliding():
		var point: Vector3 = ray.get_collision_point()
		_surface_anchor.global_position = point + (ray.global_position - point).normalized() * .12 + Vector3.UP * .10

func _input_blocked() -> bool:
	return get_tree().paused or Blackboard.read_data("player_input_blocked") == true or Blackboard.read_data("world_view_session") != null or DevTools.any_modal_open()

func _seen_flavor() -> Array:
	var seen: Variant = Blackboard.read_data("memory_flavor_seen")
	return seen.duplicate() if seen is Array else []

func _flavor_seen() -> bool:
	return story != null and str(story.look_id) in _seen_flavor()

func _checkpoint() -> void:
	if SaveGame.enabled and not SaveGame.saving_disabled:
		SaveGame.save_now()
