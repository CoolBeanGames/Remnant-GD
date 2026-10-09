class_name computer_entry
extends Resource

enum Tab { MECHANICS, SELF, STORE, MULCH }
@export var id: StringName
@export var title: String = "Upgrade"
@export_multiline var description: String
@export var tab: Tab = Tab.MECHANICS
@export_range(0, 1000000, 1) var base_cost: int = 10
@export_range(1.0, 10.0) var cost_multiplier: float = 3.0
@export var escalating_store_price: bool = false
## Zero means unlimited. Store entries are always repeatable.
@export_range(0, 100, 1) var max_level: int = 5
@export_enum("none", "mulcher", "mulch_bin") var installation: String = "none"
@export var effects: Array[upgrade_effect] = []
@export var delivery_scene: PackedScene
@export_enum("none", "fan", "plate", "spawner") var delivery_kind: String = "none"

func cost(level: int) -> int:
	var exponent: int = level if tab != Tab.STORE or escalating_store_price else 0
	return int(clampf(ceil(base_cost * pow(cost_multiplier, exponent)), 0.0, 2147483647.0))
