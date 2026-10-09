extends Node

signal changed
signal purchased(entry: computer_entry, delivered: Node3D)
var entries: Dictionary = {}
var levels: Dictionary = {}
var restored_levels: bool = false

func register_catalog(catalog: computer_catalog) -> void:
	if not restored_levels:
		var saved: Variant = Blackboard.read_data("upgrade_levels")
		if saved is Dictionary:
			levels = saved.duplicate(true)
		restored_levels = true
	if catalog == null:
		return
	for entry in catalog.entries:
		if entry != null and entry.id != &"":
			entries[entry.id] = entry
	Blackboard.store_data("upgrade_levels", levels.duplicate(true))

func level(entry: computer_entry) -> int:
	return Mulch.upgrade_level(entry.id) if entry.tab == computer_entry.Tab.MULCH else int(levels.get(entry.id, 0))

func score() -> int:
	var value: Variant = Blackboard.read_data("score")
	return int(value) if value is int or value is float else 0

func purchase(entry: computer_entry, world: Node, spawn_point: Node3D, player: Node) -> String:
	if entry == null or entry.id == &"" or entries.get(entry.id) != entry:
		return "Unavailable entry."
	if entry.tab != computer_entry.Tab.STORE and entry.max_level > 0 and level(entry) >= entry.max_level:
		return "Upgrade complete."
	if entry.tab == computer_entry.Tab.MULCH:
		var result: String = Mulch.buy_upgrade(entry, player)
		if result.is_empty():
			purchased.emit(entry, null)
			changed.emit()
		return result
	if entry.installation == "mulcher" and Flags.check_flag("mulcher purchased"):
		return "Mulcher already installed."
	var price: int = entry.cost(level(entry))
	if score() < price:
		return "Not enough score."
	var actor: Node3D
	if entry.tab == computer_entry.Tab.STORE and entry.installation == "mulcher":
		if not Mulch.install():
			return "Grinder installation unavailable."
		levels[entry.id] = level(entry) + 1
	elif entry.tab == computer_entry.Tab.STORE:
		if entry.delivery_scene == null or not is_instance_valid(world) or not world.is_inside_tree() or not is_instance_valid(spawn_point):
			return "Delivery unavailable."
		var instance: Node = entry.delivery_scene.instantiate()
		if not instance is Node3D:
			instance.free()
			return "Delivery scene must be 3D."
		actor = instance as Node3D
		apply_new_prop(actor, entry.delivery_kind)
		world.add_child(actor)
		actor.global_position = spawn_point.global_position
		WorldState.track(actor)
		levels[entry.id] = level(entry) + 1
		if entry.installation == "mulch_bin":
			Flags.set_flag("mulch bin purchased", true)
	else:
		if entry.effects.is_empty():
			return "Upgrade has no effects."
		if entry.tab == computer_entry.Tab.SELF and not is_instance_valid(player):
			return "Player unavailable."
		levels[entry.id] = level(entry) + 1
		apply_player(player)
		apply_effects(Mulch, "mulcher")
		for spawner in get_tree().get_nodes_in_group("automatic-spawner"):
			spawner.refresh_upgrade()
	Blackboard.store_data("score", score() - price)
	Blackboard.store_data("upgrade_levels", levels.duplicate(true))
	purchased.emit(entry, actor)
	changed.emit()
	return ""

## Baselines prevent repeated application when opening a second terminal or buying another tier.
func apply_effects(node: Object, kind: String) -> void:
	if node == null:
		return
	var bases: Dictionary = node.get_meta("upgrade_base_values", {})
	for entry: computer_entry in entries.values():
		for effect in entry.effects:
			if effect != null and effect.target == kind:
				var key: String = str(effect.property)
				if not bases.has(key):
					var value: Variant = node.get_indexed(effect.property)
					if value is int or value is float or value is bool:
						bases[key] = value
	for key in bases:
		node.set_indexed(NodePath(key), bases[key])
	for entry: computer_entry in entries.values():
		for effect in entry.effects:
			if effect != null and effect.target == kind and bases.has(str(effect.property)):
				for tier in level(entry):
					node.set_indexed(effect.property, effect.apply_value(node.get_indexed(effect.property)))
	node.set_meta("upgrade_base_values", bases)

func apply_player(player: Node) -> void:
	if not is_instance_valid(player):
		return
	apply_effects(player.get_node_or_null("Controllers/Player_Move_Controller"), "movement")
	apply_effects(player.get_node_or_null("Controllers/Player_Pickup"), "pickup")

func apply_new_prop(actor: Node3D, kind: String) -> void:
	if kind == "none":
		return
	if actor is RigidBody3D and actor.physics_material_override != null:
		actor.physics_material_override = actor.physics_material_override.duplicate()
	apply_effects(actor, kind)

func apply_spawned_value(actor: Node3D) -> void:
	var component: score_object = physics_items.score_component(actor)
	if component == null:
		component = score_object.new()
		actor.add_child(component)
	apply_effects(component, "item_value")
