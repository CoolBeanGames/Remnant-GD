# F1 tools followup and item-pile performance

The three pending October 13 reports were read with their original screenshots: repeated Sweep prompts while holding a fan, automatic Mulcher repairs, and a per-light cone switch. Their originals and individual resolution records stay in the local issue inbox. This pass also addresses the requested large-pile optimization and live flashlight recovery.

## Fan controls

Fan attachment controls copy their entry array into a new prompt_set before adding Sweep/Suction/Empty Bag. The reusable carry Resource is never modified, so repeated HUD refreshes and other fan instances keep a bounded prompt list. The actual display is exercised for 240 refreshes. The wind loop now uses a dictionary for duplicate-body detection. Normal pickup, rotation, B ghost placement, J sweep, H suction/blow and E power remain available.

## Automatic Mulcher Repair

Buy **Automatic Mulcher Repair** in the computer's Mulch tab for **100 banked mulch coins**, once. It requires the installed Mulcher and the run's bin, like the existing Mulch tab. Data/Mulch/auto_repair.tres applies the editable `automatic_repair` effect. The tier persists across New Game through the normal profile upgrade system.

A broken machine starts its normal repair as soon as spendable score covers the cost. It pays the current escalating score price once, waits the existing repair duration (four seconds by default), clears damage and raises the next price. Insufficient score leaves it waiting; normal score rewards can fund it later. Saved in-progress repairs resume without a second charge. Manual E interaction still shares the same guarded repair function. The physical Status display shows AUTO REPAIR / ENABLED or WAITING FOR SCORE. [Mulch authoring](Mulch/README.md).

## Per-light cone choice

After the Light Beam Hood upgrade, press **K** while holding or looking at a particular light to choose Cone Light or Omni Light. It changes only that light. Its hood mesh follows the selection; E remains the independent power switch and L remains the coloured lens control. Other lights keep their own choice. `beam_hood_enabled` is the purchased capability; exported `beam_hood_active=true` is its saved selection. Older upgraded lights default to their original cone behavior.

Scripts/Actors/work_light.gd extends switchable_prop, UID uid://41vpi4kluaya. API `set_beam_active(value)`, `cycle_lens`, power application and the prompt getters; it depends on WorldState, Blackboard and the existing prompt/input services. If the project has no `toggle_light_beam` InputMap action, it registers K at runtime. An authored action keeps its binding. Dynamic SpotLight3D/hood creation and portal light masks remain shared with the original upgrade system. WorldState saves the new selection independently of colour, power and upgrade permission.

## Flashlight and performance

[T flashlight controls and live Blackboard updates](PLAYER_FLASHLIGHT.md). [Bounded world snapshots, fair cleanup, fan scanning and measured workloads](PHYSICS_PERFORMANCE.md).

Verification uses actual scene instances, rendered controls, disk save/reload, repair charging/countdown and New Game, actual item sleep/wake contacts, removals during batching, continuous arrivals during culling, and the existing save/carry/portal/rail/chute suites. Test logs and save data remain private. The development summary records final Windows build, diagnostics and publication results.
