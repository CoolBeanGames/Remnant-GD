class_name word_message
extends CanvasLayer

signal word_shown(word: String, key: StringName)
signal message_finished(key: StringName)
@export var word_seconds: float = 0.65
@export var phrase_gap: float = 1.0
@export var font_size: int = 140
@export var word_sound: AudioStream = preload("res://Audio/SFX/world_word.wav")
@export var sound_volume: float = 0.9
@export var sound_bus: StringName = &"SFX"
var queue: Array[Dictionary] = []
var current: Dictionary = {}
var word_index: int = 0
var remaining: float = 0.0
@onready var label: Label = $Word

func _ready() -> void:
	hide()
	get_viewport().size_changed.connect(_fit_word)
	Blackboard.store_data("world_messages", self)

func say(text: String, key: StringName = &"", once: bool = false, repeat: bool = false, priority: int = 0) -> bool:
	if once and Flags.check_flag(str(key)):
		return false
	if not key.is_empty() and (current.get("key") == key or queue.any(func(item: Dictionary): return item.key == key)):
		return false
	var regex := RegEx.new()
	regex.compile("\\S+")
	var words: Array[String] = []
	for found in regex.search_all(text):
		words.append(found.get_string().to_upper())
	if words.is_empty():
		return false
	var request: Dictionary = {"key": key, "words": words, "repeat": repeat, "priority": priority}
	if once and not key.is_empty():
		Flags.set_flag(str(key), true)
	if not current.is_empty() and priority > current.priority:
		queue.append(current)
		current = {}
	queue.append(request)
	queue.sort_custom(func(a: Dictionary, b: Dictionary): return a.priority > b.priority)
	if current.is_empty() and Blackboard.read_data("player_waking") != true:
		_start_next()
	return true

func cancel(key: StringName) -> void:
	queue = queue.filter(func(item: Dictionary): return item.key != key)
	if current.get("key") == key:
		current = {}
		hide()
		_start_next()

func _start_next() -> void:
	if Blackboard.read_data("player_waking") == true:
		return
	if queue.is_empty():
		current = {}
		hide()
		return
	current = queue.pop_front()
	word_index = 0
	_show_word()

func _show_word() -> void:
	label.text = current.words[word_index]
	_fit_word()
	remaining = maxf(.05, word_seconds)
	show()
	Audio.play_global(word_sound, sound_volume, 1.0, sound_bus)
	word_shown.emit(label.text, current.key)

func _fit_word() -> void:
	if label == null:
		return
	var font: Font = label.get_theme_font("font")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var max_width: float = get_viewport().get_visible_rect().size.x * .9
	label.add_theme_font_size_override("font_size", maxi(12, int(font_size * minf(1.0, max_width / maxf(1.0, width)))))

func _process(delta: float) -> void:
	if Blackboard.read_data("player_waking") == true:
		hide()
		return
	if current.is_empty():
		if not queue.is_empty():
			_start_next()
		return
	if word_index >= 0:
		show()
	remaining -= delta
	if remaining > 0:
		return
	word_index += 1
	if word_index >= current.words.size():
		if current.repeat:
			word_index = -1
			remaining = maxf(.05, phrase_gap)
			hide()
		else:
			var key: StringName = current.key
			current = {}
			message_finished.emit(key)
			_start_next()
	elif word_index >= 0:
		_show_word()

func _exit_tree() -> void:
	if Blackboard.read_data("world_messages") == self:
		Blackboard.remove_data("world_messages")
