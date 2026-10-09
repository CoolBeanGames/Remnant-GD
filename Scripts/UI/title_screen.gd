extends Node3D
@export var loader_scene: PackedScene = preload("res://Scenes/save_loader.tscn")
var options: options_menu
@onready var rows: VBoxContainer = $UI/Screen/Center/Rows
func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SaveGame.enabled = false
	ScoreRewards.set_process(false)
	GrindCombo.set_process(false)
	SaveGame.load_profile()
	Settings.restore()
	rows.get_node("Continue").visible = SaveGame.has_run_save()
	SaveGame.save_failed.connect(_failed)
	rows.get_node("NewGame").pressed.connect(_new_game)
	rows.get_node("Continue").pressed.connect(_continue)
	rows.get_node("Options").pressed.connect(_options)
	rows.get_node("Exit").pressed.connect(SaveGame.exit_game)
	rows.get_node("Continue" if SaveGame.has_run_save() else "NewGame").grab_focus()
func _new_game() -> void:
	if SaveGame.new_game():
		get_tree().change_scene_to_packed(loader_scene)
func _continue() -> void:
	if SaveGame.has_run_save():
		SaveGame.saving_disabled = false
		SaveGame.load_attempted = false
		get_tree().change_scene_to_packed(loader_scene)
func _options() -> void:
	if not is_instance_valid(options):
		options = load("res://Scenes/UI/options_menu.tscn").instantiate()
		add_child(options)
	options.open()

func _failed(message: String) -> void:
	rows.get_node("Status").text = message
