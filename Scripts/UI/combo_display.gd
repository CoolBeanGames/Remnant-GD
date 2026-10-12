extends CanvasLayer

@export var payout_display_time: float = 2.0
var payout_time: float = 0.0
var last_count: int = 0
var pulse: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GrindCombo.combo_changed.connect(refresh)
	GrindCombo.combo_paid.connect(_show_payout)
	refresh()


func _process(delta: float) -> void:
	visible = not get_tree().paused and not Blackboard.read_data("player_input_blocked") and not DevTools.any_modal_open()
	if get_tree().paused:
		return
	payout_time = maxf(0.0, payout_time - delta)
	pulse = maxf(0.0, pulse - delta * 3.0)
	$Position/Panel.scale = Vector2.ONE
	if GrindCombo.item_count == 0 and payout_time == 0.0:
		$Position.hide()


func refresh() -> void:
	if GrindCombo.item_count == 0:
		last_count = 0
		return
	payout_time = 0.0
	$Position.show()
	if GrindCombo.item_count != last_count:
		pulse = 1.0
	last_count = GrindCombo.item_count
	$Position/Panel/Rows/Title.text = "COMBO / %.1f×" % GrindCombo.multiplier()
	$Position/Panel/Rows/Points.text = "%d items  ·  %d points" % [GrindCombo.item_count, GrindCombo.pending_points()]
	$Position/Panel/Rows/Countdown.text = "%.1fs" % GrindCombo.remaining


func _show_payout(points: int, multiplier: float, items: int) -> void:
	payout_time = payout_display_time
	pulse = 1.0
	$Position.show()
	$Position/Panel/Rows/Title.text = "EARNED +%d" % points
	$Position/Panel/Rows/Points.text = "%d items  ·  %.1f×" % [items, multiplier]
	$Position/Panel/Rows/Countdown.text = ""
