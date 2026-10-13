extends Node
signal changed
signal pellet_produced(pellet: Node3D)
signal coins_changed(coins: int)
@export var points_per_pellet: float = 100.0
@export var base_maximum_damage: float = 100.0
@export var base_efficiency: float = 1.0
var maximum_damage: float = 100.0
var efficiency: float = 1.0
## Permanent collector permission is applied through editable upgrade effects.
var automatic_collection: bool = false
@export var damage_per_item: float = 1.0
@export var repair_seconds: float = 4.0
@export var repair_base_cost: int = 100
@export var repair_cost_multiplier: float = 1.6
@export var pellet_scene: PackedScene = preload("res://Scenes/Mulch/mulch_pellet.tscn")
var points: float = 0.0
var damage: float = 0.0
var repairs: int = 0
var repair_remaining: float = 0.0
var level: Node3D
var station: Node3D
var bin: mulch_bin
## FIFO contributions conserve each item's half-score across pellet boundaries.
var contributions: Array[Dictionary] = []
var emission_pending: bool = false

func _ready() -> void:
	restore()

func restore() -> void:
	points = maxf(0, float(Blackboard.read_data("mulch_points") if Blackboard.data_exists("mulch_points") else 0))
	damage = maxf(0, float(Blackboard.read_data("mulcher_damage") if Blackboard.data_exists("mulcher_damage") else 0))
	repairs = maxi(0, int(Blackboard.read_data("mulcher_repairs") if Blackboard.data_exists("mulcher_repairs") else 0))
	repair_remaining = maxf(0, float(Blackboard.read_data("mulcher_repair_remaining") if Blackboard.data_exists("mulcher_repair_remaining") else 0))
	maximum_damage = maxf(1, base_maximum_damage)
	efficiency = maxf(0, base_efficiency)
	automatic_collection = false
	contributions.clear()
	var saved: Variant = Blackboard.read_data("mulch_contributions")
	var accounted: float = 0.0
	if saved is Array:
		for entry in saved:
			if not entry is Dictionary or not (entry.get("points") is float or entry.get("points") is int) or not (entry.get("score") is float or entry.get("score") is int):
				continue
			var contribution_points: float = float(entry.points)
			var contribution_score: float = float(entry.score)
			if not is_finite(contribution_points) or not is_finite(contribution_score) or contribution_points <= 0 or accounted >= points:
				continue
			var accepted: float = minf(contribution_points, points - accounted)
			contributions.append({"points": accepted, "score": maxf(0, contribution_score) * accepted / contribution_points})
			accounted += accepted
	# Legacy pending points have no recorded score; do not invent historical value.
	if accounted < points:
		contributions.push_front({"points": points - accounted, "score": 0.0})
	if has_meta("upgrade_base_values"):
		remove_meta("upgrade_base_values")
	changed.emit()
	coins_changed.emit(coins())

func coins() -> int:
	return maxi(0, int(SaveGame.profile.get("mulch_coins", 0)))

func upgrade_level(id: StringName) -> int:
	return int(SaveGame.profile.get("mulch_upgrades", {}).get(id, 0))

## Profile-owned story permission, available before any terminal binds its catalog.
func prestige_items_unlocked() -> bool:
	return upgrade_level(&"grind_additional_items") > 0

func tab_unlocked() -> bool:
	return Flags.check_flag("mulcher purchased") and Flags.check_flag("mulch bin purchased")

func installed_unlock() -> bool:
	return bool(SaveGame.profile.get("mulcher_unlocked", false)) or Flags.check_flag("mulcher purchased")

func bind_level(root: Node3D) -> void:
	level = root
	restore()
	Progression.apply_effects(self, "mulcher")
	if installed_unlock():
		install()
		_schedule_pellets()
	if Flags.check_flag("mulch bin purchased"):
		install_bin.call_deferred()

