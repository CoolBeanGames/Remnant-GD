class_name level_sequence
extends Node3D

@export var player: CharacterBody3D
@export var room: start_room
@export var manual_lever: lever
@export var chute: ceiling_chute
@export var grinder: grinding_area
@export var computer: computer_terminal
@export var machine_audio: AudioStreamPlayer3D
@export var exit_delay: float = 3.0
@export var lever_threshold: int = 5
@export var computer_threshold: int = 30
@export var kill_height: float = -10.0
@export var spawn_animation_enabled: bool = true
var exit_countdown: float = -1.0
var lever_pulls: int = 0
var room_template: PackedScene
var spawn_pose: Transform3D
var spawn_camera_pose: Transform3D

func _enter_tree() -> void:
	if spawn_animation_enabled:
		Blackboard.store_data("player_waking", true)
	var authored_player: CharacterBody3D = get_node_or_null("Player")
	var authored_room: start_room = get_node_or_null("CSGCombiner3D")
	if authored_player != null:
		spawn_pose = authored_player.transform
		spawn_camera_pose = authored_player.get_node("Camera3D").transform
	if authored_room != null:
		var copy: start_room = authored_room.duplicate(Node.DUPLICATE_SCRIPTS) as start_room
		copy.door = null
		copy.player = null
		copy.camera = null
		copy.footsteps = null
		copy.respect_exit_flag = false
		copy.mute_sfx_until_open = false
		copy.auto_close_on_exit = false
		copy.interior = copy.get_node("Start_Room_Inner")
		for descendant in copy.find_children("*", "", true, false):
			descendant.owner = copy
		room_template = PackedScene.new()
		room_template.pack(copy)
		copy.free()
	# Normalize resumed progress before child lights initialize, so startup is silent.
	if Flags.check_flag("exited room") or Flags.check_flag("grinder enabled") or Flags.check_flag("computer enabled"):
		Flags.set_flag("level enabled", true)

func _ready() -> void:
	player.get_node("Camera3D").make_current()
	lever_pulls = int(Blackboard.read_data("lever_pulls")) if Blackboard.data_exists("lever_pulls") else 0
	var resumed: bool = Flags.check_flag("exited room") or Flags.check_flag("level enabled") or Flags.check_flag("grinder enabled") or Flags.check_flag("computer enabled")
	if resumed and is_instance_valid(room):
		room._remove_room()
	if is_instance_valid(room):
		room.exited.connect(_on_room_exit)
	if resumed:
		exit_countdown = exit_delay if not Flags.check_flag("level enabled") else -1.0
	var saved_countdown: Variant = Blackboard.read_data("level_exit_countdown")
	if saved_countdown is float or saved_countdown is int:
		exit_countdown = float(saved_countdown)
	manual_lever.pulled.connect(_on_lever_pulled)
	Flags.connect_to_flag("level enabled", [_enable_level])
	Flags.connect_to_flag("grinder enabled", [_enable_grinder])
	Flags.connect_to_flag("computer enabled", [_enable_computer])
	manual_lever.set_enabled(Flags.check_flag("level enabled"))
	chute.enabled = Flags.check_flag("level enabled")
	grinder.set_enabled(Flags.check_flag("grinder enabled"))
	computer.set_enabled(Flags.check_flag("computer enabled"))
	_set_grinder_motion(Flags.check_flag("grinder enabled"))
	WorldState.begin(self, player, kill_height)
	Mulch.bind_level(self)
	if Blackboard.read_data("respawn room active") == true:
		_restore_respawn_room.call_deferred()
	_check_thresholds()
	if spawn_animation_enabled:
		_begin_spawn.call_deferred()

func _begin_spawn() -> void:
	respawn_player(false)

func _restore_respawn_room() -> void:
	if room_template == null:
		return
	if not is_instance_valid(room) or room.erased:
		room = room_template.instantiate() as start_room
		room.door = $doorway_animated
		room.player = player
		room.camera = player.get_node("Camera3D")
		room.footsteps = player.get_node("footstep_sound_players")
		add_child(room)
	if not room.room_erased.is_connected(_respawn_room_erased):
		room.room_erased.connect(_respawn_room_erased)
	var portal: door_portal = get_node_or_null("DoorPortal")
	if portal != null:
		portal.set_suspended(true)
	Blackboard.store_data("respawn room active", true)

