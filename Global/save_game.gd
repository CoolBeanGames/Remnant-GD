extends Node

signal saved
signal loaded
signal save_failed(message: String)
@export var save_path: String = "user://remnant.save"
@export var autosave_seconds: float = 10.0
var enabled: bool = false
var saving_disabled: bool = false
var load_attempted: bool = false
var elapsed: float = 0.0
const VERSION: int = 2
var profile: Dictionary = {"mulch_coins": 0, "mulch_upgrades": {}, "settings": {}}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false

# All Blackboard keys are retained. Live scene handles are session-only, rebuilt
# by their owners; Resources retain their path and built-in Variants stay typed.
func _encode(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[_encode(key)] = _encode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_encode(entry))
		if value.is_typed():
			var array_script: Script = value.get_typed_script() as Script
			return {"__remnant_array__": result, "type": value.get_typed_builtin(), "class": value.get_typed_class_name(), "script": array_script.resource_path if array_script != null else ""}
		return result
	if value is Resource:
		if not value.resource_path.is_empty():
			return {"__remnant_resource__": value.resource_path}
		var properties: Dictionary = {}
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE and property.name != "script":
				properties[property.name] = _encode(value.get(property.name))
		var script: Script = value.get_script() as Script
		return {"__remnant_inline__": value.get_class(), "script": script.resource_path if script != null else "", "properties": properties}
	if value is Object or value is Callable or value is Signal or value is RID:
		return null
	return value

func _decode(value: Variant) -> Variant:
	if value is Dictionary:
		if value.has("__remnant_array__"):
			var entries: Array = _decode(value["__remnant_array__"])
			var script_path: String = str(value.get("script", ""))
			var array_script: Script = load(script_path) if not script_path.is_empty() and ResourceLoader.exists(script_path) else null
			return Array(entries, int(value.type), StringName(value["class"]), array_script)
		if value.has("__remnant_resource__"):
			var path: String = str(value["__remnant_resource__"])
			return load(path) if ResourceLoader.exists(path) else null
		if value.has("__remnant_inline__"):
			var resource: Resource
			var script_path: String = str(value.get("script", ""))
			if not script_path.is_empty() and ResourceLoader.exists(script_path):
				resource = load(script_path).new() as Resource
			elif ClassDB.can_instantiate(value["__remnant_inline__"]):
				resource = ClassDB.instantiate(value["__remnant_inline__"]) as Resource
			if resource != null:
				for property in value.get("properties", {}):
					resource.set(property, _decode(value.properties[property]))
			return resource
		var result: Dictionary = {}
		for key in value:
			result[_decode(key)] = _decode(value[key])
		return result
	if value is Array:
		var result: Array = []
		for entry in value:
			result.append(_decode(entry))
		return result
	return value

func capture_runtime() -> void:
	if WorldState.tracking and is_instance_valid(WorldState.player) and WorldState.player.is_inside_tree() and is_instance_valid(WorldState.level) and WorldState.level.is_inside_tree() and not WorldState.level.is_queued_for_deletion():
		WorldState._physics_process(0.0)
		WorldState.capture()
	Blackboard.store_data("saved_score_rewards", {"pending": ScoreRewards.pending_points, "interval": ScoreRewards.current_interval, "remaining": ScoreRewards.remaining})
	Blackboard.store_data("saved_combo", {"items": GrindCombo.item_count, "base": GrindCombo.base_points, "remaining": GrindCombo.remaining, "window": GrindCombo.current_window})
	if is_instance_valid(WorldState.level):
		Blackboard.store_data("level_exit_countdown", WorldState.level.get("exit_countdown"))

func restore_runtime(resume: bool = false) -> void:
	Progression.levels.clear()
	Progression.entries.clear()
	Progression.restored_levels = false
	ScoreRewards.reset()
	GrindCombo.reset()
	var rewards: Variant = Blackboard.read_data("saved_score_rewards")
	if rewards is Dictionary:
		ScoreRewards.pending_points = maxi(0, int(rewards.get("pending", 0)))
		ScoreRewards.current_interval = float(rewards.get("interval", ScoreRewards.point_interval))
		ScoreRewards.remaining = maxf(0, float(rewards.get("remaining", 0)))
	var combo: Variant = Blackboard.read_data("saved_combo")
	if combo is Dictionary:
		GrindCombo.item_count = maxi(0, int(combo.get("items", 0)))
		GrindCombo.base_points = maxf(0, float(combo.get("base", 0)))
		GrindCombo.remaining = maxf(0, float(combo.get("remaining", 0)))
		GrindCombo.current_window = maxf(0, float(combo.get("window", 0)))
		GrindCombo.combo_changed.emit()
	ScoreRewards.set_process(resume)
	GrindCombo.set_process(resume)

func save_now() -> bool:
	if saving_disabled:
		return false
	capture_runtime()
	var states: Dictionary = {}
	for key in Flags._flags:
		states[key] = Flags._flags[key].state
	var payload: Dictionary = {"version": VERSION, "blackboard": _encode(Blackboard._data), "flags": states}
	payload["profile"] = _encode(profile)
	payload["has_run"] = true
	return _write_payload(payload)

