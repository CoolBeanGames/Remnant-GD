@tool
extends EditorPlugin

var dock: VBoxContainer
var entries: ItemList
var database: LexiconDatabase
var selected_kind: String = "notes"

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "Lexicon"
	var reload_button := Button.new()
	reload_button.text = "Reload master list"
	reload_button.pressed.connect(_request_reload)
	dock.add_child(reload_button)
	var tabs := TabBar.new()
	for title in ["Notes", "Dialog", "Flavor"]:
		tabs.add_tab(title)
	tabs.tab_changed.connect(func(index: int) -> void:
		selected_kind = ["notes", "dialog", "flavor"][index]
		_refresh())
	dock.add_child(tabs)
	entries = ItemList.new()
	entries.custom_minimum_size = Vector2(220, 250)
	entries.item_selected.connect(_select)
	dock.add_child(entries)
	var hint := Label.new()
	hint.text = "Author in Lexicon, save to this project.\nSelect an entry to inspect its resource."
	dock.add_child(hint)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, dock)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_request_reload)
	_request_reload()

func _request_reload() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.is_scanning() or filesystem.is_importing():
		return
	set_process(false)
	if not _imports_ready():
		return
	_reload()

func _imports_ready() -> bool:
	var source_path := "res://lexicon/lexicon.source.json"
	if not FileAccess.file_exists(source_path):
		return true
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if not source is Dictionary:
		return true
	for content_kind: String in ["notes", "dialog", "flavor"]:
		for entry: Dictionary in source.get(content_kind, []):
			var media: Array[String] = []
			if content_kind == "notes":
				media.append(str(entry.get("image", "")))
			else:
				for line: Dictionary in entry.get("lines", []):
					media.append(str(line.get("audio", "")))
			for reference: String in media:
				if reference.is_empty():
					continue
				var metadata := ConfigFile.new()
				if metadata.load("res://" + reference + ".import") != OK:
					return false
				var imported_path: String = str(metadata.get_value("remap", "path", ""))
				if imported_path.is_empty() or not FileAccess.file_exists(imported_path):
					return false
	return true

func _exit_tree() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	if filesystem.filesystem_changed.is_connected(_request_reload):
		filesystem.filesystem_changed.disconnect(_request_reload)
	remove_control_from_docks(dock)
	dock.queue_free()

func _reload() -> void:
	var path := "res://lexicon/lexicon_db.tres"
	database = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as LexiconDatabase if ResourceLoader.exists(path) else null
	_refresh()

func _refresh() -> void:
	entries.clear()
	if database == null:
		return
	var catalog: LexiconCatalog = database.get(selected_kind)
	if catalog != null:
		for entry: Resource in catalog.entries:
			if entry != null:
				entries.add_item(str(entry.get("title")))
				entries.set_item_metadata(entries.item_count - 1, entry)

func _select(index: int) -> void:
	get_editor_interface().inspect_object(entries.get_item_metadata(index))
