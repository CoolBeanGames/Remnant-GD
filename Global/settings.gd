extends Node
signal changed
const DEFAULTS: Dictionary = {
	"master": 1.0, "sfx": 1.0, "vocals": 1.0, "music": 1.0,
	"invert_x": false, "invert_y": false, "sensitivity": 1.0,
	"window_mode": 0, "vsync": true, "fps_limit": 0, "render_scale": 1.0,
	"antialiasing": 0, "shadow_quality": 1, "ambient_occlusion": true,
}
const FPS_LIMITS: Array[int] = [0, 30, 60, 90, 120, 144, 165, 240]
const SHADOW_SIZES: Array[int] = [1024, 2048, 4096, 8192]
const DIRECTIONAL_SHADOW_SIZES: Array[int] = [1024, 4096, 4096, 8192]
const SHADOW_FILTERS: Array[int] = [
	RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW,
	RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM, RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
]
const GRAPHICS_KEYS: Array[String] = ["window_mode", "vsync", "fps_limit", "render_scale", "antialiasing", "shadow_quality", "ambient_occlusion"]
var values: Dictionary = DEFAULTS.duplicate(true)
var revision: int = 0
var graphics_revision: int = 0
var world_gates: int = 0
var dirty_seconds: float = -1.0
var environments: Dictionary = {}
var _applied_shadow_quality: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SaveGame.load_profile()
	get_tree().node_added.connect(_graphics_node_added)
	restore()

func restore() -> void:
	values = DEFAULTS.duplicate(true)
	var saved: Variant = SaveGame.profile.get("settings", {})
	if saved is Dictionary:
		for key in DEFAULTS:
			if saved.has(key):
				values[key] = _validated(key, saved[key])
	graphics_revision += 1
	apply_audio()
	apply_graphics()
	changed.emit()

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key):
		return
	var validated: Variant = _validated(key, value)
	if values[key] == validated:
		return
	values[key] = validated
	revision += 1
	SaveGame.profile["settings"] = values.duplicate(true)
	dirty_seconds = .25
	if key in GRAPHICS_KEYS:
		graphics_revision += 1
		apply_graphics()
	else:
		apply_audio()
	changed.emit()

func _validated(key: String, value: Variant) -> Variant:
	if key in ["master", "sfx", "vocals", "music"]:
		return clampf(float(value), 0, 1) if value is float or value is int else DEFAULTS[key]
	elif key == "sensitivity":
		return clampf(float(value), .1, 5) if value is float or value is int else DEFAULTS[key]
	elif key == "render_scale":
		return clampf(float(value), .5, 1.0) if value is float or value is int else DEFAULTS[key]
	elif key in ["window_mode", "antialiasing", "shadow_quality", "fps_limit"]:
		if not (value is int or value is float):
			return DEFAULTS[key]
		var amount: int = int(value)
		if key == "fps_limit":
			return amount if amount in FPS_LIMITS else DEFAULTS[key]
		return clampi(amount, 0, 1 if key == "window_mode" else (4 if key == "antialiasing" else 3))
	return value if value is bool else DEFAULTS[key]

func apply_graphics() -> void:
	Engine.max_fps = int(values.fps_limit)
	# Headless test/servers do not have an operating-system window.
	if DisplayServer.get_name() != "headless":
		var window := get_tree().root
		var mode: Window.Mode = Window.MODE_FULLSCREEN if int(values.window_mode) == 1 else Window.MODE_WINDOWED
		if (mode == Window.MODE_FULLSCREEN and window.mode != mode) or (mode == Window.MODE_WINDOWED and window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]):
			window.mode = mode
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	apply_viewport(get_tree().root)
	var quality: int = int(values.shadow_quality)
	if quality != _applied_shadow_quality:
		RenderingServer.directional_shadow_atlas_set_size(DIRECTIONAL_SHADOW_SIZES[quality], true)
		RenderingServer.positional_soft_shadow_filter_set_quality(SHADOW_FILTERS[quality])
		RenderingServer.directional_soft_shadow_filter_set_quality(SHADOW_FILTERS[quality])
		_applied_shadow_quality = quality
	for id in environments.keys():
		var environment: Environment = environments[id].reference.get_ref()
		if environment == null:
			environments.erase(id)
		else:
			environment.ssao_enabled = bool(environments[id].authored_ssao) and bool(values.ambient_occlusion)

func apply_viewport(viewport: Viewport) -> void:
	# The UI remains at native resolution. Only the 3D buffers are downscaled.
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = float(values.render_scale)
	var aa: int = int(values.antialiasing)
	viewport.msaa_3d = (aa - 1) as Viewport.MSAA if aa >= 2 else Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.positional_shadow_atlas_size = SHADOW_SIZES[int(values.shadow_quality)]

func register_environment(environment: Environment) -> void:
	if environment == null:
		return
	var id: int = environment.get_instance_id()
	if not environments.has(id):
		environments[id] = {"reference": weakref(environment), "authored_ssao": environment.ssao_enabled}
	environment.ssao_enabled = bool(environments[id].authored_ssao) and bool(values.ambient_occlusion)

func _graphics_node_added(node: Node) -> void:
	if node is WorldEnvironment or node is Camera3D:
		_register_node_environment.call_deferred(weakref(node))

func _register_node_environment(reference: WeakRef) -> void:
	var node: Node = reference.get_ref()
	if is_instance_valid(node):
		register_environment(node.get("environment") as Environment)

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
