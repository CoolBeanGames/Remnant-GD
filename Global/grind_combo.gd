extends Node

signal combo_changed
signal combo_paid(points: int, multiplier: float, items: int)

@export var initial_window: float = 3.0
@export var window_decrease: float = 0.4
@export var minimum_window: float = 0.5
@export var multiplier_step: float = 0.5

var item_count: int = 0
var base_points: int = 0
var remaining: float = 0.0
var current_window: float = 0.0


func _process(delta: float) -> void:
	if item_count == 0:
		return
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		finish_combo()
	else:
		combo_changed.emit()


func multiplier() -> float:
	return 1.0 + maxi(0, item_count - 1) * maxf(0.0, multiplier_step)


func pending_points() -> int:
	return roundi(base_points * multiplier())


## Every destroyed item advances the chain; only scoring items add base value.
func record_item(points: int) -> void:
	item_count += 1
	base_points += maxi(0, points)
	current_window = maxf(maxf(minimum_window, 0.05), initial_window - (item_count - 1) * maxf(0.0, window_decrease))
	remaining = current_window
	combo_changed.emit()


func finish_combo() -> void:
	if item_count == 0:
		return
	var points: int = pending_points()
	var final_multiplier: float = multiplier()
	var count: int = item_count
	reset()
	if points > 0:
		ScoreRewards.enqueue(points)
	combo_paid.emit(points, final_multiplier, count)


func reset() -> void:
	item_count = 0
	base_points = 0
	remaining = 0.0
	current_window = 0.0
	combo_changed.emit()
