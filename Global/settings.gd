extends Node
signal changed
const DEFAULTS: Dictionary = {"master": 1.0, "sfx": 1.0, "vocals": 1.0, "music": 1.0, "invert_x": false, "invert_y": false, "sensitivity": 1.0}
var values: Dictionary = DEFAULTS.duplicate(true)
var revision: int = 0
var world_gates: int = 0
var dirty_seconds: float = -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveGame.load_profile()
	restore()

func restore() -> void:
	values = DEFAULTS.duplicate(true)
	var saved: Variant = SaveGame.profile.get("settings", {})
	if saved is Dictionary:
		for key in DEFAULTS:
			if saved.has(key):
				values[key] = saved[key]
	for key in ["master", "sfx", "vocals", "music"]:
		values[key] = clampf(float(values[key]), 0, 1)
	values["sensitivity"] = clampf(float(values["sensitivity"]), .1, 5)
	values["invert_x"] = bool(values["invert_x"])
	values["invert_y"] = bool(values["invert_y"])
	apply_audio()
	changed.emit()

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	values[key] = value
	if key in ["master", "sfx", "vocals", "music"]:
		values[key] = clampf(float(value), 0, 1)
	elif key == "sensitivity":
		values[key] = clampf(float(value), .1, 5)
	else:
		values[key] = bool(value)
	revision += 1
	SaveGame.profile["settings"] = values.duplicate(true)
	dirty_seconds = .25
	apply_audio()
	changed.emit()

func _set_bus(name: StringName, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(volume) if volume > 0 else -80.0)

func apply_audio() -> void:
	_set_bus(&"Master", float(values.master))
	_set_bus(&"SFX", float(values.sfx))
	_set_bus(&"RoomSFX", float(values.sfx))
	_set_bus(&"Vocals", float(values.vocals))
	_set_bus(&"Music", float(values.music))
	if world_gates > 0:
		var index: int = AudioServer.get_bus_index("SFX")
		if index >= 0:
			AudioServer.set_bus_mute(index, true)

func flush() -> bool:
	if dirty_seconds < 0:
		return true
	dirty_seconds = -1
	return SaveGame.save_profile()

func _process(delta: float) -> void:
	if dirty_seconds >= 0:
		dirty_seconds -= delta
		if dirty_seconds <= 0:
			dirty_seconds = 0
			flush()