func install() -> bool:
	if not is_instance_valid(level) or not level.is_inside_tree():
		return false
	if not is_instance_valid(station) or not level.is_ancestor_of(station):
		station = load("res://Scenes/Mulch/mulcher_station.tscn").instantiate()
		level.add_child(station)
		var grinder: Area3D = level.get_node_or_null("grinding_area")
		var origin: Vector3 = grinder.global_position if grinder != null else level.global_position
		var mount: Node3D = grinder.get_node_or_null("MulcherMount") if grinder != null else null
		station.global_transform = mount.global_transform if mount != null else Transform3D(Basis.IDENTITY, origin + Vector3(2.0, .55, 1.4))
	Flags.set_flag("mulcher purchased", true)
	SaveGame.profile["mulcher_unlocked"] = true
	SaveGame.save_profile()
	changed.emit()
	return true

func broken() -> bool:
	return damage >= maxf(1, maximum_damage)

## New and saved portable bins share one fixed, designer-editable mount.
func install_bin() -> mulch_bin:
	if not is_instance_valid(level) or not level.is_inside_tree():
		return null
	bin = null
	for candidate in get_tree().get_nodes_in_group("mulch-bin"):
		if not candidate is mulch_bin or not level.is_ancestor_of(candidate) or candidate.is_queued_for_deletion():
			continue
		if bin == null:
			bin = candidate
		else:
			WorldState.untrack(candidate)
			candidate.queue_free()
	if bin == null:
		bin = load("res://Scenes/Mulch/mulch_bin.tscn").instantiate()
		level.add_child(bin)
	var grinder: Node3D = level.get_node_or_null("grinding_area")
	var mount: Node3D = grinder.get_node_or_null("MulchBinMount") if grinder != null else null
	var origin: Vector3 = grinder.global_position if grinder != null else level.global_position
	bin.global_transform = mount.global_transform if mount != null else Transform3D(Basis.IDENTITY, origin + Vector3(3.55, .08, 1.4))
	portal_space.apply_actor(bin, false)
	WorldState.track(bin)
	Flags.set_flag("mulch bin purchased", true)
	changed.emit()
	return bin

func consume(item: Node3D, score_value: float = -1.0) -> void:
	if not Flags.check_flag("mulcher purchased") or broken() or repair_remaining > 0:
		return
	var value: int = 1
	var component: score_object = physics_items.score_component(item)
	if component != null:
		value = component.mulch_value
	else:
		value = int(item.get_meta("mulch_value", 1))
	if score_value < 0:
		score_value = component.score if component != null else (1 if item.is_in_group("score") else 0)
	var produced: float = clampi(value, 1, 5) * maxf(0, efficiency)
	if produced > 0:
		points += produced
		contributions.append({"points": produced, "score": maxf(0, score_value) * .5})
	damage = minf(maximum_damage, damage + maxf(0, damage_per_item))
	_schedule_pellets()
	_store()

func _schedule_pellets() -> void:
	if not emission_pending and points >= maxf(1, points_per_pellet):
		emission_pending = true
		_emit_pellets.call_deferred()

func _emit_pellets() -> void:
	emission_pending = false
	var index: int = 0
	while points >= maxf(1, points_per_pellet) and is_instance_valid(level) and level.is_inside_tree() and not level.is_queued_for_deletion() and is_instance_valid(station):
		var output: Node3D = station.get_node("Output")
		var pose: Transform3D = output.global_transform
		pose.origin += output.global_basis * Vector3((index % 3) * .28, 0, floorf(float(index) / 3.0) * .28)
		index += 1
		var pellet: Node3D = WorldState.spawn_item(pellet_scene, level, pose)
		if pellet == null:
			return
		var consumed_points: float = maxf(1, points_per_pellet)
		if pellet is mulch_pellet:
			pellet.stored_score = _take_score(consumed_points)
		points = maxf(0, points - consumed_points)
		if pellet is RigidBody3D:
			pellet.linear_velocity = station.global_basis * Vector3(0, 1.5, 2.5)
		pellet_produced.emit(pellet)
		# Deferred output runs outside physics callbacks; never bank a held pellet.
		if automatic_collection and Flags.check_flag("mulch bin purchased"):
			deposit(pellet, false)
	if index > 0:
		_store()
		if automatic_collection:
			SaveGame.save_profile()
		DevTools.log_info("Produced %d mulch pellets" % index, "mulch")

