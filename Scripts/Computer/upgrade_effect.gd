class_name upgrade_effect
extends Resource

enum Operation { ADD, MULTIPLY, SET }
## fan/plate apply only to future store deliveries; item_value to future chute items.
@export_enum("fan", "plate", "broom", "light", "item_value", "movement", "pickup", "spawner", "mulcher") var target: String = "fan"
@export var property: NodePath = NodePath("force")
@export var operation: Operation = Operation.MULTIPLY
@export var amount: float = 1.25

func apply_value(value: Variant) -> Variant:
	var result: float = amount
	if operation == Operation.ADD:
		result = float(value) + amount
	elif operation == Operation.MULTIPLY:
		result = float(value) * amount
	if value is bool:
		return result > 0
	if value is int:
		return int(round(result))
	return result
