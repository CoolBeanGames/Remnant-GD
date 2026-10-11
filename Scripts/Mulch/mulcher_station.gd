class_name mulcher_station
extends StaticBody3D
var notice: String = ""
var displayed_cells: int = -1
var look_prompts: prompt_set = prompt_set.new()
var look_entry: prompt_entry = prompt_entry.new()
func _ready() -> void:
	look_prompts.entries.append(look_entry)
	Mulch.changed.connect(refresh)
	refresh()
func refresh() -> void:
	var cells: int = clampi(ceili(100 * Mulch.damage / maxf(1, Mulch.maximum_damage)), 0, 100)
	if displayed_cells != cells:
		displayed_cells = cells
		var grid: String = ""
		for i in 100:
			grid += "#" if i < cells else "."
			if i % 10 == 9:
				grid += "\n"
		$DamageGrid.text = grid
	var status: String = "MULCH / %.0f / %.0f\n" % [Mulch.points, Mulch.points_per_pellet]
	if Mulch.repair_remaining > 0:
		status += "REPAIR / %.1f s" % Mulch.repair_remaining
	elif Mulch.broken():
		status += "BROKEN / REPAIR %d SCORE" % Mulch.repair_cost()
	else:
		status += "DAMAGE / %.0f / %.0f" % [Mulch.damage, Mulch.maximum_damage]
	if not notice.is_empty():
		status += "\n" + notice
	if $Status.text != status:
		$Status.text = status
func interact() -> void:
	notice = Mulch.repair()
	refresh()
func get_look_prompts() -> prompt_set:
	look_entry.action = &""
	if Mulch.repair_remaining > 0:
		look_entry.text = "Repairing Mulcher / %.1f s" % Mulch.repair_remaining
	elif Mulch.broken():
		look_entry.text = "Repair Mulcher / %d Score" % Mulch.repair_cost()
		look_entry.action = &"confirm"
	else:
		look_entry.text = "Mulcher / Damage %.0f%%" % (100 * Mulch.damage / maxf(1, Mulch.maximum_damage))
	return look_prompts
