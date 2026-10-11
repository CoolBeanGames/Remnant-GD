class_name mulch_bin
extends RigidBody3D
var look_prompts: prompt_set
func _ready() -> void:
	$Deposit.body_entered.connect(_deposit)
func _deposit(body: Node3D) -> void:
	Mulch.deposit(body)
func get_look_prompts() -> prompt_set:
	if look_prompts == null:
		look_prompts = prompt_set.new()
		var entry := prompt_entry.new()
		entry.text = "Pickup Mulch Bin"
		entry.action = &"pickup"
		look_prompts.entries.append(entry)
	return look_prompts

func _physics_process(_delta: float) -> void:
	# Keep the non-solid deposit sensor working while the bin is carried.
	var mask: int = int(get_meta("collision_space_mask", 1))
	if $Deposit.collision_mask != mask:
		$Deposit.collision_mask = mask
