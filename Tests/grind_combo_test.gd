extends Node

class RecordingPlayer extends audio_player:
	static var calls: Array[Dictionary] = []
	func _ready() -> void:
		pass
	func play_global(stream: AudioStream, volume: float = 1.0, _pitch: float = 1.0, bus: StringName = &"Master") -> void:
		calls.append({"stream": stream, "volume": volume, "bus": bus})
		playback_finished.emit()

class RecordingPool extends object_pool:
	func _create_object() -> Node:
		var sound := RecordingPlayer.new()
		add_child(sound)
		return sound

var failures: Array[String] = []
var payouts: Array[int] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var pool := RecordingPool.new()
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	GrindCombo.combo_paid.connect(func(points: int, _mult: float, _items: int): payouts.append(points))
	GrindCombo.reset()
	ScoreRewards.reset()
	GrindCombo.set_process(false)
	ScoreRewards.set_process(false)
	Blackboard.store_data("score", 100)
	var ui: CanvasLayer = load("res://Scenes/UI/combo_display.tscn").instantiate()
	add_child(ui)
	check(not ui.get_node("Position").visible, "Combo popup must initially be hidden.")
	GrindCombo.record_item(10)
	check(is_equal_approx(GrindCombo.multiplier(), 1.0) and GrindCombo.remaining == 3.0 and Blackboard.read_data("score") == 100, "First item starts 1.0x and three seconds without awarding score.")
	check(ui.get_node("Position").visible and "1.0" in ui.get_node("Position/Panel/Rows/Title").text, "First grind must pop up the live multiplier.")
	GrindCombo._process(1.0)
	GrindCombo.record_item(10)
	check(is_equal_approx(GrindCombo.multiplier(), 1.5) and is_equal_approx(GrindCombo.remaining, 2.6) and GrindCombo.pending_points() == 30, "Next item refreshes a shorter window and adds 0.5x.")
	check(not ui.get_node("Position/Panel/Rows").has_node("Time") and not ui.get_node("Position/Panel") is PanelContainer, "Combo UI must contain only text, no panel or bar.")
	GrindCombo._process(2.61)
	check(Blackboard.read_data("score") == 101 and ScoreRewards.pending_points == 29 and payouts == [30] and GrindCombo.item_count == 0, "Expiry queues the chain, awards only its first point and resets it.")
	check(RecordingPlayer.calls.size() == 1 and RecordingPlayer.calls[0].bus == &"SFX" and RecordingPlayer.calls[0].volume == 2.0, "Banked score must play one loud SFX sound.")
	check("+30" in ui.get_node("Position/Panel/Rows/Title").text, "Payout popup must show the banked total.")
	ui._process(2.1)
	check(not ui.get_node("Position").visible, "Payout popup must disappear after its display duration.")
	GrindCombo._process(10.0)
	check(payouts == [30], "Expired chains must never award twice.")
	while ScoreRewards.pending_points > 0:
		ScoreRewards._process(1.0)
	check(Blackboard.read_data("score") == 130, "The point queue must finish at the earned total.")
	GrindCombo.record_item(2)
	check(GrindCombo.remaining == 3.0 and is_equal_approx(GrindCombo.multiplier(), 1.0), "A new chain must restore the starting window and multiplier.")
	for i in 30:
		GrindCombo.record_item(1)
	check(GrindCombo.remaining == 0.5, "Long chains must retain a positive minimum window.")
	GrindCombo.reset()
	GrindCombo.initial_window = .08
	GrindCombo.minimum_window = .05
	GrindCombo.record_item(10)
	GrindCombo.set_process(true)
	await get_tree().create_timer(.15).timeout
	check(Blackboard.read_data("score") == 131 and ScoreRewards.pending_points == 9 and payouts == [30, 10], "Actual frame countdown must expire and award a fresh chain.")
	ui.queue_free()
	await get_tree().process_frame
	print("Combo countdown/audio/UI: ", "PASS" if failures.is_empty() else str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
