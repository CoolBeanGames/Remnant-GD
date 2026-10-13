class_name scene_warmup
extends RefCounted

## Resource-only cache. Never instantiate hidden memories or trigger their story.
const PATHS: Array[String] = ["res://Scenes/Game.tscn", "res://Scenes/Environments/furnished_apartment.tscn", "res://Scenes/Environments/dilapidated_warehouse.tscn", "res://Scenes/Environments/dilapidated_hospital.tscn"]
static var scenes: Dictionary[String, PackedScene] = {}
static var queue: Array[String] = []
static var pending: String = ""
static var failed_path: String = ""

static func begin() -> void:
	for path in PATHS:
		if not scenes.has(path) and path != pending and not queue.has(path):
			queue.append(path)

static func poll() -> void:
	if not failed_path.is_empty():
		return
	if not pending.is_empty():
		var state: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(pending)
		if state == ResourceLoader.THREAD_LOAD_LOADED:
			scenes[pending] = ResourceLoader.load_threaded_get(pending) as PackedScene
			pending = ""
		elif state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			failed_path = pending
			pending = ""
	if pending.is_empty() and not queue.is_empty():
		var path: String = queue.pop_front()
		# The dummy renderer cannot create shared mesh RIDs on loading threads.
		if DisplayServer.get_name() == "headless":
			var scene: PackedScene = load(path) as PackedScene
			if scene != null:
				scenes[path] = scene
			else:
				failed_path = path
		elif ResourceLoader.load_threaded_request(path, "PackedScene", false) == OK:
			pending = path
		else:
			failed_path = path

static func progress() -> float:
	var fraction: float = float(scenes.size())
	if not pending.is_empty():
		var status: Array = []
		ResourceLoader.load_threaded_get_status(pending, status)
		if not status.is_empty():
			fraction += float(status[0])
	return fraction / PATHS.size()

static func ready() -> bool:
	return scenes.size() == PATHS.size()

static func get_scene(path: String) -> PackedScene:
	return scenes.get(path) as PackedScene

static func release() -> void:
	if not pending.is_empty():
		ResourceLoader.load_threaded_get(pending)
	pending = ""
	queue.clear()
	scenes.clear()
