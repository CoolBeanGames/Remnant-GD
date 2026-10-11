# Diagnostics and tests

Reproduce the concrete trigger through existing test scenes. Typed GDScript warnings can become parse failures. Inspect logs even if tests exit 0; parse-failed scenes may remain running. Fix lifecycle causes rather than hiding errors.

Instantiate actual scenes, let Area3D/contact physics settle for multiple ticks, then exercise controls/forces and observe results. Cover collision tunneling, chute jams, container release, nested supports, reversal/removal, player dismount, duplicate rewards, optional audio and save/load identities when relevant. Isolate fixture damping/timing; do not weaken assertions to conceal a real failure. Skip tests that only mirror wording or trivial reversible changes.

Remnant discovery hints: rail_chain_test/rail_player_test/rail_slider_test for rails; prop_placement_test/carry_attachment_test/manual_expansion_test/manual_props_test for carry/build; save_game_test/door_portal_test/portal_assembly_test/wake_up_test/player_voice_test/dev_console_test for persistence/relocation; approved_tools_test/approved_upgrades_test/computer_test/graphics_options_test for upgrades/rendering. Verify scenes exist and select appropriate checks; no automatic full-suite repetition after they pass.

Run editor import first: Godot --headless --editor --path PROJECT --quit. Test: Godot --headless --path PROJECT --log-file LOG res://Tests/NAME.tscn. Use argument arrays, explicit timeouts and absolute paths. On Windows set APPDATA only in the subprocess environment to an isolated workspace profile; never alter global environment or touch the user's real save. On other OSes discover the supported data location before save-mutating tests.

Stop only the exact agent-started hung process and its verified children; never terminate the user's editor/unrelated apps. Retain logs and report failures. Passing selected checks is not proof of every possible gameplay combination.

Capture actual rendered UI/models and open the images. Headless checks do not verify materials, transparency, layout or portal colours. Compare portal/direct view at matched camera poses. Smoke Windows exports with isolated data/logs and check EXE/PCK/renderer DLLs; headless startup only proves resource/script availability. Render a short exported run when presentation changed.

Use existing diagnostic service (Remnant DevTools.log_info/log_warning/log_error). Log concise event/category/context: startup/load, purchases, unlocks, issue saved, portal, respawn, cull, save failures, recorder state. Avoid continuous spam, secrets or private snapshots. F5 preserves interrupted-session evidence and exports logs; missing clean shutdown can also mean forced termination. F1 original screenshot/description remain intact with a resolution record.

Measure before broad optimization. State exactly what was profiled. Keep bounded caches invalidated on removal/support/space changes; do not leave stale strong references to actors.