func _respawn_room_erased() -> void:
	Blackboard.store_data("respawn room active", false)
	var portal: door_portal = get_node_or_null("DoorPortal")
	if portal != null:
		portal.set_suspended(false)

func respawn_player(is_death: bool = true) -> void:
	DevTools.log_info("Respawning player in the concrete room." if is_death else "Starting the player's wake-up sequence.", "level")
	var tally: Variant = Blackboard.read_data("respawn_tallies")
	Blackboard.store_data("respawn_tallies", (int(tally) if tally is int or tally is float else 0) + 1)
	var placement: prop_placement = player.get_node("Controllers/Prop_Placement")
	placement.cancel_building()
	var pickup: player_pickup = player.get_node("Controllers/Player_Pickup")
	pickup.drop_object()
	var portal: door_portal = get_node_or_null("DoorPortal")
	if portal != null:
		portal.inside = false
		Blackboard.store_data("portal_inside", false)
		if portal.active:
			portal._set_player_space()
	_restore_respawn_room()
	var marks: room_tallies = room.get_node_or_null("TallyMarks") if is_instance_valid(room) else null
	if marks != null:
		marks.refresh()
	$doorway_animated.request_close()
	player.transform = spawn_pose
	player.velocity = Vector3.ZERO
	var camera: Camera3D = player.get_node("Camera3D")
	var breathing: camera_breathing = player.get_node_or_null("Controllers/Camera_Breathing")
	if breathing != null:
		breathing.reset()
	camera.transform = spawn_camera_pose
	var look: Node = player.get_node("Controllers/Player_Look_Controller")
	look.target_rotation = Vector2(camera.rotation_degrees.x, player.rotation_degrees.y)
	look.look_rotation = look.target_rotation
	look.mouse_input = Vector2.ZERO
	var movement: Node = player.get_node("Controllers/Player_Move_Controller")
	movement.wind_velocity = Vector3.ZERO
	movement.applied_wind = Vector3.ZERO
	movement.velocity_target = Vector3.ZERO
	movement.reset_platform_motion()
	player.get_node("Camera3D/RayCast3D")._set_looked_at(null)
	WorldState._physics_process(0.0)
	WorldState.capture()
	if spawn_animation_enabled:
		player.get_node("Controllers/Wake_Up").start(is_death)

func _on_room_exit() -> void:
	if not Flags.check_flag("level enabled") and exit_countdown < 0:
		exit_countdown = exit_delay

func _process(delta: float) -> void:
	if exit_countdown >= 0:
		exit_countdown -= delta
		if exit_countdown <= 0:
			exit_countdown = -1.0
			Flags.set_flag("level enabled", true)
	_check_thresholds()

func _on_lever_pulled() -> void:
	lever_pulls += 1
	Blackboard.store_data("lever_pulls", lever_pulls)
	_check_thresholds()

func _check_thresholds() -> void:
	if lever_pulls >= lever_threshold and not Flags.check_flag("grinder enabled"):
		Flags.set_flag("grinder enabled", true)
	if Progression.score() >= computer_threshold and not Flags.check_flag("computer enabled"):
		Flags.set_flag("computer enabled", true)

func _enable_level() -> void:
	DevTools.log_info("Level lighting, lever and chute enabled.", "level")
	manual_lever.set_enabled(true)
	chute.enabled = true

func _enable_grinder() -> void:
	DevTools.log_info("Grinder enabled after %d lever pulls." % lever_pulls, "level")
	grinder.set_enabled(true)
	_set_grinder_motion(true)

func _set_grinder_motion(enabled: bool) -> void:
	for node in $game_stage_base.get_children():
		if str(node.name).begins_with("Grinder_"):
			node.set_process(enabled)
			node.set_physics_process(enabled)
	Audio.set_spatial_active(machine_audio, enabled)

func _enable_computer() -> void:
	DevTools.log_info("Computer enabled at %d score." % Progression.score(), "level")
	computer.set_enabled(true)

func _exit_tree() -> void:
	if spawn_animation_enabled:
		Blackboard.store_data("player_waking", false)
