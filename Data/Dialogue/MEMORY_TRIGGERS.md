# Memory objects and completion

Look at a required prop within the player's normal 3 m interaction ray, then press E on its world prompt. Each object starts its editable dialogue and sets its own run flag. Looking alone never acknowledges an objective. After every required flag is true, the room's MemoryCompletion node sets its existing `memory N complete` flag. Returning through the door then closes the completed portal through the existing travel system. Unfinished memories retain ordinary return/reentry and the purchase lock.

## Current objects

| Memory | Required E objects | Individual flags | Completion flag |
| --- | --- | --- | --- |
| Apartment / 1 | Family photo, landline phone, bills on the table (existing PileOfMail art) | memory 1 photo; memory 1 phone; memory 1 bills | memory 1 complete |
| Warehouse / 2 | First hydraulic press, first lathe, first control cabinet, production-office phone, office paperwork | memory 2 press; memory 2 lathe; memory 2 cabinet; memory 2 phone; memory 2 paperwork | memory 2 complete |
| Hospital / 3 | Ward 01 first bed, treatment trolley, nursing phone, nursing paperwork | memory 3 bed; memory 3 trolley; memory 3 phone; memory 3 paperwork | memory 3 complete |

The apartment's coffee pot, phone and TV also have look-only flavor. Aim steadily for 0.8 seconds to hear/read it; no button, completion contribution or Flags entry is required. The phone supports both independent behaviors. Flavor uses Blackboard.memory_flavor_seen (array of stable IDs) to play once per run and survive Continue. New Game clears it and all objective/completion flags. Warehouse/hospital objects and all new dialogue are editable first drafts using existing scenery.

## Edit or add an object

In the environment scene, select the prop's art wrapper and use Scripts/Dialogue/memory_object.gd. It inherits environment_art, preserving existing pose overrides and imported art/materials. Assign a memory_trigger_data resource in Story. The current resources and individual dialogue sequences are under Data/Dialogue/Memories/.

For an E objective, give Interaction Flag a unique stable name, set Prompt Text, and assign Interaction Dialogue. Add that same flag to the room's MemoryCompletion Required Flags list. Its Completion Flag must match the computer memory resource exactly. An empty required list never auto-completes. All existing individual flags restored from a save immediately reconstruct completion if necessary; an acknowledged object hides its prompt and does not replay its interaction dialogue.

For look flavor, leave Interaction Flag empty (or keep it for a combined object), give Look Id a unique stable ID and assign Look Dialogue. Look Delay sets the dwell time. Flavor sequences should keep Once off: the trigger owns repetition via Blackboard without creating dialogue once-flags. Sequences use existing dialogue_line text, typing/hold/fade timing and optional pooled Audio/Vocals voiceovers. Empty optional text/voice assignments are safe. E advances existing dialogue before world interactions; the object's E prompt hides while captions own that key, then returns if the object is still unacknowledged.

The existing solid collider must be beneath the prop wrapper. For small props, the level has a separate StoryAim Area3D with a configurable BoxShape3D; it enlarges only ray targeting, never physical collision. Mask=0 and monitoring=false keep it passive. Portal layer remapping includes these areas. By default, objective prompts follow a marker just above and in front of the actual visible ray-hit surface, preventing large model bounds from hiding labels behind neighboring furniture. Assign optional Prompt Anchor to override this with an authored marker. Ordinary ray distance, solid-wall occlusion and interaction_enabled ancestry remain in force.

## Runtime API and identity

| Source / class | Base / UID | Configuration and API |
| --- | --- | --- |
| Scripts/Dialogue/memory_trigger_data.gd / memory_trigger_data | Resource / uid://ratdytccuqod | interaction_flag, prompt_text, interaction_dialogue, look_id, look_dialogue, look_delay; editable data only |
| Scripts/Dialogue/memory_object.gd / memory_object | environment_art / uid://dsqovkaam6ygx | story, prompt_anchor; interact(), get_look_prompts(), on_look_started(ray). Registers interact for objectives and look-prompt for targeting; adds existing object_prompts provider. Idle processing is disabled; only the actual focused target follows its prompt marker and starts a flavor dwell. |
| Scripts/Dialogue/memory_completion.gd / memory_completion | Node / uid://cxq7mobyly766 | completion_flag, required_flags; refresh(). Subscribes to individual Flags changes and restores aggregate state on ready. Empty/missing flags cannot complete. |
| Scripts/Player/raycaster.gd / raycaster | RayCast3D / uid://dopt5ybemmifn | Calls an optional on_look_started(self) only when its actual grouped target changes. Existing targets retain their behavior. |

Pause, wake-up/input locks, F-key/console modals and PC/note viewing suspend flavor. Busy dialogue defers flavor without queuing a flood. A completed E interaction logs one memories event and checkpoints through SaveGame when saving is enabled. Flavor IDs use the ordinary autosave. The system does not add an objectives panel or counter.

F9 previews preserve purchased ownership; inspecting a preview sets only that destination's own named flags. A preview cannot close a different owned memory. Cycling back restores normal owned completion behavior. These are run flags; permanent profile currencies are untouched.

## Verification

Tests/memory_triggers_test.tscn instantiates the production level, aims the actual remapped ray, sends actual E key events, checks the 3/5/4 objective counts and every required flag, separates coffee/phone/TV flavor from objectives, checks pause/input ownership and repeat suppression, saves/Continues partial progress, completes and releases portals through the production return path, and checks New Game reset. Isolate APPDATA; do not touch the user's real save. Rendered captures additionally verify the current world prompts/captions with authored lighting and the player's flashlight. Related existing memory_portals, memory_unlocks, dialogue and prompt_system fixtures verify travel, purchases, voice/skip and reusable binding behavior.
