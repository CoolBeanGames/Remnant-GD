class_name computer_terminal
extends StaticBody3D

@export var catalog: computer_catalog
@export var player: CharacterBody3D
@export var delivery_point: Node3D
@export var delivery_parent: Node
@export var interface_scene: PackedScene = preload("res://Scenes/UI/computer_ui.tscn")
var interface: CanvasLayer
@export var enabled: bool = true

func _ready() -> void:
	add_to_group("interact")
	var prompts := object_prompts.new()
	var entry := prompt_entry.new()
	entry.text = "Use Computer"
	entry.action = &"confirm"
	var set := prompt_set.new()
	set.entries.append(entry)
	prompts.prompts = set
	add_child(prompts)
	Progression.register_catalog(catalog)
	Progression.apply_player(player)

func interact() -> void:
	if not enabled or Blackboard.read_data("player_input_blocked") or interface_scene == null:
		return
	_open_interface.call_deferred()

func _open_interface() -> void:
	if not enabled or Blackboard.read_data("player_input_blocked"):
		return
	if not is_instance_valid(interface):
		interface = interface_scene.instantiate()
		get_tree().root.add_child(interface)
	interface.open(self)

func buy(entry: computer_entry) -> String:
	if not enabled:
		return "Computer offline."
	var parent: Node = delivery_parent if is_instance_valid(delivery_parent) else get_parent()
	return Progression.purchase(entry, parent, delivery_point, player)

func set_enabled(value: bool) -> void:
	enabled = value
	set_meta("interaction_enabled", value)
	$Screen.visible = value
	$OfflineScreen.visible = not value
	$Text.visible = value
	if not value and is_instance_valid(interface):
		interface.close()

func _exit_tree() -> void:
	if is_instance_valid(interface):
		interface.queue_free()
