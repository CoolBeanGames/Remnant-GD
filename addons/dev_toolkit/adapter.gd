class_name DevToolsAdapter
extends Resource
## Override these hooks to connect the toolkit to a host project's systems.
@export var values: Dictionary = {}
@export var flag_values: Dictionary = {}
@export var save_path: String = ""
@export_enum("Variant", "JSON") var save_format: int = 0
@export var input_lock_key: String = "player_input_blocked"
@export var player_path: NodePath
@export var movement_path: NodePath

func blackboard_snapshot() -> Dictionary:
	return values.duplicate()
func set_blackboard(key: String, value: Variant) -> String:
	values[key] = value
	return ""
func flags_snapshot() -> Dictionary:
	return flag_values.duplicate()
func set_flag(key: String, state: bool) -> String:
	flag_values[key] = state
	return ""
func capture_input_lock() -> Dictionary:
	var data := blackboard_snapshot()
	return {"had": data.has(input_lock_key), "value": data.get(input_lock_key)}
func set_input_locked(locked: bool) -> void:
	set_blackboard(input_lock_key, locked)
func restore_input_lock(snapshot: Dictionary) -> void:
	if snapshot.get("had", false):
		set_blackboard(input_lock_key, snapshot.get("value"))
	else:
		values.erase(input_lock_key)
func save_snapshot() -> Dictionary:
	if save_path.is_empty():
		return {"path": "", "error": "No save file configured."}
	var path := ProjectSettings.globalize_path(save_path)
	if not FileAccess.file_exists(path):
		return {"path": path, "error": "No save file exists."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"path": path, "error": "Cannot read save: " + error_string(FileAccess.get_open_error())}
	var bytes := file.get_length()
	var data: Variant
	if save_format == 1:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		if error != OK:
			file.close()
			return {"path": path, "error": "Invalid JSON save: " + json.get_error_message()}
		data = json.data
	else:
		data = file.get_var(false)
		if file.get_error() != OK:
			file.close()
			return {"path": path, "error": "Invalid or unreadable save."}
	file.close()
	return {"path": path, "bytes": bytes, "data": data, "error": ""}
func _root() -> Window:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null
func player() -> Node3D:
	var root := _root()
	if root == null:
		return null
	if not player_path.is_empty():
		return root.get_node_or_null(player_path) as Node3D
	return root.get_tree().get_first_node_in_group("devtools_player") as Node3D
func movement() -> Node:
	var avatar := player()
	return avatar.get_node_or_null(movement_path) if avatar != null and not movement_path.is_empty() else null
func teleport(position: Vector3) -> String:
	var avatar := player()
	if avatar == null:
		return "No active player. Start a game first."
	avatar.global_position = position
	if avatar is CharacterBody3D:
		avatar.velocity = Vector3.ZERO
	set_blackboard("player_position", position)
	set_blackboard("player_transform", avatar.global_transform)
	return "Teleported to " + str(position)
func set_movement_mode(_mode: String, _requested: String) -> String:
	return "Player movement controller unavailable. Provide an adapter movement hook."
func report_context() -> Dictionary:
	return {}
