# Item piles and bounded world updates

WorldState used to rebuild every actor's complete save record ten times a second and check every tracked item for falling through the floor on every physics tick. The cost grew with the entire pile, including sleeping items. The fan also used a linear duplicate search for each body in its wind volume.

Regular snapshots now run at a 0.5-second cadence, coalescing births/removals into background work. Each physics tick builds at most 32 records with a soft 2,000-microsecond budget checked between records. Sleeping ordinary items reuse a record while their actual wrapper/body transforms still match. A completed generation publishes its list atomically. New or removed actors invalidate their cached records; a new world clears the entire generation. Background Blackboard snapshots can lag live movement while a batch completes. Explicit `capture()` and every normal disk save synchronously capture current state, including score changes, body topology, velocities, supports and containers.

Fallen-item cleanup checks up to 64 registry entries per physics tick and advances its cursor even while items are continually added or removed. Below-floor items still use their original `on_culled` hook, so unread notes return to the spawn pool. Explicit save cleanup checks the entire registry before writing. Camera/player transforms continue updating each tick. The fan's per-volume duplicate set is now a dictionary, giving constant-time membership without changing its forces.

## Configuration and API

Global/world_state.gd is the WorldState Node autoload, UID uid://b3q7iixomu4d7. `snapshot_interval=0.5`, `snapshot_items_per_tick=32`, `snapshot_budget_usec=2000` and `cull_checks_per_tick=64` are exported tuning values. `capture()` keeps its existing no-argument API and exact-refresh semantics. `capture_background()` queues bounded work. `begin`, `track`, `untrack`, `spawn_item`, `cull` and restoration APIs remain available. Record caches, scan cursors, weak body handles and unfinished generations are transient; they are not written into the Blackboard/save.

The budget is a soft per-record limit, not a maximum for the complete frame: setup, publishing, engine work, explicit serialization and OS scheduling take additional time. Keep the regular physics rate, CCD, masses, friction and collision response authored for gameplay. The optimization is in world bookkeeping and fan scanning. Repair countdown updates also store only the changed timer until completion, rather than cloning the unchanged mulch contribution ledger every frame.

## Measured results

The same actual nine-item workload was run sequentially against the previous Windows release PCK and the updated source with Godot 4.7.2 / Jolt. Both 800-item headless cases use 240 sampled physics ticks after five seconds of settling. The moving case explicitly keeps all 800 bodies awake. A separate fan scan includes 800 bodies in an enlarged wind volume with force disabled to isolate scanning cost.

| Workload | Before | After | Measurement |
| --- | --- | --- | --- |
| 800 sleeping items | 61.207 ms | 4.388 ms | 95th percentile world-maintenance time |
| 800 forced-awake items | 115.411 ms | 5.164 ms | 95th percentile world-maintenance time |
| 800 bodies in the fan volume | 6.100 ms | 3.259 ms | Median fan scan time |
| Rendered workshop, 400 sleeping items | 48.467 ms | 13.433 ms | Mean full frame, 1280×720 / Forward+ / D3D12 / GTX 1660 Super |
| Same rendered workshop | 122.858 ms | 24.437 ms | 95th percentile full frame |

These measurements describe controlled workloads on this machine. The final workshop fixture disables only its intake sensor to retain exactly 400 live sleeping items; authored lighting and animation remain. Rendering quality, hardware and fully active contact piles can still determine frame rate. Alternative contact-report and mesh-LOD settings were measured but are not applied as gameplay changes. The baseline is Builds/Windows_2026-10-13_13-46-06/Remnant.pck; the current benchmark fixture loads externally against that PCK for the comparison. Original intermediate measurements with an invalid moving fixture are not used in these results.

## Reproduce and verify

Tests/item_pile_benchmark.tscn accepts `-- --count=800 --phase=settled --output=ABSOLUTE_JSON_PATH`. Use phase=moving for sustained forces, `--fan` for the oversized scan, and `--workshop` with a rendered launch for the real stage. Optional `--lod` and `--contacts` affect only the benchmark. It records frame/world/fan/GPU samples, actual awake-body counts and renderer; rendered runs save a sibling image. Run serially with isolated APPDATA and avoid competing benchmark processes. The fixture disables saving and contains the pile within its test floor/walls.

Tests/world_budget_test checks natural sleep, force wake-up, bounded/atomic batches, exact disk captures, removal during batching, cleanup fairness under continuous births, empty worlds and cache invalidation. Tests/gameplay_review_test additionally checks coalesced background capture, cancellation by forced saves and runtime-added/detached rigid bodies. Save, portal assemblies, carried attachments, rail cargo and chute/notes tests cover the affected lifecycle paths. [Followup controls and repairs](ISSUE_TOOLS_FOLLOWUP.md).
