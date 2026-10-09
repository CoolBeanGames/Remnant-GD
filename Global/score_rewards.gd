extends Node
@export var score_sound: AudioStream = preload("res://Audio/SFX/Score.wav")
@export var score_volume: float = 2.0
@export var point_interval: float = 0.5
@export var interval_decrease: float = 0.02
var pending_points: int = 0
var current_interval: float = 0.5
var remaining: float = 0.0

func enqueue(points: int) -> void:
	if points <= 0:
		return
	var idle: bool = pending_points == 0
	pending_points += points
	if idle:
		current_interval = point_interval
		_award()

func _process(delta: float) -> void:
	if pending_points == 0:
		return
	remaining -= delta
	if remaining <= 0.0:
		current_interval -= maxf(0.0, interval_decrease)
		_award()

func _award() -> void:
	var amount: int = pending_points if current_interval <= 0.000001 else 1
	pending_points -= amount
	var score: Variant = Blackboard.read_data("score")
	if not (score is int or score is float):
		score = 0
	Blackboard.store_data("score", score + amount)
	Audio.play_global(score_sound, score_volume, 1.0, &"SFX")
	if pending_points == 0:
		reset()
	else:
		remaining = current_interval

func reset() -> void:
	pending_points = 0
	remaining = 0.0
	current_interval = point_interval
