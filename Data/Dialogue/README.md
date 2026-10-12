# Authoring dialogue

Normal gameplay enables story/dialogue text. show_text remains configurable; PC/note viewing temporarily hides captions while preserving voice/sequence timing. World viewing sessions own input before dialogue. See Data/WORLD_INTERFACES.md.

The normal testing level includes `Scenes/UI/dialogue_player.tscn`. Its bottom-screen Text label is reusable and has no panel. Edit that scene to change its font, colour, margins, wrapping and outline. Optional voiceover uses the existing pooled Audio system on Vocals by default, so it remains audible during the initial room's SFX gate. Set Voice Bus on DialoguePlayer to another existing bus if needed.

Create a `dialogue_sequence` Resource and save it under Data/Dialogue. Give it an optional Id, enable Once for story beats that must survive reloads, and add `dialogue_line` resources to Lines. Each line has editable multiline Text, an optional Voiceover stream, Characters Per Second, Hold Seconds, Fade Seconds, Wait For Voice and Voice Volume. Blank voice streams are silent and safe. Null lines are skipped; empty sequences do nothing.

Trigger a saved sequence from any script with `Dialogue.play(preload("res://Data/Dialogue/my_scene.tres"))`. For quick text, call `Dialogue.say("A line of dialogue", optional_voiceover, optional_id, once)`. Calls queue in order. `Dialogue.cancel()` stops the current voice and clears all queued lines. No player input is needed to advance: each line types, holds, then fades. Wait For Voice keeps its full text visible until the optional voice finishes. Dialogue pauses with the game's pause menu.

For level triggers, instance `Scenes/Dialogue/dialogue_trigger.tscn`, resize its Shape, assign Sequence and leave On Player Entry enabled. For an E interaction, disable On Player Entry; the area enables its aim layer and reusable Listen prompt. Prompt Text is adjustable. Trigger's `trigger()` and `interact()` are also available to scripts/signals.

`Data/Dialogue/first_spawn.tres` contains "what the hell?" and "where am I?" and has Once enabled. `respawn.tres` contains "I..." and "I thought I died..." and repeats for each grinder respawn. Player Wake_Up references both resources and starts them after its Dialogue Delay (4.3 seconds). The first sequence does not replay on later loads.

## APIs and identities

| File / class / inheritance | Exports and runtime state | Public API and signals |
|---|---|---|
| Global/dialogue.gd / Dialogue autoload / Node | view: dialogue_player, pending: Array[dialogue_sequence] | bind(player), play(sequence) -> bool, say(text, voiceover=null, id="", once=false) -> bool, cancel(). No signals. project.godot loads it after Notes. |
| Scripts/Dialogue/dialogue_line.gd / dialogue_line / Resource | text, voiceover=null, characters_per_second=28, hold_seconds=1.6, fade_seconds=0.5, wait_for_voice=true, voice_volume=1 | Data-only resource; no signals. |
| Scripts/Dialogue/dialogue_sequence.gd / dialogue_sequence / Resource | id, once=false, lines:Array[dialogue_line] | Data-only resource; no signals. |
| Scripts/Dialogue/dialogue_trigger.gd / dialogue_trigger / Area3D | sequence, on_player_entry=true, prompt_text="Listen" | trigger() -> bool, interact(), get_look_prompts(). Uses Dialogue and object_prompts. Needs Shape child; no custom signals. |
| Scripts/UI/dialogue_player.gd / dialogue_player / CanvasLayer | voice_bus=Vocals; Text Label, queue, current, line_index, phase, characters, remaining, voice WeakRef | play(sequence) -> bool, cancel(). Signals sequence_started(sequence), sequence_finished(sequence), line_started(line). Needs Dialogue, Flags and Audio pool; layer 32. |

One-time sequence flags use `dialogue <id>`. They are independent of collected notes and the world word-message flags. The screen binds to Dialogue on ready and unregisters/stops voice on teardown. Dialogue does not lock gameplay by itself; the wake controller owns the startup input lock.

`Tests/dialogue_test.tscn` checks typing, opacity fade, pause, optional voice, cancellation/release, once flags and direct scripted lines. `Tests/wake_up_test.tscn` checks both sample sequences and reload suppression.

Global/dialogue.gd: `uid://dc0fv0be0eug5`.

Scripts/Dialogue/dialogue_line.gd: `uid://c08iw1y3tl01g`.

Scripts/Dialogue/dialogue_sequence.gd: `uid://chxo6i74ojp1q`.

Scripts/Dialogue/dialogue_trigger.gd: `uid://bur58k4f1qrib`.

Scripts/UI/dialogue_player.gd: `uid://ck412fepw2bgo`.

The four current lines now have their matching Audio/Vocals clips assigned. E advances immediately and stops the current voice; its release does not trigger a world/carry interaction. `dialogue_player` adds advance(), blocks_confirm() and confirm_consumed. See Data/Level/VOICE.md for clip mappings and get-up/death/movement audio. Dialogue once-flags now persist through SaveGame (Data/SAVING.md).

Recorded speech and exertion now use the Vocals bus controlled by Options; slides remain RoomSFX. See Data/OPTIONS.md.


Memory-specific required E interactions, independent look flavor and completion lists now use memory_trigger_data / memory_object / memory_completion. See Data/Dialogue/MEMORY_TRIGGERS.md and Data/Dialogue/Memories/. Existing generic area-entry dialogue_trigger remains available.
