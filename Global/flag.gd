#defines a single flag
class_name flag
extends Resource

#signals
signal flag_set #fires when a flag is set to true
signal flag_unset #fires when a flag is set to false

#values
var state : bool = false

func set_state(value: bool) -> void:
	state = value
	if state:
		flag_set.emit()
	else:
		flag_unset.emit()
