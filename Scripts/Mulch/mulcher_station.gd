class_name mulcher_station
extends StaticBody3D
var notice: String = ""
func _ready() -> void:
	Mulch.changed.connect(refresh)
	refresh()
func refresh() -> void:
	var cells: int = clampi(ceili(100 * Mulch.damage / maxf(1, Mulch.maximum_damage)), 0, 100)
	var grid: String = ""
	for i in 100:
		grid += "#" if i < cells else "."
		if i % 10 == 9:
			grid += "\n"
	$DamageGrid.text = grid
	$Status.text = "MULCH / %.0f / %.0f\n" % [Mulch.points, Mulch.points_per_pellet]
	if Mulch.repair_remaining > 0:
		$Status.text += "REPAIR / %.1f s" % Mulch.repair_remaining
	elif Mulch.broken():
		$Status.text += "BROKEN / REPAIR %d SCORE" % Mulch.repair_cost()
	else:
		$Status.text += "DAMAGE / %.0f / %.0f" % [Mulch.damage, Mulch.maximum_damage]
	if not notice.is_empty():
		$Status.text += "\n" + notice
func interact() -> void:
	notice = Mulch.repair()
	refresh()
func get_look_prompts() -> prompt_set:
	var result := prompt_set.new()
	var entry := prompt_entry.new()
	if Mulch.repair_remaining > 0:
		entry.text = "Repairing Mulcher / %.1f s" % Mulch.repair_remaining
	elif Mulch.broken():
		entry.text = "Repair Mulcher / %d Score" % Mulch.repair_cost()
		entry.action = &"confirm"
	else:
		entry.text = "Mulcher / Damage %.0f%%" % (100 * Mulch.damage / maxf(1, Mulch.maximum_damage))
	result.entries.append(entry)
	return result
