# Title and shared Options

Project startup is Scenes/UI/title_screen.tscn. New Game clears the saved run while retaining banked mulch coins, purchased permanent mulch tiers and settings, then enters Scenes/save_loader.tscn → Game → testing_level. Continue appears only when a valid saved run exists, and restores that run through the same intermediary. A profile-only file from settings/New Game does not enable Continue. Options opens the same reusable menu as pause-menu Options. Exit uses SaveGame's safe quit flow.

TitleScreen is a Node3D with an empty Background child ready for a future 3D scene/camera. UI/Screen is a translucent dark overlay; its Rows contain editable NewGame/Continue/Options/Exit buttons. Main-scene startup no longer enters gameplay automatically.

Options has Master, SFX, Vocals and Music sliders (0–100%), separate mouse X/Y inversion, sensitivity multiplier (0.1–5), Back and DELETE SAVE AND EXIT. Controls apply immediately and persist after a short 0.25-second debounce or when closing. A shared options_menu CanvasLayer owns its pause/mouse state, restoring the caller's previous pause on Back/Escape. From pause it returns to a still-paused game; from title it returns to title. Delete Save moved off the main pause menu. It removes the entire file/profile, including banked coins/tiers, and quits without saving. Any failure appears in the Options status label; deletion is checked against the resolved absolute path and verified afterward.

Master controls Master, SFX controls SFX plus RoomSFX, Vocals controls Vocals, Music controls Music. Spoken dialogue, jump grunts, sprint breathing, death clips and intro exertion now use Vocals. Slide/room effects remain RoomSFX. Footsteps bus routes to RoomSFX so footsteps stay audible during initial world muting but respect the SFX slider. start_room tracks Settings revision while gating SFX; if settings change, opening restores the current configured gain, not the earlier value or full gain. World gating only mutes SFX; it never overrides the other sliders. Mouse settings multiply the authored look sensitivity and invert axes independently.

## API and identities

| Script / inheritance / identity | Exports / runtime state | Public API / signals / scene dependencies |
|---|---|---|
| Global/settings.gd / Settings autoload / Node / uid://bfyab6u48kgeb | DEFAULTS, values, revision, world_gates, dirty_seconds | restore(), set_value(key,value), apply_audio(), flush()->bool. Signal changed. PROCESS_MODE_ALWAYS; profile settings persist through SaveGame. |
| Scripts/UI/title_screen.gd / Node3D / uid://b50s7t3jl3q3f | loader_scene:PackedScene, options:options_menu, rows | _new_game(), _continue(), _options(), _failed(message). Depends SaveGame/Settings and named Rows buttons; no custom signals. Title disables inactive reward/combo processing. |
| Scripts/UI/options_menu.gd / options_menu / CanvasLayer / uid://brtfk4qvon376 | is_open, previous_pause/mouse, status, widgets, delete_button | open(), close(), _slider_changed(value,key), _toggle_changed(value,key), _delete(), _failed(message). Signal closed. Runtime controls on reusable options_menu.tscn, layer 60, PROCESS_MODE_ALWAYS. |
| Scripts/UI/pause_menu.gd / pause_menu / CanvasLayer / uid://ciplhqtpq62j | options:options_menu; existing pause/reader state | _options opens shared scene; main Options enabled, main Reset removed. Existing journal/Continue/Exit retained. |
| Scripts/Player/player_look_controller.gd / Node / uid://bu180f6gx5iet | existing authored sensitivity, rotations/mouse input | look(delta) applies Settings sensitivity/invert_x/invert_y; wake/menu locks retained. |
| Scripts/Level/start_room.gd / start_room / CSGCombiner3D | settings_revision and Settings.world_gates coordination | _restore_sfx honors slider changes while gated; legacy manually configured volume/mute preserved when settings did not change. |

Tests/title_options_test.tscn covers fresh-title visibility, profile-only saves, shared menu pause ownership, all bus gains, room gate/restoration, inversion/sensitivity, preserved run data on settings writes, New Game coins/settings and deletion suppression. An isolated user:// delete-button integration was also exercised, including queued settings writes and game exit.

Title save failures appear in Rows/Status. Window/menu exit flushes pending settings before closing, so a slider change immediately followed by Exit is retained.
