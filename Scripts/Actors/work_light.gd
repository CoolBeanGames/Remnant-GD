extends switchable_prop

func _apply_power() -> void:
	for lamp in find_children("*", "Light3D", true, false):
		lamp.visible = powered