func _take_score(amount: float) -> float:
	var result: float = 0.0
	while amount > 0 and not contributions.is_empty():
		var entry: Dictionary = contributions[0]
		var consumed: float = minf(amount, float(entry.points))
		var share: float = float(entry.score) * consumed / float(entry.points)
		result += share
		amount -= consumed
		if consumed >= float(entry.points):
			contributions.pop_front()
		else:
			entry.points -= consumed
			entry.score = maxf(0, float(entry.score) - share)
	return result

func repair_cost() -> int:
	return int(minf(2147483647, ceil(repair_base_cost * pow(repair_cost_multiplier, repairs))))

func repair() -> String:
	if not broken():
		return "Mulcher does not need repair."
	if repair_remaining > 0:
		return "Repair already in progress."
	if Progression.score() < repair_cost():
		return "Not enough score."
	Blackboard.store_data("score", Progression.score() - repair_cost())
	repair_remaining = maxf(.01, repair_seconds)
	_store()
	DevTools.log_info("Mulcher repair started / %d score / %.1f seconds" % [repair_cost(), repair_remaining], "mulch")
	return ""

func _process(delta: float) -> void:
	if repair_remaining > 0 and is_instance_valid(level) and level.is_inside_tree():
		repair_remaining = maxf(0, repair_remaining - delta)
		if repair_remaining <= 0:
			damage = 0
			repairs += 1
			DevTools.log_info("Mulcher repair finished / repairs %d" % repairs, "mulch")
		_store()

func _store() -> void:
	Blackboard.store_data("mulch_points", points)
	Blackboard.store_data("mulch_contributions", contributions.duplicate(true))
	Blackboard.store_data("mulcher_damage", damage)
	Blackboard.store_data("mulcher_repairs", repairs)
	Blackboard.store_data("mulcher_repair_remaining", repair_remaining)
	changed.emit()

func deposit(pellet: Node3D, persist: bool = true) -> bool:
	if not is_instance_valid(pellet) or not pellet.is_in_group("mulch-pellet") or pellet.is_queued_for_deletion() or pellet.get_meta("banked", false) or pellet.get_meta("carried_by_player", false):
		return false
	pellet.set_meta("banked", true)
	SaveGame.profile["mulch_coins"] = coins() + maxi(1, int(pellet.get("coin_value")))
	WorldState.untrack(pellet)
	pellet.queue_free()
	coins_changed.emit(coins())
	changed.emit()
	if persist:
		SaveGame.save_profile()
	return true

func buy_upgrade(entry: computer_entry, player: Node) -> String:
	if not tab_unlocked():
		return "Buy the Mulcher and Mulch Bin first."
	var requirement: String = Progression.purchase_requirement_error(entry)
	if not requirement.is_empty():
		return requirement
	var price: int = entry.cost(upgrade_level(entry.id))
	if coins() < price:
		return "Not enough mulch coins."
	var levels: Dictionary = SaveGame.profile.get("mulch_upgrades", {}).duplicate(true)
	levels[entry.id] = upgrade_level(entry.id) + 1
	SaveGame.profile["mulch_upgrades"] = levels
	SaveGame.profile["mulch_coins"] = coins() - price
	Progression.apply_player(player)
	Progression.apply_effects(self, "mulcher")
	for handle in get_tree().get_nodes_in_group("manual-lever"):
		handle.refresh_upgrade()
	for spawner in get_tree().get_nodes_in_group("automatic-spawner"):
		spawner.refresh_upgrade()
	if automatic_collection and is_instance_valid(level) and Flags.check_flag("mulch bin purchased"):
		_collect_existing.call_deferred()
	SaveGame.save_profile()
	coins_changed.emit(coins())
	changed.emit()
	DevTools.log_info("Purchased permanent %s / tier %d / %d mulch coins" % [entry.id, upgrade_level(entry.id), price], "upgrades")
	return ""

func _collect_existing() -> void:
	if not automatic_collection or not is_instance_valid(bin):
		return
	var count: int = 0
	for actor in get_tree().get_nodes_in_group("mulch-pellet"):
		if level.is_ancestor_of(actor) and not actor.get_meta("portal_inside", false) and deposit(actor, false):
			count += 1
	if count > 0:
		SaveGame.save_profile()
		DevTools.log_info("Collector banked %d loose pellets" % count, "mulch")
