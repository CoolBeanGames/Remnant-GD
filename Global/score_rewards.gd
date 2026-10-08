extends Node

## Shared queue: multiple items and grinding areas extend the same count-up.
@export var score_sound: AudioStream = preload("res://Audio/SFX/Score.wav")
@export var score_volume: float = 2.0
@export var point_interval: float = 0.5
@export var interval_decrease: float = 0.02

var pending_points: int = 0
var _timer: Timer
var _next_point_time_usec: int = 0
var _current_interval: float = 0.5


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_award_next_point)
	add_child(_timer)
	_current_interval = point_interval


func enqueue(amount: int) -> void:
	if amount <= 0:
		return
	if pending_points == 0:
		_current_interval = point_interval
	pending_points += amount
	if _timer.is_stopped():
		_award_next_point()


func _award_next_point() -> void:
	if pending_points <= 0:
		return
	var now: int = Time.get_ticks_usec()
	if now < _next_point_time_usec:
		_timer.start(float(_next_point_time_usec - now) / 1000000.0)
		return
	_current_interval -= maxf(interval_decrease, 0.0)
	# At zero delay, award the remaining queue in one update and sound.
	var amount: int = pending_points if _current_interval <= 0.000001 else 1
	pending_points -= amount
	var total: Variant = Blackboard.read_data("score")
	if not (total is int or total is float):
		total = 0
	Blackboard.store_data("score", total + amount)
	Audio.play_global(score_sound, score_volume, 1.0, &"SFX")
	if pending_points == 0:
		_timer.stop()
		_next_point_time_usec = 0
		_current_interval = point_interval
		return
	_next_point_time_usec = now + int(_current_interval * 1000000.0)
	_timer.start(_current_interval)
