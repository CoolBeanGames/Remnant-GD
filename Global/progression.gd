extends Node

signal changed
signal purchased(entry: computer_entry, delivered: Node3D)
var entries: Dictionary = {}
var levels: Dictionary = {}
var restored_levels: bool = false

func register_catalog(catalog: computer_catalog) -> void:
	# Migrate old saves without hiding offers their existing score already unlocked.
	SaveGame.profile["lifetime_score"] = maxi(lifetime_score(), score())
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
			if not entry.completion_flag.is_empty():
				Flags.connect_to_flag(entry.completion_flag, [changed.emit], [changed.emit])
			if entry.tab in [computer_entry.Tab.MECHANICS, computer_entry.Tab.SELF] and not entry.unlock_flag.is_empty() and level(entry) > 0 and not Flags.check_flag(entry.unlock_flag):
				Flags.set_flag(entry.unlock_flag, true)
	Blackboard.store_data("upgrade_levels", levels.duplicate(true))
	apply_effects(GrindCombo, "combo")
	for handle in get_tree().get_nodes_in_group("manual-lever"):
		handle.refresh_upgrade()

func level(entry: computer_entry) -> int:
	return Mulch.upgrade_level(entry.id) if entry.tab == computer_entry.Tab.MULCH else int(levels.get(entry.id, 0))

func score() -> int:
	var value: Variant = Blackboard.read_data("score")
	return int(value) if value is int or value is float else 0

func lifetime_score() -> int:
	return maxi(score(), maxi(0, int(SaveGame.profile.get("lifetime_score", 0))))

func record_earned_score(amount: int) -> void:
	if amount > 0:
		SaveGame.profile["lifetime_score"] = maxi(score(), int(SaveGame.profile.get("lifetime_score", 0)) + amount)

func entry_visible(entry: computer_entry) -> bool:
	if not entry.memory_destination.is_empty():
		if level(entry) > 0:
			return false
		var saved: Variant = Blackboard.read_data("revealed_memories")
		var revealed: Dictionary = saved if saved is Dictionary else {}
		if score() >= ceili(entry.base_cost * .5) and not revealed.has(entry.id):
			revealed[entry.id] = true
			Blackboard.store_data("revealed_memories", revealed)
		return revealed.has(entry.id)
	return lifetime_score() >= entry.reveal_lifetime_score or level(entry) > 0 or (entry.installation == "mulcher" and Mulch.installed_unlock())

func purchase(entry: computer_entry, world: Node, spawn_point: Node3D, player: Node) -> String:
	if entry == null or entry.id == &"" or entries.get(entry.id) != entry:
		return "Unavailable entry."
	if entry.single_purchase and level(entry) > 0:
		return "Already purchased."
	if not entry_visible(entry) and level(entry) == 0:
		return "Earn more score to unlock this offer."
	if entry.tab != computer_entry.Tab.STORE and entry.max_level > 0 and level(entry) >= entry.max_level:
		if not entry.memory_destination.is_empty() and not Flags.check_flag(entry.completion_flag):
			return reopen_memory(entry)
		return "Upgrade complete."
	if entry.tab == computer_entry.Tab.MULCH:
		var result: String = Mulch.buy_upgrade(entry, player)
		if result.is_empty():
			purchased.emit(entry, null)
			changed.emit()
		return result
	if not entry.memory_destination.is_empty():
		if entry.completion_flag.is_empty():
			return "Memory completion flag missing."
		var blocked: String = memory_purchase_error(entry)
		if not blocked.is_empty():
			return blocked
	if entry.installation == "mulcher" and Mulch.installed_unlock():
		return "Mulcher already installed."
	var price: int = entry.cost(level(entry))
	if score() < price:
		return "Not enough score."
	if entry.tab in [computer_entry.Tab.MECHANICS, computer_entry.Tab.SELF]:
		if entry.effects.is_empty() and entry.unlock_flag.is_empty():
			return "Upgrade has no effects."
		if entry.tab == computer_entry.Tab.SELF and not entry.effects.is_empty() and not is_instance_valid(player):
			return "Player unavailable."
	if not entry.memory_destination.is_empty():
		var portal: door_portal = memory_portal(entry)
		if portal == null or not portal.open_memory(entry.id, entry.memory_destination):
			return "Memory portal unavailable."
	var actor: Node3D
	if entry.tab == computer_entry.Tab.STORE and entry.installation == "mulcher":
		if not Mulch.install():
			return "Grinder installation unavailable."
		levels[entry.id] = level(entry) + 1
	elif entry.tab == computer_entry.Tab.STORE and entry.installation == "mulch_bin":
		actor = Mulch.install_bin()
		if actor == null:
			return "Mulch Bin mount unavailable."
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
		levels[entry.id] = level(entry) + 1
		apply_player(player)
		apply_effects(Mulch, "mulcher")
		apply_effects(GrindCombo, "combo")
		for spawner in get_tree().get_nodes_in_group("automatic-spawner"):
			spawner.refresh_upgrade()
		for handle in get_tree().get_nodes_in_group("manual-lever"):
			handle.refresh_upgrade()
	Blackboard.store_data("score", score() - price)
	Blackboard.store_data("upgrade_levels", levels.duplicate(true))
	if entry.tab in [computer_entry.Tab.MECHANICS, computer_entry.Tab.SELF] and not entry.unlock_flag.is_empty():
		Flags.set_flag(entry.unlock_flag, true)
	purchased.emit(entry, actor)
	changed.emit()
	DevTools.log_info("Purchased %s / tier %d / %d score" % [entry.id, level(entry), price], "upgrades")
	return ""

func pending_memory() -> computer_entry:
	for entry: computer_entry in entries.values():
		if not entry.memory_destination.is_empty() and level(entry) > 0 and not Flags.check_flag(entry.completion_flag):
			return entry
	return null

func memory_purchase_error(entry: computer_entry) -> String:
	var unfinished: computer_entry = pending_memory()
	if unfinished != null and unfinished != entry:
		return "Complete %s first." % unfinished.title
	return ""

func memory_portal(entry: computer_entry) -> door_portal:
	for node in get_tree().get_nodes_in_group("story-portal"):
		if node is door_portal and not node.inside and not node.suspended and not node.switching and not node.closing_memory and Flags.check_flag(node.activation_flag) and node._destination(entry.memory_destination) != null:
			return node
	return null

func memory_is_open(entry: computer_entry) -> bool:
	for node in get_tree().get_nodes_in_group("story-portal"):
		if node is door_portal and node.active and node.memory_id == entry.id:
			return true
	return false

func reopen_memory(entry: computer_entry) -> String:
	if memory_is_open(entry):
		return "Memory already open."
	var portal: door_portal = memory_portal(entry)
	if portal == null or not portal.open_memory(entry.id, entry.memory_destination):
		return "Memory portal unavailable."
	changed.emit()
	DevTools.log_info("Reopened %s without another charge." % entry.id, "memories")
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
