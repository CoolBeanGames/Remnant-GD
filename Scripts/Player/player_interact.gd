class_name player_interact
extends Node

@export_category("References")
@export var ray: raycaster
@export var pickup: player_pickup

@export_category("Debug")
@export var debug_enabled: bool = false


func _ready() -> void:
	_debug("Ready.")

	if ray == null:
		_debug("ERROR: Ray reference missing.")

	if pickup == null:
		_debug("ERROR: Pickup reference missing.")


func _process(_delta: float) -> void:
	if Blackboard.read_data("player_input_blocked") or (Dialogue.view != null and Dialogue.view.blocks_confirm()):
		return
	if not Input.is_action_just_released("confirm"):
		return

	_debug("Confirm released.")

	if pickup != null and pickup.is_holding_object():
		_debug("Interaction blocked: holding an object.")
		return

	if ray == null:
		_debug("Interaction failed: ray reference missing.")
		return

	if not ray.is_looking_at_something():
		_debug("Interaction failed: no valid target.")
		return

	var target: Node3D = ray.get_looked_at()

	if not is_instance_valid(target):
		_debug("Interaction failed: invalid target.")
		return

	_debug("Target: %s" % target.name)
	_debug("Groups: %s" % str(target.get_groups()))

	if target.has_method("interact"):
		_debug("Calling interact().")
		target.interact()
	else:
		_debug("Target has no interact() method.")


func _debug(message: String) -> void:
	if debug_enabled:
		print("[PlayerInteract] ", message)
