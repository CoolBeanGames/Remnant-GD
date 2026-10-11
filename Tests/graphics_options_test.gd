extends Node

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func tick() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	SaveGame.save_path = "res://.godot/graphics_options_test.save"
	SaveGame.enabled = false
	SaveGame.saving_disabled = false
	SaveGame.profile = {"mulch_coins": 0, "mulch_upgrades": {}, "settings": {}}
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.save_path))
	Settings.restore()
	var viewport := get_tree().root
	var environment := Environment.new()
	environment.ssao_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	await tick()
	Settings.set_value("ambient_occlusion", false)
	check(not environment.ssao_enabled, "Ambient occlusion is disabled on the live authored environment")
	Settings.set_value("ambient_occlusion", true)
	check(environment.ssao_enabled, "Re-enabling ambient occlusion restores the authored environment")
	var unlit := Environment.new()
	Settings.register_environment(unlit)
	Settings.set_value("ambient_occlusion", false)
	Settings.set_value("ambient_occlusion", true)
	check(not unlit.ssao_enabled, "Settings do not add ambient occlusion to environments that never used it")
	world.queue_free()
	await tick()
	Settings.set_value("render_scale", .65)
	check(is_equal_approx(viewport.scaling_3d_scale, .65) and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, "Render scale changes the actual 3D render buffers")
	for aa in range(5):
		Settings.set_value("antialiasing", aa)
		check(viewport.msaa_3d == (aa - 1 if aa >= 2 else 0) and viewport.screen_space_aa == (1 if aa == 1 else 0) and not viewport.use_taa, "Antialiasing mode %d changes the live viewport without stacked modes" % aa)
	for quality in range(4):
		Settings.set_value("shadow_quality", quality)
		check(viewport.positional_shadow_atlas_size == Settings.SHADOW_SIZES[quality], "Shadow quality %d changes live atlas resolution" % quality)
	Settings.set_value("fps_limit", 30)
	check(Engine.max_fps == 30, "Frame cap applies to the engine immediately")
	Settings.set_value("fps_limit", 0)
	check(Engine.max_fps == 0, "Unlimited FPS removes the cap")
	var options: options_menu = load("res://Scenes/UI/options_menu.tscn").instantiate()
	add_child(options)
	options.open()
	check(options.tabs.get_tab_count() == 3 and options.widgets.has("render_scale") and options.widgets.has("shadow_quality"), "Shared options exposes graphics, audio and controls in scrollable tabs")
	if DisplayServer.get_name() != "headless":
		options.tabs.current_tab = 2
		await tick()
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://.godot/graphics_options_top.png")
		var graphics_scroll: ScrollContainer = options.tabs.get_child(2)
		graphics_scroll.scroll_vertical = int(graphics_scroll.get_v_scroll_bar().max_value)
		await tick()
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://.godot/graphics_options_bottom.png")
	options._slider_changed(75, "render_scale")
	options._choice_changed(2, "antialiasing")
	options._choice_changed(1, "shadow_quality")
	options._choice_changed(5, "fps_limit")
	options._toggle_changed(false, "vsync")
	if DisplayServer.get_name() != "headless":
		options._choice_changed(1, "window_mode")
		await tick()
		check(viewport.mode == Window.MODE_FULLSCREEN, "Display mode enters fullscreen live")
		options._choice_changed(0, "window_mode")
		await tick()
		check(viewport.mode == Window.MODE_WINDOWED, "Display mode returns to windowed live")
		check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "V-sync selection applies to the operating-system window")
	options.close()
	check(not get_tree().paused, "Options restores prior pause ownership")
	check(is_equal_approx(viewport.scaling_3d_scale, .75) and viewport.msaa_3d == Viewport.MSAA_2X and Engine.max_fps == 144, "Menu selections affect rendering and frame pacing")
	var payload: Dictionary = SaveGame._read_payload()
	check(payload.profile.settings.render_scale == .75 and payload.profile.settings.fps_limit == 144 and payload.profile.settings.vsync == false, "Graphics settings persist to the same profile file")
	Settings.values = Settings.DEFAULTS.duplicate(true)
	SaveGame.profile = payload.profile
	Settings.restore()
	check(is_equal_approx(viewport.scaling_3d_scale, .75) and viewport.msaa_3d == Viewport.MSAA_2X and Engine.max_fps == 144, "Restoring a persisted profile reapplies actual renderer state")
	Blackboard.store_data("spawned_items", [])
	Blackboard.store_data("portal_inside", false)
	Flags.set_flag("exited room", true)
	var level: level_sequence = load("res://Scenes/testing_level.tscn").instantiate()
	level.spawn_animation_enabled = false
	add_child(level)
	level.player.process_mode = Node.PROCESS_MODE_DISABLED
	await tick()
	var portal: door_portal = level.get_node("DoorPortal")
	check(portal.active and is_equal_approx(portal.viewport.scaling_3d_scale, .75) and portal.viewport.msaa_3d == viewport.msaa_3d and portal.viewport.positional_shadow_atlas_size == viewport.positional_shadow_atlas_size, "New portal view inherits all current render settings")
	Settings.set_value("render_scale", .5)
	Settings.set_value("antialiasing", 1)
	Settings.set_value("shadow_quality", 0)
	portal._update_view()
	check(is_equal_approx(portal.viewport.scaling_3d_scale, .5) and portal.viewport.screen_space_aa == viewport.screen_space_aa and portal.viewport.msaa_3d == viewport.msaa_3d and portal.viewport.positional_shadow_atlas_size == viewport.positional_shadow_atlas_size, "Live graphics changes stay consistent through the door portal")
	level.queue_free()
	options.queue_free()
	await tick()
	SaveGame.profile.settings = {"render_scale": -8, "antialiasing": 99, "fps_limit": "corrupt", "vsync": "corrupt", "ambient_occlusion": false}
	Settings.restore()
	check(Settings.values.render_scale == .5 and Settings.values.antialiasing == 4 and Settings.values.fps_limit == 0 and Settings.values.vsync == true, "Invalid or old settings are safely normalized")
	SaveGame.profile.settings = {}
	Settings.restore()
	SaveGame.saving_disabled = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.save_path))
	print("Graphics options live renderer, portal, UI, persistence and validation: ", "PASS" if failures.is_empty() else failures)
	get_tree().quit(0 if failures.is_empty() else 1)
