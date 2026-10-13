extends Control
@export var game_scene: PackedScene
@export_range(0, 2, .05) var minimum_visible_seconds: float = .35
var entering: bool = false
var elapsed: float = 0
var status: Label
var progress_bar: ProgressBar

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(.018, .018, .018)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size.x = 320
	rows.add_theme_constant_override("separation", 18)
	center.add_child(rows)
	status = Label.new()
	status.text = "LOADING / 0%"
	status.add_theme_font_size_override("font_size", 28)
	rows.add_child(status)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size.y = 4
	rows.add_child(progress_bar)
	scene_warmup.begin()
	DevTools.log_info("Loading workshop and three memory resources.", "loading")

func _process(delta: float) -> void:
	if entering:
		return
	scene_warmup.poll()
	elapsed += delta
	progress_bar.value = scene_warmup.progress() * 100
	status.text = "LOADING / %d%%" % progress_bar.value
	if not scene_warmup.failed_path.is_empty():
		status.text = "COULD NOT LOAD\n" + scene_warmup.failed_path.get_file()
		set_process(false)
		DevTools.log_error("Loading failed / " + scene_warmup.failed_path, "loading")
		return
	if scene_warmup.ready() and elapsed >= minimum_visible_seconds:
		entering = true
		_load.call_deferred()

func _load() -> void:
	get_tree().paused = false
	SaveGame.load_now()
	SaveGame.enabled = true
	if game_scene == null:
		game_scene = scene_warmup.get_scene("res://Scenes/Game.tscn")
	DevTools.log_info("Loading complete; entering game with three cached memories.", "loading")
	get_tree().change_scene_to_packed(game_scene)