func _write_payload(payload: Dictionary) -> bool:
	var temporary: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("Cannot write save: " + error_string(FileAccess.get_open_error()))
	file.store_var(payload, false)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _fail("Cannot finish save: " + error_string(error))
	error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(save_path))
	if error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return _fail("Cannot replace save: " + error_string(error))
	saved.emit()
	return true

func load_now() -> bool:
	load_attempted = true
	if not FileAccess.file_exists(save_path):
		return false
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _fail("Cannot open save.")
	var payload: Variant = file.get_var(false)
	file.close()
	if not payload is Dictionary or not int(payload.get("version", 0)) in [1, VERSION] or not payload.get("blackboard") is Dictionary or not payload.get("flags") is Dictionary:
		return _fail("Save data is invalid or uses an unsupported version.")
	_restore_profile(payload)
	if not bool(payload.get("has_run", true)):
		return false
	var restored: Variant = _decode(payload.blackboard)
	Blackboard._data = restored
	# Menu locks and cinematic locks are recreated, never resumed as stuck input.
	Blackboard.store_data("player_input_blocked", false)
	Blackboard.store_data("player_waking", false)
	Flags._flags.clear()
	for key in payload.flags:
		Flags.set_flag(str(key), bool(payload.flags[key]))
	restore_runtime()
	if has_node("/root/Settings"):
		Settings.restore()
	if has_node("/root/Mulch"):
		Mulch.restore()
	loaded.emit()
	DevTools.log_info("Loaded run / version %d / %d blackboard keys / %d flags" % [int(payload.version), Blackboard._data.size(), Flags._flags.size()], "save")
	return true

func start_session() -> void:
	enabled = true
	elapsed = 0
	if not load_attempted:
		load_now()

func _process(delta: float) -> void:
	if not enabled or saving_disabled or get_tree().paused or not WorldState.tracking:
		return
	elapsed += delta
	if elapsed >= maxf(1, autosave_seconds):
		elapsed = 0
		save_now()

func exit_game() -> void:
	if not saving_disabled and has_node("/root/Settings") and not Settings.flush():
		return
	if enabled and not saving_disabled and not save_now():
		return
	saving_disabled = true
	get_tree().quit()

func reset_save() -> bool:
	# Set first: neither scene teardown nor window-close can recreate the file.
	saving_disabled = true
	enabled = false
	for path in [save_path, save_path + ".tmp"]:
		if FileAccess.file_exists(path):
			var error: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if error != OK:
				return _fail("Cannot delete save: " + error_string(error))
		if FileAccess.file_exists(path):
			return _fail("Save file still exists after deletion.")
	return true

func reset_and_quit() -> void:
	if reset_save():
		get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		exit_game()

func _fail(message: String) -> bool:
	push_warning(message)
	DevTools.log_error(message, "save")
	save_failed.emit(message)
	return false

func _read_payload() -> Dictionary:
	if not FileAccess.file_exists(save_path):
		return {}
	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	var payload: Variant = file.get_var(false)
	file.close()
	return payload if payload is Dictionary and int(payload.get("version", 0)) in [1, VERSION] else {}

func _restore_profile(payload: Dictionary) -> void:
	var value: Variant = _decode(payload.get("profile", {}))
	if value is Dictionary:
		profile = {"mulch_coins": maxi(0, int(value.get("mulch_coins", 0))), "mulch_upgrades": value.get("mulch_upgrades", {}).duplicate(true), "settings": value.get("settings", {}).duplicate(true), "lifetime_score": maxi(0, int(value.get("lifetime_score", 0))), "mulcher_unlocked": bool(value.get("mulcher_unlocked", payload.get("flags", {}).get("mulcher purchased", false)))}

func load_profile() -> void:
	var payload: Dictionary = _read_payload()
	if not payload.is_empty():
		_restore_profile(payload)

func has_run_save() -> bool:
	var payload: Dictionary = _read_payload()
	return not payload.is_empty() and bool(payload.get("has_run", true)) and payload.get("blackboard") is Dictionary and payload.get("flags") is Dictionary

func save_profile() -> bool:
	if saving_disabled:
		return false
	if enabled and is_instance_valid(WorldState.level) and WorldState.level.is_inside_tree():
		return save_now()
	var payload: Dictionary = _read_payload()
	if payload.is_empty():
		payload = {"blackboard": {}, "flags": {}, "has_run": false}
	payload["version"] = VERSION
	payload["profile"] = _encode(profile)
	return _write_payload(payload)

func new_game() -> bool:
	# Clear the current run while preserving the bank and permanent upgrades.
	load_profile()
	if not reset_save():
		return false
	Blackboard._data.clear()
	Flags._flags.clear()
	WorldState.tracking = false
	WorldState.items.clear()
	WorldState.body_cache.clear()
	WorldState.level = null
	WorldState.player = null
	restore_runtime()
	load_attempted = true
	elapsed = 0
	saving_disabled = false
	if has_node("/root/Mulch"):
		Mulch.restore()
	return save_profile()
