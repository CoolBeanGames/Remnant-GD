# Wake-up, room tallies and world boundary

Gameplay startup and grinder death now wake the player in the authored concrete room. Score, upgrades, purchases, found notes, item records and story flags are retained. On startup WorldState first restores its snapshots; the wake sequence then deliberately puts the player back at the room's authored start. Saved player transforms continue to track during play. Turn off Spawn Animation Enabled on the testing-level root for isolated tests/previews that require exact saved player-pose restoration.

The camera begins close to the floor with 90 degrees of roll behind a black screen. Vision fades in over 1.25 seconds. It rises through lying, pushing up, sitting, standing and settling poses, then looks left and right. Smooth transitions use multiple position/angle keys rather than one straight path. At 12.8 seconds it restores the authored standing pose and grants control. Mouse look, movement, footsteps and breathing are suspended until then. Crosshair and look prompts are hidden. Pause menus remain available and freeze the sequence; optional dialogue plays during waking. World word messages wait until waking finishes.

Select **Player / Controllers / Wake_Up** to change Duration, Fade In Seconds, Dialogue Delay, First Dialogue and Respawn Dialogue. The pose keyframes are in player_wake_up.gd (TIMES, POSITIONS, ANGLES). Head height scales to the authored camera height. The black overlay is runtime-generated on layer 40; pause UI remains above it at layer 50. Camera_Breathing resumes afterward with a stronger bounded bob and gentle roll; see CAMERA.md.

Every initial startup/load and grinder respawn increments Blackboard `respawn_tallies`. A runtime TallyMarks node renders narrow, uneven dark grooves with lighter scraped edges on the room's right interior wall. Marks group in fives, wrap across rows and rebuild from the count when the concrete room is recreated. The count is preserved in Blackboard by SaveGame. No individual meshes need saving. Edit room_tallies.gd/its runtime node for Groups Per Row (16), Max Visible Marks (500) and scratch dimensions/colours. Scratches have no collisions.

**WorldBoundary** is a fixed, invisible cube centred on the authored player start. Six static collider faces sit 500 metres away on each axis, with 4 m thickness. It affects main-world layer 1 only. Its centre is not moved with the player or portal crossings. DoorPortal's destination now defaults to `(1600, 0, 0)`, well outside the boundary, at the workshop's floor height. Layer-20 destination collision/render isolation and portal colour continuity are retained. Choose similarly distant positions for later story rooms.

## API and identities

| Script / class / inheritance | Exports and runtime state | API, signals and dependencies |
|---|---|---|
| Scripts/Player/player_wake_up.gd / player_wake_up / Node | player, camera, duration=12.8, fade_in_seconds=1.25, dialogue_delay=4.3, first_dialogue, respawn_dialogue; active, elapsed, standing, previous_block, controller_states, selected_dialogue, dialogue_started, overlay, black, ui_states | start(is_respawn=false). Signals started and finished. Uses Blackboard, Dialogue and Player controller/footstep paths. Normal pause processing; teardown releases owned controls/offsets. |
| Scripts/Level/room_tallies.gd / room_tallies / Node3D | interior:CSGBox3D, groups_per_row=16, max_visible_marks=500; count | refresh(). Uses Blackboard respawn_tallies, procedural meshes/materials and interior geometry; no signals/autoload. |
| Scripts/Level/world_boundary.gd / world_boundary / StaticBody3D | centre_target:Node3D, half_extent=500, wall_thickness=4 | _ready builds six child BoxShape3D colliders; no signals/autoload. Placed in testing_level on layer 1. |

`level_sequence` adds spawn_animation_enabled=true, startup _begin_spawn(), and respawn_player(is_death=true). It increments the tally before reconstructing the room, refreshes marks, resets player/camera/carry/momentum and starts Wake_Up. `start_room._ready` adds TallyMarks after its authored template has been cached. Blackboard player_waking is transient and blocks word-message timing until the sequence finishes. Existing player_input_blocked ownership is restored rather than unconditionally overwritten. Camera3D is explicitly made current on level ready.

`Tests/wake_up_test.tscn` checks the floor/roll/black starting view, rising and look-around stages, locked input, final standing pose, first/death dialogue, visible breathing, persistent load/death tallies, real collision on all six boundary faces and remote portal placement. Production spawn behavior is enabled in this test; unrelated suites explicitly disable the cinematic.

Scripts/Player/player_wake_up.gd: `uid://cl3ux503kxlx6`.

Scripts/Level/room_tallies.gd: `uid://di7ssn6df72nu`.

Scripts/Level/world_boundary.gd: `uid://ce012vxidcxe0`.

The late look-around and optional get-up/death sounds are detailed in [VOICE.md](VOICE.md). Disk persistence and reload behavior are detailed in [../SAVING.md](../SAVING.md).
