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
## Score earned across runs, rather than current spendable balance; zero is immediate.
@export_range(0, 1000000, 1) var reveal_lifetime_score: int = 0
@export var single_purchase: bool = false
## Zero means unlimited. Store entries repeat unless single_purchase is enabled.
@export_range(0, 100, 1) var max_level: int = 5
## Regular score upgrades can unlock a saved run flag without numeric effects.
@export var unlock_flag: String = ""
## Memory purchases open an existing destination; completion comes from story triggers.
@export var memory_destination: StringName = &""
@export var completion_flag: String = ""
@export_enum("none", "mulcher", "mulch_bin") var installation: String = "none"
@export var effects: Array[upgrade_effect] = []
@export var delivery_scene: PackedScene
@export_enum("none", "fan", "plate", "broom", "light", "spawner") var delivery_kind: String = "none"

func cost(level: int) -> int:
	var exponent: int = level if tab != Tab.STORE or escalating_store_price else 0
	return int(clampf(ceil(base_cost * pow(cost_multiplier, exponent)), 0.0, 2147483647.0))
