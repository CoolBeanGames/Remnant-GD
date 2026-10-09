# Player voices and cinematic audio

Audio assets are under Audio/Vocals (the supplied folder's actual name). The first-spawn resource maps what the hell? to vo__what the hell (intro).wav and where am I? to vo__where am I.wav. Respawn maps I... to vo__I (first death).wav and I thought I died... to vo__I thought I died.wav. Other recorded story lines remain available for future dialogue resources and have no new triggers.

Dialogue waits for the current line's typewriter/hold and optional voice before fading to the next line. E immediately advances to the next line and stops/releases the previous voice. Its press/release is consumed, including when skipping the last line, so it cannot open a door, toggle a held fan or empty a basket. The default Vocals bus keeps voices audible before the first door opening. Empty voiceover is safe.

Wake_Up now lasts 12.8 seconds. The rise keeps its original staged motion; the late look-around is stretched: standing 5.35 s, left 7.25 s, right 10.15 s, centred 12.1 s, handoff 12.8 s. Slide 1 plays at pose time 1.3 and Slide 2 at 3.65, with an optional quiet effort bank using the supplied short jump grunts. All pose cues scale with Duration. Dialogue begins at 4.3 seconds by default, after both rise grunts finish. Edit Slide Sounds/Effort Sounds on Wake_Up; clear either bank for silence.

Jumping plays a random clip from vo__jump_1 through vo__jump_6. Five seconds of continuous grounded movement while sprinting starts vo__out of breath.wav; stopping resets the timer. Continuous sprinting can play another breath after the current clip finishes, but never overlaps it. Death/teardown stop and release it. These banks, thresholds and bus are exported on Player_Move_Controller.

Grinder death first cancels dialogue and heavy breathing, locks movement/look/breathing, plays a random vo__death_1 through vo__death_4 and fades vision to black over 0.65 seconds. It waits until both the fade and death voice finish before rebuilding the room and starting the wake-up/respawn dialogue. Death Sounds and Death Fade Seconds are exported on Wake_Up; an empty bank still fades/respawns safely. DONT. DO. THAT. retains its once-only history and waits until waking ends.

The main door dispatches its close sound from AnimationPlayer.animation_finished only when the finished animation matches Close Animation and the door is closed. Opening still plays its sound at the start, after restoring the world SFX bus.

## APIs and scene dependencies

| Script / class / inheritance | Added exports / runtime state | API / integration |
|---|---|---|
| Scripts/Player/player_wake_up.gd / player_wake_up / Node / uid://cl3ux503kxlx6 | duration=12.8, slide_sounds:Array[AudioStream], effort_sounds:Array[AudioStream], death_sounds:Array[AudioStream], death_fade_seconds=.65; cue_index | start(is_respawn=false), asynchronous fade_for_death(); existing started/finished signals. Uses pooled Audio, Dialogue, Blackboard, Camera3D and Player controller paths; black overlay layer 40. |
| Scripts/Player/player_move_controller.gd / Node | jump_sounds:Array[AudioStream], heavy_breathing:AudioStream, sprint_breath_seconds=5, voice_bus=Vocals; sprint_elapsed, breath_voice:WeakRef | play_jump_sound()->audio_player, _update_sprint_audio(delta,sprinting), reset_audio(). Existing actual jump branch dispatches the grunt; sprint accumulation requires motion and floor contact. No new signals. |
| Scripts/UI/dialogue_player.gd / dialogue_player / CanvasLayer / uid://ck412fepw2bgo | confirm_consumed | advance(), blocks_confirm(); _input handles confirm, releases after .05 s. Existing sequence_started/finished/line_started retained. Player Interact/Pickup consult blocks_confirm. |
| Scripts/Actors/start_room_door.gd / start_room_door / Node3D | existing Close Animation/audio exports | _on_animation_finished(name:StringName). No new signals; opened retained. Requires imported AnimationPlayer. |
| Scripts/Level/world_guidance.gd / world_guidance / Node | existing respawn_pending/player_contact_pending guards | _respawn awaits Wake_Up.fade_for_death before level.respawn_player; cinematics-disabled fixtures retain immediate respawn. |

Tests/player_voice_test.tscn checks the sprint threshold, no overlapping breaths, randomized jump bank, blank-bank safety, death controls/fade/voice wait, slide cues and slower look sweep. Dialogue and start_room_audio tests check E skipping/voice release and end-of-close dispatch.

Recorded speech and exertion now use the Vocals bus controlled by Options; slides remain RoomSFX. See Data/OPTIONS.md.
