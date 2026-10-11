# Code review — 10 October 2026

The pre-review work was committed and pushed as `4996d1e`. This pass reviewed active production code, fixed specific lifecycle bugs and removed repeated work in physics/rendering paths. Current manual gameplay takes precedence over retired conveyor/crate designs. `.issues/inbox/` had no pending reports.

## Changes and evidence

| Area | Finding and final change | Evidence |
| --- | --- | --- |
| World snapshots | Every physics tick rediscovered nested rigid bodies; every burst spawn/removal rebuilt a full snapshot. Cache weak body handles between 10 Hz topology refreshes and coalesce registry changes into one deferred capture. Explicit saves capture synchronously. Session tokens discard stale restoration/capture callbacks. | Thirty same-frame spawns produce one complete snapshot; forced capture includes same-frame removals; added/detached/freed bodies and nested culling remain correct. |
| Pickup/placement | Repeated array copies, geometry discovery, inversions and query setup. Reuse build-session vertices/exclusions/query, use membership dictionaries and forward attachment iteration; restore surviving props during player teardown. | Basket parent/child attachments follow in the same tick; carry transparency/collisions, portal transfer, cancel/place and teardown regressions. |
| Mulch and notes | Unneeded deferred pellet jobs, repeated status/grid/prompt rebuilding and deep journal copies. Schedule output only at pellet threshold, coalesce jobs and cache display/prompt state; read note existence directly while retaining defensive snapshots. Mulch-bin sensor had reset its portal mask to workshop space. | Pellet/repair/save tests and portal/held/return bin sensing; journal mutations cannot alter stored data. |
| Pooled audio | Canceled sounds occupied slots; old owners could stop a later reused player. Add playback IDs and automatic release on stop; discard freed pooled objects safely. Fan/machinery persistent sources now use `Audio.set_spatial_active` with optional-stream support. | Cancellation/reuse ownership, invalid pooled nodes, blank/persistent spatial sources, dialogue/exertion and audio regression cases. |
| Sound timing | Lever pull/reset dispatched together; portal return close sound started too early. Dispatch pull at interaction, reset at reset start and close at animation completion. | Lever and portal animation-stage assertions. |
| Portal/room | An offscreen doorway kept rendering a second viewport; stable return-door state repeatedly replayed animation. Cull viewport updates and skip unchanged pose. Reuse room geometry, door mesh lists and a single per-check light snapshot. | Portal activation/crossing/held items/return/restoration, offscreen render mode, close timing, room visibility/protection/audio suites. |
| Player/UI | Recreated stair result objects and held prompt resources; stale scene references and incomplete modal guards. Reuse checks/prompts, safely purge externally freed scenes, restore options mouse ownership and use a shared modal guard. | Stair movement, prompts, scene lifecycle, title/options, wake-up, dialogue and tool ownership checks. |
| Developer tools | Console history/output could grow indefinitely; deferred standalone tools could create duplicate contexts, or overwrite a modal that refused to close. Bound console history/command/output, deduplicate pending context and protect modal ownership. | Memory limits, standalone/refusing/freed modal tests, existing command and inspector cases. |
| Diagnostics | Add portable F5 logger with thread-safe native engine capture, bounded rotation, independent sessions and diagnostic ZIP export. Instrument meaningful game/tool events. | Headless and rendered logger tests plus copied-addon project; current/previous ZIP contents and export failure/retry. |

## Measurement

The full audit's hierarchy lookup microbenchmark used 200 synthetic actors with 20 nested nodes and two rigid bodies, 20 repeated lookup ticks, seven samples, and the median. The legacy recursive search took **68,394 μs**, the cached reference lookup **3,881 μs**: **17.62×** in that sample. Separate repeats ranged roughly 11.76–13.76×. This isolates discovery overhead and does not measure whole-game FPS. Rendering savings are established by viewport mode/state assertions, not an invented frame-rate estimate.

## Coverage and verification

All **38** top-level regression scenes passed with Godot 4.7.2 after the attachment ordering fix and explicit audio fixture teardown. Tests ran from an isolated project identity, preserving the player's real save. Intentional logger warning/error probes are distinguished from application failures. Rendered recorder/encoder checks, the F5 viewer and an addon-only project supplement the headless suite. Source imports completed without parse errors. A normal Forward+ D3D12 gameplay startup smoke test exited cleanly, and tracked production resource references have no case mismatches. Machine-readable outcomes: [review_verification_2026-10-10.json](review_verification_2026-10-10.json).

Reviewed production areas: every Global service; Actors and shared physics/pool helpers; Player input/movement/look/wake-up/voice/breathing/pickup/placement; Level spawning/chute/grinding/staged lighting/room/guidance/messages/boundary/tallies; Portal rendering/transfer/return/space; Computer entries/effects/catalog/UI; Mulch station/bin/pellet; UI prompts/menus/readers/combo/dialogue; Dialogue resources/triggers; save loader/title/game startup; portable adapter/context/resources/console/inspectors/reporter/recorder/encoder/installer/plugin. Unchanged systems retain their existing designs after inspection; low-impact speculative rewrites were avoided.

The first regression pass exposed an attachment-order regression introduced during optimization. Forward parent-before-child traversal fixed it and the case passed again. One test used lowercase `checks passed` instead of `PASS`; its exit zero and assertions were successful. The audio lifecycle fixture required explicit teardown before immediate quit to avoid misleading ObjectDB shutdown warnings. These were resolved before final verification.

## API changes for maintainers

- `WorldState`: runtime `session`, `capture_scheduled`, `body_cache`; `_bodies(actor, refresh=false)` refreshes topology when requested. Public `capture()` remains immediate.
- `prop_placement`: runtime `ray_query`, `excluded`, `support_vertices` are per-build caches.
- `audio_player`: `playback_id`, `is_playback_active(id)`, `stop(id=-1)`; stop releases its pooled slot, `reset()` remains silent. Store the ID with a borrowed player if retaining cancellation ownership.
- `Audio.set_spatial_active(player:AudioStreamPlayer3D, active:bool)` manages optional persistent sources; transient production cues use `Audio.play_3d/play_global` and pooled players.
- `DevConsole`: exported `maximum_history=100`, `maximum_output_characters=65536`, `maximum_command_characters=4096`.
- `DevToolsContext`: `log_info/log_warning/log_error`, pending-context deduplication and protected modal transition. `log [open|export|folder]` is a scripted resource in both catalogs.
- New logger API, UIDs, configuration, scene dependency and crash-export behavior are documented in [DEBUG_LOG.md](DEBUG_LOG.md).

This is a targeted source and regression review, not proof that all possible gameplay is bug-free. Broad hardware/GPU profiling, long-session soak testing and earlier Godot versions were not established by this pass. Crash exports preserve diagnostic breadcrumbs; they cannot run during an abrupt crash or guarantee a final disk write.
