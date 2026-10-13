class_name item_spawn_pool
extends Resource

## Add one scene per item type. Each valid entry has an equal chance.
@export var items: Array[PackedScene] = []

func pick_item() -> PackedScene:
	if items.is_empty():
		return null
	# Normal authored pools contain valid scenes: avoid a temporary array per drop.
	var selected: PackedScene = items.pick_random()
	if selected != null:
		return selected
	# Null slots remain safe and equally weighted, even when edited at runtime.
	var available: Array[PackedScene] = []
	for scene in items:
		if scene != null:
			available.append(scene)
	return available.pick_random() if not available.is_empty() else null
