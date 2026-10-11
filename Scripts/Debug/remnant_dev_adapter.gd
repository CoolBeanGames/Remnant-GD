extends "res://addons/dev_toolkit/adapter.gd"
func blackboard_snapshot() -> Dictionary:
	return Blackboard._data.duplicate()
func set_blackboard(key: String, value: Variant) -> String:
	Blackboard.store_data(key, value)
	return ""
func flags_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for key in Flags._flags:
		result[key] = Flags._flags[key].state
	return result
func set_flag(key: String, state: bool) -> String:
	Flags.set_flag(key, state)
	return ""
func restore_input_lock(snapshot: Dictionary) -> void:
	if snapshot.get("had", false):
		Blackboard.store_data(input_lock_key, snapshot.get("value"))
	else:
		Blackboard.remove_data(input_lock_key)
func save_snapshot() -> Dictionary:
	save_path = SaveGame.save_path
	save_format = 0
	return super.save_snapshot()
func player() -> Node3D:
	return WorldState.player if is_instance_valid(WorldState.player) and WorldState.player.is_inside_tree() else null
func movement() -> Node:
	var avatar := player()
	return avatar.get_node_or_null("Controllers/Player_Move_Controller") if avatar != null else null
func teleport(position: Vector3) -> String:
	var result := super.teleport(position)
	var controller := movement()
	if controller != null:
		controller.wind_velocity = Vector3.ZERO
		controller.applied_wind = Vector3.ZERO
	return result
func set_movement_mode(mode: String, requested: String) -> String:
	var avatar := player()
	if avatar == null:
		return "No active player. Start a game first."
	var controller := movement()
	if controller == null:
		return "Player movement controller unavailable."
	var property := "debug_noclip" if mode == "noclip" else "debug_fly"
	var enabled: bool = not bool(controller.get(property)) if requested.is_empty() else requested in ["on", "true", "1"]
	if mode == "noclip":
		controller.set_debug_noclip(enabled)
	else:
		controller.debug_fly = enabled
	if avatar is CharacterBody3D:
		avatar.velocity = Vector3.ZERO
	return mode + " = " + str(enabled)
func report_context() -> Dictionary:
	return {"score": Blackboard.read_data("score"), "player_position": str(Blackboard.read_data("player_position"))}
