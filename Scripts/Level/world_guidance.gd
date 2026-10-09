class_name world_guidance
extends Node

@export var level: level_sequence
@export var messages: word_message
@export var idle_seconds: float = 30.0
@export_multiline var death_text: String = "DONT. DO. THAT."
@export_multiline var idle_text: String = "CHEW IT UP"
@export_multiline var note_text: String = "DO NOT LISTEN"
@export_multiline var computer_text: String = "YOU DESERVE THIS"
var idle_elapsed: float = 0.0
var grinder_waiting: bool = false
var respawn_pending: bool = false

func _ready() -> void:
	level.grinder.item_ground.connect(_on_item_ground)
	level.grinder.player_entered.connect(_on_player_entered)
	Notes.note_read_finished.connect(_on_note_finished)
	Flags.connect_to_flag("grinder enabled", [_grinder_enabled])
	Flags.connect_to_flag("computer enabled", [_computer_enabled])
	if Flags.check_flag("grinder enabled"):
		_grinder_enabled()
	if Flags.check_flag("computer enabled"):
		_computer_enabled()

func _grinder_enabled() -> void:
	grinder_waiting = not Flags.check_flag("grinder used")
	var saved: Variant = Blackboard.read_data("grinder_idle_seconds")
	idle_elapsed = float(saved) if saved is float or saved is int else 0.0

func _process(delta: float) -> void:
	if not grinder_waiting:
		return
	idle_elapsed += delta
	Blackboard.store_data("grinder_idle_seconds", idle_elapsed)
	if idle_elapsed >= idle_seconds:
		messages.say(idle_text, &"grinder instruction", false, true)

func _on_item_ground(_points: int) -> void:
	Flags.set_flag("grinder used", true)
	grinder_waiting = false
	messages.cancel(&"grinder instruction")

func _on_player_entered(_player: CharacterBody3D) -> void:
	if respawn_pending:
		return
	respawn_pending = true
	_respawn.call_deferred()

func _respawn() -> void:
	if level.spawn_animation_enabled:
		await level.player.get_node("Controllers/Wake_Up").fade_for_death()
	level.respawn_player()
	messages.say(death_text, &"message grinder death", true, false, 100)
	respawn_pending = false
	level.grinder.player_contact_pending = false

func _on_note_finished(_note: Dictionary) -> void:
	messages.say(note_text, &"message first note", true, false, 50)

func _computer_enabled() -> void:
	messages.say(computer_text, &"message computer enabled", true, false, 50)
