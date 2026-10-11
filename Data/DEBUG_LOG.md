# F5 debug log and crash diagnostics

Press **F5** from gameplay or a menu to open the log; F5 or Escape closes it and restores the previous pause, mouse and input lock. It shows engine prints, warnings/errors and game breadcrumbs in a scrollable text view. Filter by severity and channel/text, or turn Follow off to inspect older entries. F1 report drafts keep ownership until closed.

Choose **EXPORT LOGS** to write a ZIP, then **OPEN EXPORT FOLDER** to locate it. Console commands `log open`, `log export` and `log folder` offer the same actions. The ZIP includes current and previous session log segments, their session markers, recent engine logs, the in-memory entries, and engine/OS/rendering/scene information. It does not deliberately dump Blackboard, flags or the save file. Authored engine prints are captured as written, so avoid printing secrets.

Logs live in `user://debug_logs/sessions/<timestamp-pid-id>/`; exports default to `user://debug_logs/exports/`. Independent session folders prevent concurrent editor/test instances from overwriting each other. A session without a clean-exit marker is retained for the next export when its process is no longer running. Restart after a crash, then export. An interrupted session can also mean forced termination: this is diagnostic evidence, not a crash dump or a guarantee that the final event survived.

Memory defaults to 2,000 entries. Disk defaults to one 2 MiB active segment plus two rotated segments per session, with eight inactive/active recent session slots and preservation of the selected unexported interrupted session. Engine files are truncated to their latest 8 MiB each when exported. Native callbacks write and flush events under a mutex, never touching UI/SceneTree or recursively printing. The visible view refreshes only while open and when entries change; game diagnostics describe meaningful transitions rather than every physics frame.

## Add a debug statement

```gdscript
DevTools.log_info("Door opened", "door")
DevTools.log_warning("Optional asset unavailable", "audio")
DevTools.log_error("Save write failed: " + error_string(error), "save")
```

Remnant also exposes `DebugLog.info/warning/error(message, channel="game")`. Prefer the context helpers in reusable code; they safely do nothing when a host omits the logger. Native engine prints, warnings and errors are captured automatically. Current breadcrumbs cover scene/room/door/portal lifecycle, unlocks, world restoration/culling, save operations, purchases, note reads, combo payout, mulcher production/repairs, local report submission, console command metadata and recorder setup/start/finalization/errors. Console breadcrumbs include the command prefix and argument count, not raw argument values.

## Authoring / API

| Script / identity | Configuration / state | Public API |
| --- | --- | --- |
| `Global/debug_log.gd`, UID `uid://bl8ie2k8ffy87` | `DebugLog` autoload; thin compatibility wrapper | Inherits the portable core |
| `addons/dev_toolkit/debug_log.gd`, `DevDebugLog : CanvasLayer`, UID `uid://c537rw6o68epb` | `tools_context`, `toggle_key=F5`, `enabled`, `capture_engine_messages`, `log_directory`, `export_directory`, `max_entries`, `max_segment_bytes`, `archive_segments`, `retained_sessions`; runtime `context`, `is_open`, `sink`, session/previous paths and markers, `previous_unclean`, `last_export_error`, UI controls | `info/warning/error(message,channel)`, `open_log()`, `close()`, `get_entries()`, `refresh_view()`, `export_logs(destination_directory="")->String` (absolute ZIP or empty), `open_export_folder()`, `shutdown(mark_clean=true)`; signal `logs_exported(path)` |
| `addons/dev_toolkit/log_sink.gd`, `DevLogSink : Logger`, UID `uid://budgvvoesadkp` | Thread-safe ring, mutex, file/segment/session state; native Logger callbacks | `configure`, `append`, `snapshot`, `sequence`, `flush`, `close_file`, `storage_error` |
| `addons/dev_toolkit/commands/log.gd`, `DevConsoleCommand`, UID `uid://mjnvhpq6avni` | Scripted `log` resource in portable and Remnant catalogs | `execute(arguments,context)`; open/export/folder |
| `addons/dev_toolkit/context.gd`, `DevToolsContext : Node` | Registered `&"logger"`; shared modal ownership | `log_info/log_warning/log_error(message,channel="game")`, existing `any_modal_open()` |

The portable `dev_tools.tscn` includes a Logger child. Copy the whole addon and use its existing scene/plugin installation; do not also install a second Remnant logger. Individual tools share a pending fallback context instead of accidentally making several deferred contexts. A modal cannot replace an owner that refuses to close. Remnant's pause, options, dialogue and computer handlers use `DevTools.any_modal_open()`.

Tested with Godot 4.7.2, including native `Logger`/`OS.add_logger`. Earlier-engine compatibility is unverified. `Tests/debug_log_test.tscn` covers real native print/warning/error and worker capture, memory/file rotation, filters, export/retry, prior interrupted sessions, active-process exclusion, command integration and modal ownership. The warning/error capture probes in that test are intentional. Rendered UI and an addon-only project also passed.
