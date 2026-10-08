#defines a single flag
class_name flag
extends Resource

#signals
signal flag_set #fires when a flag is set to true
signal flag_unset #fires when a flag is set to false

#values
var state : bool = false
