class_name DevToolsContext
extends Node
signal modal_changed(active_tool: StringName)
@export var adapter: DevToolsAdapter = preload("adapter.gd").new()
@export var command_catalog: DevCommandCatalog
var tools: Dictionary = {}
var active_modal: StringName = &""
var modal_snapshot: Dictionary = {}

static func resolve(owner: Node, path: NodePath = NodePath()) -> DevToolsContext:
	if not path.is_empty():
		var explicit := owner.get_node_or_null(path) as DevToolsContext
		if explicit != null:
			return explicit
	var parent := owner.get_parent()
	while parent != null:
		if parent is DevToolsContext:
			return parent
		parent = parent.get_parent()
	var existing := owner.get_tree().root.get_node_or_null("DevTools") as DevToolsContext
	if existing != null:
		return existing
	var fallback := DevToolsContext.new()
	fallback.name = "DevTools"
	owner.get_tree().root.add_child.call_deferred(fallback)
	return fallback

func _ensure_defaults() -> void:
	if adapter == null:
		adapter = DevToolsAdapter.new()
	if command_catalog == null:
		command_catalog = load("res://addons/dev_toolkit/default_commands.tres")

func register_tool(name: StringName, node: Node) -> void:
	_ensure_defaults()
	tools[name] = node
func tool(name: StringName) -> Node:
	var node: Variant = tools.get(name)
	return node if is_instance_valid(node) else null
func tool_open(name: StringName) -> bool:
	var node := tool(name)
	return node != null and bool(node.get("is_open"))
func any_modal_open() -> bool:
	return not active_modal.is_empty()
func enter_modal(name: StringName) -> bool:
	if active_modal == name:
		return true
	if active_modal == &"reporter":
		return false
	if not active_modal.is_empty():
		var old := tool(active_modal)
		var close_method: String = {"console": "close_console", "inspector": "close_inspector", "reporter": "close_report"}.get(str(active_modal), "close")
		if old != null and old.has_method(close_method):
			old.call(close_method)
	_ensure_defaults()
	modal_snapshot = {"pause": get_tree().paused, "mouse": Input.mouse_mode, "input": adapter.capture_input_lock()}
	active_modal = name
	adapter.set_input_locked(true)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modal_changed.emit(active_modal)
	return true
func leave_modal(name: StringName) -> void:
	if active_modal != name:
		return
	get_tree().paused = modal_snapshot.get("pause", false)
	Input.mouse_mode = modal_snapshot.get("mouse", Input.MOUSE_MODE_VISIBLE)
	adapter.restore_input_lock(modal_snapshot.get("input", {}))
	active_modal = &""
	modal_snapshot = {}
	modal_changed.emit(active_modal)
func modal_lock_value(key: String, value: Variant) -> bool:
	if any_modal_open() and key == adapter.input_lock_key:
		modal_snapshot["input"] = {"had": true, "value": value}
		return true
	return false
func blackboard_snapshot() -> Dictionary:
	var data := adapter.blackboard_snapshot()
	if any_modal_open():
		var lock: Dictionary = modal_snapshot.get("input", {})
		if lock.get("had", false):
			data[adapter.input_lock_key] = lock.get("value")
		else:
			data.erase(adapter.input_lock_key)
	return data
func register_command(command: DevConsoleCommand) -> void:
	_ensure_defaults()
	command_catalog.commands.append(command)
func help_text() -> String:
	_ensure_defaults()
	var lines: PackedStringArray = []
	for command: DevConsoleCommand in command_catalog.commands:
		if command != null and command.enabled:
			lines.append(command.usage + (" — " + command.description if not command.description.is_empty() else ""))
	return "\n".join(lines)
func parse_name(token: String) -> String:
	if token.begins_with('"'):
		var value: Variant = JSON.parse_string(token)
		return value if value is String else ""
	return token
func tokenize(command: String) -> Array[String]:
	var tokens: Array[String] = []
	var current := ""
	var quoted := false
	var escaped := false
	for character in command.replace("“", '"').replace("”", '"'):
		if character == '"' and not escaped:
			quoted = not quoted
		if character in [" ", "\t", "\n"] and not quoted:
			if not current.is_empty():
				tokens.append(current)
				current = ""
		else:
			current += character
		escaped = character == "\\" and not escaped
	if quoted:
		return []
	if not current.is_empty():
		tokens.append(current)
	return tokens
func execute(command: String) -> String:
	_ensure_defaults()
	var tokens := tokenize(command)
	if tokens.is_empty():
		return "Invalid command or unmatched quote. Type help."
	var matched: DevConsoleCommand
	var prefix_size := 0
	for entry: DevConsoleCommand in command_catalog.commands:
		if entry == null or not entry.enabled:
			continue
		var names := PackedStringArray([entry.command])
		names.append_array(entry.aliases)
		for name in names:
			var prefix := name.strip_edges().split(" ", false)
			if prefix.is_empty() or prefix.size() > tokens.size() or prefix.size() <= prefix_size:
				continue
			var matches := true
			for i in prefix.size():
				if prefix[i].to_lower() != tokens[i].to_lower():
					matches = false
					break
			if matches:
				matched = entry
				prefix_size = prefix.size()
	if matched == null:
		return "Unknown command or wrong arguments. Type help."
	return matched.execute(tokens.slice(prefix_size), self)
func format_value(value: Variant, depth: int = 0) -> String:
	if depth > 32:
		return "(nested/cyclic value: maximum depth reached)"
	if value is Object:
		if not is_instance_valid(value):
			return "(freed object)"
		if value is Node:
			return str(value.name)
		if value is Resource:
			if not value.resource_name.is_empty():
				return value.resource_name
			if not value.resource_path.is_empty():
				return value.resource_path.get_file()
		return value.get_class()
	var indent := "  ".repeat(depth + 1)
	var end_indent := "  ".repeat(depth)
	if value is Dictionary:
		if value.is_empty():
			return "{}"
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a).naturalnocasecmp_to(str(b)) < 0)
		var lines: PackedStringArray = []
		for key in keys:
			lines.append(indent + str(key) + ": " + format_value(value[key], depth + 1))
		return "{\n" + "\n".join(lines) + "\n" + end_indent + "}"
	if value is Array or typeof(value) in [TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY]:
		if value.is_empty():
			return "[]"
		var lines: PackedStringArray = []
		for i in value.size():
			lines.append(indent + "[" + str(i) + "] " + format_value(value[i], depth + 1))
		return "[\n" + "\n".join(lines) + "\n" + end_indent + "]"
	if value is String or value is StringName:
		return JSON.stringify(str(value))
	return str(value)
