class_name DevLogSink
extends Logger
## Thread-safe bounded log store. Logger callbacks never print or touch the scene tree.
var _mutex := Mutex.new()
var _entries: Array[Dictionary] = []
var _capacity: int = 2000
var _head: int = 0
var _count: int = 0
var _sequence: int = 0
var _file: FileAccess
var _path: String = ""
var _segment_bytes: int = 2 * 1024 * 1024
var _archives: int = 2
var _session_id: String = ""
var _storage_error: String = ""

func configure(path: String, session_id: String, capacity: int = 2000, segment_bytes: int = 2097152, archives: int = 2) -> void:
	_capacity = maxi(capacity, 1)
	_entries.resize(_capacity)
	_segment_bytes = maxi(segment_bytes, 4096)
	_archives = clampi(archives, 1, 8)
	_path = path
	_session_id = session_id
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		_storage_error = "Cannot write session log: " + error_string(FileAccess.get_open_error())

func append(severity: String, channel: String, message: String, details: Dictionary = {}) -> void:
	if message.strip_edges().is_empty():
		return
	_mutex.lock()
	_sequence += 1
	var entry := {"sequence": _sequence, "time": Time.get_datetime_string_from_system(), "ticks_ms": Time.get_ticks_msec(), "session": _session_id, "severity": severity, "channel": channel.left(64), "message": message.strip_edges().left(16000)}
	if not details.is_empty():
		entry["details"] = details
	_entries[(_head + _count) % _capacity] = entry
	if _count == _capacity:
		_head = (_head + 1) % _capacity
	else:
		_count += 1
	if _file != null:
		var line := JSON.stringify(entry)
		if _file.get_position() + line.to_utf8_buffer().size() > _segment_bytes:
			_rotate()
		if _file != null:
			_file.store_line(line)
			_file.flush()
			if _file.get_error() != OK:
				_storage_error = "Session log write failed: " + error_string(_file.get_error())
	_mutex.unlock()

func snapshot() -> Array[Dictionary]:
	_mutex.lock()
	var result: Array[Dictionary] = []
	for i in _count:
		result.append(_entries[(_head + i) % _capacity].duplicate(true))
	_mutex.unlock()
	return result

func sequence() -> int:
	_mutex.lock()
	var value := _sequence
	_mutex.unlock()
	return value

func storage_error() -> String:
	_mutex.lock()
	var value := _storage_error
	_mutex.unlock()
	return value

func flush() -> void:
	_mutex.lock()
	if _file != null:
		_file.flush()
	_mutex.unlock()

func close_file() -> void:
	_mutex.lock()
	if _file != null:
		_file.flush()
		_file.close()
		_file = null
	_mutex.unlock()

func _rotate() -> void:
	_file.close()
	_file = null
	for i in range(_archives, 0, -1):
		var source := _path if i == 1 else _archive_path(i - 1)
		var target := _archive_path(i)
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(target)
		if FileAccess.file_exists(source):
			DirAccess.rename_absolute(source, target)
	_file = FileAccess.open(_path, FileAccess.WRITE)
	if _file == null:
		_storage_error = "Cannot rotate session log: " + error_string(FileAccess.get_open_error())

func _archive_path(index: int) -> String:
	return _path.get_basename() + "." + str(index) + ".jsonl"

func _log_message(message: String, is_error: bool) -> void:
	append("ERROR" if is_error else "INFO", "engine", message)

func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
	var details := {"function": function, "file": file, "line": line, "type": error_type}
	if not code.is_empty():
		details["code"] = code.left(2048)
	var traces: PackedStringArray = []
	for i in mini(script_backtraces.size(), 2):
		traces.append(script_backtraces[i].format().left(8192))
	if not traces.is_empty():
		details["backtraces"] = traces
	append("WARNING" if error_type == Logger.ERROR_TYPE_WARNING else "ERROR", "engine", rationale if not rationale.is_empty() else code, details)
