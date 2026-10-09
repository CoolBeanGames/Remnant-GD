# Single-file saves and startup loading

Run the project (F5) to start Scenes/UI/title_screen.tscn; New Game/Continue enter Scenes/save_loader.tscn. It restores user://remnant.save before entering Scenes/Game.tscn, which creates the audio pool and loads testing_level. This intermediate scene is ready to sit after a future title screen. Set Game Scene on its root to change the destination. A missing file starts a new game.

SaveGame writes one versioned binary file containing the entire Blackboard key/value snapshot and every flag's boolean state, including false flags. Native Godot values such as Transform3D, Vector3, Color, StringName and packed arrays retain their types. Typed arrays and both path-based/inline Resources are supported. Live Node/Object, Callable, Signal and RID handles are represented as null under their existing keys, then re-registered by their scene owners; scene instances and connections cannot survive a process restart. Input/menu/wake locks are cleared on load so a paused save does not strand the player. Persistent scene actors are restored from WorldState's spawned_items records.

Saves also capture pending ScoreRewards points/timing, the active GrindCombo and the level exit countdown into Blackboard. Progression reloads its upgrade/purchase counts from Blackboard. Score, notes, note-pool history, progression/story flags, item transforms, velocities, upgrade snapshots, power states, placements/supports and auto-spawner timing use their existing state records. Production startup still wakes in the concrete room and adds a tally; Spawn Animation Enabled=false preserves the exact saved player pose for previews/tests.

Autosaving runs every 10 seconds of unpaused gameplay. Pause-menu Exit and window close save before quitting. Leaving/reloading Game saves through the level's tree_exiting signal; WorldState's continually updated last snapshot is used once actors have left the tree. Reloading through SaveLoader reads the file again before recreating the level. Game clears SceneManager's registrations on teardown so the next level can register under test_level again.

DELETE SAVE AND EXIT in shared Options disables saving first, removes the save and any interrupted temporary write, then quits. Teardown and window-close saves cannot recreate it. The next launch starts fresh. Normal writes flush a temporary file and atomically replace the final file, leaving only remnant.save after success. Invalid versions/data emit save_failed and do not partially restore state; write/delete errors are reported rather than silently treated as success.

## API and identities

| Script / inheritance / identity | Exports and runtime state | Public API / signals / dependencies |
|---|---|---|
| Global/save_game.gd / Node / SaveGame autoload / uid://bn0hnik2p11h0 | save_path=user://remnant.save; autosave_seconds=10; enabled=false, saving_disabled=false, load_attempted=false, elapsed; VERSION=2 (loads legacy version 1) | save_now()->bool, load_now()->bool, capture_runtime(), restore_runtime(resume=false), start_session(), exit_game(), reset_save()->bool, reset_and_quit(). Signals saved, loaded, save_failed(message:String). Uses Blackboard, Flags, WorldState, Progression, ScoreRewards and GrindCombo. PROCESS_MODE_ALWAYS; autosave explicitly respects pause. |
| Scripts/save_loader.gd / Node / uid://bi8no2dyvqifn | game_scene:PackedScene=Scenes/Game.tscn | _ready defers _load(); restores state then changes scene. No custom signals. Scenes/save_loader.tscn is the intermediary after the title. |
| Scripts/game.gd / Node / uid://b4onouqptgpob | child audio_pool; loaded test_level/stage | _ready starts session/resumes rewards and combo, re-registers audio_pool/game_root, loads level and connects tree_exiting. _save_before_reload saves; _exit_tree clears SceneManager registrations. |
| Scripts/UI/pause_menu.gd / pause_menu / CanvasLayer | Main Options opens the shared menu alongside Continue/Notes/Exit | Options owns Delete Save via SaveGame.reset_and_quit; Exit calls SaveGame.exit_game. Scene: Scenes/UI/pause_menu.tscn. |

Tests/save_game_test.tscn checks complete state/flags, native values, inline/path resources and typed arrays, repeat replacement of one file, actual world restoration, pending rewards and reset suppression. Tests/save_loader_test.tscn exercises the real intermediary, Game initialization, service re-registration, scene reload/tallies and reset during teardown. Both use isolated .godot test files, never the player's user://remnant.save.


## Persistent profile and New Game

Version 2 adds profile (mulch_coins, mulch_upgrades, settings) and has_run to the same file. load_profile() reads these without restoring the run, for title/options. has_run_save()->bool enables Continue only for a valid run. save_profile()->bool updates profile while retaining the file's existing encoded run; in active gameplay it captures the current run too. new_game()->bool removes run data, clears Blackboard/Flags/world/runtime caches and writes a profile-only file, preserving permanent coins/tiers/settings. It deliberately does not leave a Continue save. Version-1 files load with an empty profile and migrate on the next write.

Reset still disables saving before deletion, but file operations now use ProjectSettings.globalize_path, delete both final/temporary paths and verify absence. Shared Options displays save_failed errors; new_game starts saving again only after reset succeeds. Profile-only settings writes cannot resurrect deleted data because saving_disabled guards them too. SaveGame's profile is separate from run Blackboard/Flags but inside the same single file. restore_runtime retains its existing reward/combo behavior; load_now also restores Settings and Mulch state.

Added API: load_profile(), has_run_save()->bool, save_profile()->bool, new_game()->bool; profile:Dictionary. See Data/OPTIONS.md and Data/Mulch/README.md for menus, bank and permanent upgrades.

WorldState ignores snapshots while the old level/player is outside the scene tree during title/loader transitions, retaining the last valid Blackboard snapshot. The actual title New Game and Continue button flows were verified through the intermediary and gameplay. Legacy version-one restoration is covered by save_game_test.

exit_game() flushes pending Settings before capturing the run; a failed flush keeps the menu open and reports save_failed instead of discarding the change. Title displays these errors in its Status label.
