# October F1 issue pass

Thirty local October 12 report descriptions and every sibling screenshot were read/viewed before editing. Resolution records stay beside the local reports, with original context/images intact; these private inputs are not published. Current memory travel supersedes the earlier completion-only return design.

## Changes to test

| Area | Result |
| --- | --- |
| Intro | Floor slide cues use an exported 0.25 linear volume (about −12 dB) through Audio. |
| F1 / PC | Descriptions wrap; success closes/restores the caller, failure retains the draft. F1–F7/tilde pass through focused/moving PC input. Screen content fills its viewport; roomier rows and smaller type. |
| Memory offers | Self offers appear at 750 / 12,500 / 25,000 current score, stay introduced after spending and disappear after purchase. Unfinished return/reentry retains the portal; other memories stay blocked. Completion then return closes it. |
| Regular discovery | Editable reveal_lifetime_score per resource; profile.lifetime_score tracks awarded earnings across runs. Spending does not reverse discovery; old balances migrate. |
| Combo | Base ceiling 15×; Mechanics upgrades add five to the ceiling, add 0.25 to each increment, or reduce timer decay by 20% per tier. Five tiers, ×3 costs; immediate/restore effects use baselines. |
| Mulch | Pellet shared F prompt and overlapping pickup-volume handling; persistent Mulcher ownership installs next run; one Bin purchase per run. |
| Memory loading | Sequential background PackedScene warming in rendered games; one instantiated room only. Teardown joins its worker load; headless tools load on demand for dummy-renderer RID safety. |
| Player / apartment | 1.8 m capsule / 1.65 m eye; wood footsteps via room overrides; dim amber light. Wider armchair seat/moved placement, soft sewn pillow, visible existing family image, recessed TV glass. |
| Hospital | Portal-height headers, nonoverlapping ward door panels, supported intersection rails, inward benches and closed far exit. No powered scene lights or automatic headlamp. |
| Warehouse | Continuous stair collision with native slope motion; original visual treads remain. Rear catwalk guards close gaps. No powered scene lights or automatic headlamp. |
| Recorder | F7 default Windows camera/mic mode; top-left 15% viewport width, native aspect. F6 lossless game capture remains independent; F7 releases inputs while game recording can continue. |

## Editable state / scripts

Scripts/Player/player_wake_up.gd exports slide_volume=0.25. Scenes/Player/player.tscn owns capsule and eye height. Scripts/Player/player_move_controller.gd caches step_obstacle and lets smooth-walking-surface collisions use native slope movement. That reusable group is authored on the warehouse ramp by Tools/bake_portal_environments.gd. Scene geometry, collision resources, native .blend sources and manifests remain separately editable.

Scripts/Portal/portal_room.gd (portal_room / Node3D / uid://cktan25j4al7n) exports environment, left_foot_sounds/right_foot_sounds Array[AudioStream] and suppress_player_light=false. door_portal._set_player_space owns footstep/headlamp restoration. Its warmed_scenes/warm_queue/warming_paths are transient; _loaded_scene and _start_next_warm coordinate loading, while active_memory_id/portal_destination_id/portal_inside remain Blackboard values. No unused art room is instantiated.

Scripts/Computer/computer_entry.gd adds reveal_lifetime_score=0 and single_purchase=false. upgrade_effect target enum adds combo. Progression.lifetime_score(), record_earned_score(amount) and entry_visible(entry) own discovery; ScoreRewards calls the earnings hook as points arrive. Profile restoration validates nonnegative lifetime_score and bool mulcher_unlocked, with migration from the old flag. Delete Save still clears the whole profile; New Game preserves it. See Data/Computer/README.md, MEMORY_UPGRADES.md and Data/Mulch/README.md.

addons/dev_toolkit/webcam_capture.gd / RefCounted / uid://dbpf2oa8qbl4e is independent of Remnant gameplay: start(path), take_frame(), stop(), static png_size(), bounded latest frame/buffer and owned FFmpeg pipe/thread. GameplayRecorder adds input_mode_key, webcam_width_fraction, microphone_gain and set_input_mode(value). Microphone input is raw capture on a private muted bus, not host SFX playback. Enable audio/driver/enable_input in reused hosts. Data/RECORDING.md defines optional hardware/setup/error/lifecycle behavior.

## Verification and limits

Selected fixtures cover real pellet pile targeting/F pickup, report persistence/restoration, screen purchases, reveal thresholds, combo caps/effects, Mulcher/bin/save/New Game, actual memory walking/Continue/reentry/completed exit/cargo, all hospital ward routes, smooth warehouse ascent/office, rail rides and carry attachments. Actual engine views distinguish intended black memory lighting from test-only diagnostic illumination. Native furniture/door/architecture renders use separate presentation rigs; every final delivered image was opened.

The recorder fixture uses a real FFmpeg PNG test feed and known tone through the microphone capture bus. Encoded output is native 960×540 RGB H.264 plus stereo 48 kHz float PCM; decoded audio is non-silent. A local physical-device probe received a 1,280×720 camera frame and 25,088 default-mic samples, then released both devices without saving private media. Camera source transport caps at 1,280 pixels/30 FPS; gameplay output remains native/lossless. Warming still leaves roughly 0.09–0.25 seconds of measured scene-instantiation work on this PC; it does not promise instant purchases or whole-game performance.

Run save-affecting fixtures with isolated APPDATA. Tests/issue_presentation_test.tscn, issue_memory_art_test.tscn and recorder_inputs_test.tscn require a renderer; the latter requires FFmpeg. Inspect all logs even when the process exits successfully. Windows exports and exact commit/Pages results are recorded in the dated development summary. Story completion triggers and a full manual playthrough remain separate work.
