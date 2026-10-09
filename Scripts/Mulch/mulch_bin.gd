class_name mulch_bin
extends RigidBody3D
func _ready() -> void:
	$Deposit.body_entered.connect(_deposit)
func _deposit(body: Node3D) -> void:
	Mulch.deposit(body)
func get_look_prompts() -> prompt_set:
	var result := prompt_set.new()
	var entry := prompt_entry.new()
	entry.text = "Pickup Mulch Bin"
	entry.action = &"pickup"
	result.entries.append(entry)
	return result

func _physics_process(_delta: float) -> void:
	# Keep the non-solid deposit sensor working while the bin is carried.
	if $Deposit.collision_mask != 1:
		$Deposit.collision_mask = 1
