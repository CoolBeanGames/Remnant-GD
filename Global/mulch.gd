extends Node
signal changed
signal pellet_produced(pellet: Node3D)
signal coins_changed(coins: int)
@export var points_per_pellet: float = 100.0
@export var base_maximum_damage: float = 100.0
@export var base_efficiency: float = 1.0
var maximum_damage: float = 100.0
var efficiency: float = 1.0
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

func consume(item: Node3D) -> void:
	if not Flags.check_flag("mulcher purchased") or broken() or repair_remaining > 0:
		return
	var value: int = 1
	var component: score_object = physics_items.score_component(item)
	if component != null:
		value = component.mulch_value
	else:
		value = int(item.get_meta("mulch_value", 1))
	points += clampi(value, 1, 5) * maxf(0, efficiency)
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
		points -= maxf(1, points_per_pellet)
		if pellet is RigidBody3D:
			pellet.linear_velocity = station.global_basis * Vector3(0, 1.5, 2.5)
		pellet_produced.emit(pellet)
	if index > 0:
		_store()
		DevTools.log_info("Produced %d mulch pellets" % index, "mulch")

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
	Blackboard.store_data("mulcher_damage", damage)
	Blackboard.store_data("mulcher_repairs", repairs)
	Blackboard.store_data("mulcher_repair_remaining", repair_remaining)
	changed.emit()

func deposit(pellet: Node3D) -> bool:
	if not is_instance_valid(pellet) or not pellet.is_in_group("mulch-pellet") or pellet.is_queued_for_deletion() or pellet.get_meta("banked", false):
		return false
	pellet.set_meta("banked", true)
	SaveGame.profile["mulch_coins"] = coins() + maxi(1, int(pellet.get("coin_value")))
	WorldState.untrack(pellet)
	pellet.queue_free()
	coins_changed.emit(coins())
	changed.emit()
	SaveGame.save_profile()
	return true

func buy_upgrade(entry: computer_entry, player: Node) -> String:
	if not tab_unlocked():
		return "Buy the Mulcher and Mulch Bin first."
	var price: int = entry.cost(upgrade_level(entry.id))
	if coins() < price:
		return "Not enough mulch coins."
	var levels: Dictionary = SaveGame.profile.get("mulch_upgrades", {}).duplicate(true)
	levels[entry.id] = upgrade_level(entry.id) + 1
	SaveGame.profile["mulch_upgrades"] = levels
	SaveGame.profile["mulch_coins"] = coins() - price
	Progression.apply_player(player)
	Progression.apply_effects(self, "mulcher")
	for spawner in get_tree().get_nodes_in_group("automatic-spawner"):
		spawner.refresh_upgrade()
	SaveGame.save_profile()
	coins_changed.emit(coins())
	changed.emit()
	DevTools.log_info("Purchased permanent %s / tier %d / %d mulch coins" % [entry.id, upgrade_level(entry.id), price], "upgrades")
	return ""
