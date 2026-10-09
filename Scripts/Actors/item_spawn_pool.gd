class_name item_spawn_pool
extends Resource

## Add one scene per item type. Each valid entry has an equal chance.
@export var items: Array[PackedScene] = []

func pick_item() -> PackedScene:
	var available: Array[PackedScene] = []
	for scene in items:
		if scene != null:
			available.append(scene)
	return available.pick_random() if not available.is_empty() else null
