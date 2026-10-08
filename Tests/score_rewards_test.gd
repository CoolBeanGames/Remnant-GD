extends Node

class RecordingPlayer extends audio_player:
	func _ready() -> void:
		pass

	func play_global(stream: AudioStream, volume: float = 1.0, pitch: float = 1.0, bus: StringName = &"Master") -> void:
		get_parent().events.append({"stream": stream, "volume": volume, "pitch": pitch, "bus": bus, "time": Time.get_ticks_msec()})

class RecordingPool extends object_pool:
	var events: Array[Dictionary] = []

	func _create_object() -> Node:
		var player := RecordingPlayer.new()
		add_child(player)
		return player

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var pool := RecordingPool.new()
	pool.register_with_blackboard = true
	pool.blackboard_name = &"audio_pool"
	add_child(pool)
	Blackboard.store_data("score", 10)
	var grinder := grinding_area.new()
	add_child(grinder)
	var item := RigidBody3D.new()
	item.add_to_group("score")
	var points := score_object.new()
	points.score = 3
	item.add_child(points)
	add_child(item)
	check(grinder.grind(item), "Scored item must be ground.")
	check(Blackboard.read_data("score") == 11 and ScoreRewards.pending_points == 2, "Only the first point should be awarded immediately.")
	check(not grinder.grind(item), "Duplicate grinding must not enqueue rewards or replay grind audio.")
	await get_tree().create_timer(0.2).timeout
	check(Blackboard.read_data("score") == 11, "The next point must wait for its accelerated delay.")
	var extra := RigidBody3D.new()
	extra.add_to_group("score")
	add_child(extra)
	grinder.grind(extra)
	check(Blackboard.read_data("score") == 11 and ScoreRewards.pending_points == 3, "New rewards must extend the queue without bypassing its cooldown.")
	while ScoreRewards.pending_points > 0:
		await get_tree().process_frame
	check(Blackboard.read_data("score") == 14, "Queued rewards must eventually award all four points.")
	var ticks: Array[Dictionary] = []
	var grinds: int = 0
	for event in pool.events:
		check(event.bus == &"SFX", "Both sounds must use the SFX bus through the audio pool.")
		if event.stream == ScoreRewards.score_sound:
			ticks.append(event)
			check(event.volume == 2.0, "Score sound should play loudly at double linear volume.")
		elif event.stream == grinder.grind_sound:
			grinds += 1
	check(ticks.size() == 4 and grinds == 2, "Play one score sound per point and one grind sound per item.")
	for index in range(1, ticks.size()):
		var expected_delay: float = 500.0 - 20.0 * index
		var actual_delay: int = ticks[index].time - ticks[index - 1].time
		check(actual_delay >= expected_delay - 10 and actual_delay <= expected_delay + 70, "Score delay must decrease by .02 each point: " + str(actual_delay))
	check(ScoreRewards._timer.is_stopped() and is_equal_approx(ScoreRewards._current_interval, 0.5), "Empty queues must reset the timer and starting delay.")
	var unscored := RigidBody3D.new()
	add_child(unscored)
	var count: int = pool.events.size()
	grinder.grind(unscored)
	check(pool.events.size() == count + 1 and Blackboard.read_data("score") == 14, "Unscored grinding plays its sound without awarding points.")
	ScoreRewards.enqueue(0)
	ScoreRewards.enqueue(-2)
	check(ScoreRewards.pending_points == 0, "Nonpositive rewards must not add count-up ticks.")
	# Shorten the starting delay to exercise the zero-delay flush quickly.
	ScoreRewards.point_interval = 0.06
	var before_batch: int = pool.events.size()
	ScoreRewards.enqueue(20)
	check(Blackboard.read_data("score") == 15 and ScoreRewards.pending_points == 19, "Large queues must begin with one point.")
	while ScoreRewards.pending_points > 0:
		await get_tree().process_frame
	check(Blackboard.read_data("score") == 34, "Reaching zero delay must award every remaining point.")
	check(pool.events.size() == before_batch + 3, "The final batch must play one sound instead of a simultaneous sound per remaining point.")
	check(ScoreRewards._timer.is_stopped() and is_equal_approx(ScoreRewards._current_interval, 0.06), "Batch completion must reset the timer.")
	ScoreRewards.enqueue(2)
	check(Blackboard.read_data("score") == 35 and ScoreRewards.pending_points == 1, "A fresh queue must restart at its base delay after a flush.")
	while ScoreRewards.pending_points > 0:
		await get_tree().process_frame
	ScoreRewards.point_interval = 0.01
	ScoreRewards.enqueue(5)
	check(Blackboard.read_data("score") == 41 and ScoreRewards.pending_points == 0, "A delay below zero must also flush the entire queue.")
	ScoreRewards.point_interval = 0.5
	var real_pool := object_pool.new()
	real_pool.pooled_scene = preload("res://Scenes/audio_player.tscn")
	real_pool.reset_method = &"reset"
	add_child(real_pool)
	Blackboard.store_data("audio_pool", real_pool)
	Audio.play_global(ScoreRewards.score_sound, 2.0, 1.0, &"SFX")
	check(real_pool.active.size() == 1, "Global playback must acquire a real pooled audio player.")
	var actual := real_pool.active[0] as audio_player
	check(actual.audio_global.stream == ScoreRewards.score_sound and actual.audio_global.bus == &"SFX", "Real global audio must use the selected sound and SFX bus.")
	check(is_equal_approx(actual.audio_global.volume_db, linear_to_db(2.0)), "Loud score playback must reach the actual player volume.")
	actual.playback_finished.emit()
	check(real_pool.active.is_empty() and real_pool.available.size() == 1, "Finished audio must return to the pool.")
	Blackboard.remove_data("audio_pool")
	real_pool.queue_free()
	pool.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	print("Score rewards/audio checks: ", "PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
