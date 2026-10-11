# Reusable developer toolkit

The complete portable package lives in `addons/dev_toolkit/`. Copy that folder to the same path in another Godot project and enable Dev Toolkit in Project Settings → Plugins, or add dev_tools.tscn as a single autoload/persistent scene. Do not install both. Tested in a separate project without any Remnant singleton. See addons/dev_toolkit/README.md for full setup and host integration.

## Resource-driven commands

Remnant selects `Data/Debug/commands.tres` on its DevTools context. The portable scene selects `addons/dev_toolkit/default_commands.tres`. Every catalog entry is a DevConsoleCommand resource with a script, command prefix, aliases, usage, description and enabled flag. Add a scripted resource to the array to add code; no console branch is needed. Prefixes ignore case, longest prefix wins, and enabled commands generate help automatically. `echo` is a working example. Keep enabled names/aliases unique; equal prefixes use catalog order. Scripts validate their arguments and are trusted project code, not strings evaluated as arbitrary scripts. See Data/Debug/README.md.

Example:

```gdscript
extends DevConsoleCommand
@export var amount: int = 10
func execute(arguments: Array[String], context: DevToolsContext) -> String:
    context.adapter.set_blackboard("bonus", amount)
    return "Bonus = " + str(amount)
```

Create a resource with this script, set command/usage to `bonus`, and add it to the catalog. The amount is editable in the resource. `context.register_command(resource)` supports runtime extensions too.

## Host integration and compatibility

Only Scripts/Debug/remnant_dev_adapter.gd refers to Blackboard, Flags, SaveGame, WorldState or the Remnant movement controller. Global/dev_tools.gd selects that adapter and the Remnant command catalog. The original Global tool scripts and Scripts/Debug/movie_encoder.gd are thin compatibility wrappers retaining their paths, UIDs and public APIs. Existing F1/F2/F3/F4/F6/tilde controls and save format remain unchanged. Core UI implementations live entirely in the addon.

DevToolsAdapter's default values/flag_values dictionaries make empty-project inspection and setters useful immediately. Connect real host data by overriding snapshot/setter/input/teleport/movement hooks. Its save reader supports Variant or JSON without loading resources/game state. Optional player_path or devtools_player group enables generic teleport; fly/noclip need the host movement hook. Report context is serializable adapter metadata under report.json context. Each UI has exported hotkeys/enabled shortcut state/tools_context. Output directories and recording FPS/FFmpeg path remain editable. FFmpeg is optional for all tools except video recording; Windows x86_64 recording can download a verified private copy on its first start request if PATH/cache have none. This stays inside the reusable addon. See Data/RECORDING.md for setup, cancellation, platform support and manual overrides.

DevToolsContext owns modal state: reporter drafts block other modals; switching console/inspector restores the previous ownership before acquiring the new one; close restores prior pause, mouse and host lock. Remnant's always-processing menus retain their existing guards. Other hosts can use any_modal_open()/modal_changed to gate their own always-processing inputs. Only one toolkit instance per application is intended.

## API / identities

| Script / inheritance / identity | API and state |
|---|---|
| Global/dev_tools.gd / uid://dclujrrkfn2k8 | DevTools autoload / extends context; _init selects Remnant adapter/catalog, no additional public API. |
| Scripts/Debug/remnant_dev_adapter.gd / uid://c6fs874bxfxe1 | DevToolsAdapter subclass; snapshot/setters, restore_input_lock, save_snapshot, player/movement, teleport and set_movement_mode overrides; report_context adds score/player position. Remnant singleton dependencies remain here. |
| addons/dev_toolkit/context.gd / uid://cno10rs6njijn | DevToolsContext / Node; exports adapter, command_catalog. tools/active_modal/modal_snapshot. signal modal_changed(active_tool). resolve(owner,path), register_tool, tool, tool_open, any_modal_open, enter_modal/leave_modal, modal_lock_value, blackboard_snapshot, register_command, execute, help_text, tokenize, parse_name, format_value. |
| addons/dev_toolkit/adapter.gd / uid://cejy1qmj1ob56 | DevToolsAdapter / Resource; exports values, flag_values, save_path/format, input_lock_key, player_path/movement_path. blackboard_snapshot/set_blackboard, flags_snapshot/set_flag, save_snapshot, capture_input_lock/set_input_locked/restore_input_lock, player/movement, teleport, set_movement_mode(mode,requested), report_context. |
| addons/dev_toolkit/command.gd / uid://pfy00htt6idf | DevConsoleCommand / Resource; exports command/aliases/usage/description/enabled. execute(arguments,context)->String override for script code. No scene dependency/signals. |
| addons/dev_toolkit/command_catalog.gd / uid://bl1n0maiuov6y | DevCommandCatalog / Resource; exports commands:Array[DevConsoleCommand]; editable .tres catalog. |
| addons/dev_toolkit/dev_console.gd / uid://dkj5ov18n8s3j | CanvasLayer; exports tools_context, toggle_key, enabled. Registry console; UI/history, execute/help_text/tokenize delegate to context; open_console/close_console and history/submission. No Remnant dependencies. |
| addons/dev_toolkit/debug_inspector.gd / uid://wxvr6uyxkdfj | CanvasLayer; exports tools_context, enabled, blackboard_key/flags_key/save_key. Registry inspector; open_inspector/close_inspector/refresh_view/read_save_text/format_value via context/adapter. |
| addons/dev_toolkit/issue_reporter.gd / uid://c7vtjdmwe04h5 | CanvasLayer; exports tools_context/toggle_key/enabled/report_directory. Registry reporter; screenshot/text/modal state. issue_saved(path), open_report/close_report/save_report. Adapter supplies report context; JSON+PNG writes retained. |
| addons/dev_toolkit/gameplay_recorder.gd / uid://b6wmxodmnl7gy | CanvasLayer; exports tools_context/toggle_key/enabled/output_directory/ffmpeg_path/auto_download_ffmpeg/ffmpeg_cache_directory/capture_fps. Registry recorder; lossless capture/timing state/signals/API plus open_output_folder. pending_recording/ffmpeg_installer track optional asynchronous setup. Uses relative movie_encoder and ffmpeg_installer preloads. |
| addons/dev_toolkit/movie_encoder.gd / uid://cufkhjchai2o4 | RefCounted; worker thread/mutex/semaphore/bounded packets and result. start/enqueue/finish, exact RGB H.264/floatPCM mux. No scene/context/project dependencies. |
| addons/dev_toolkit/ffmpeg_installer.gd / uid://jt5ngre30be8 | DevFFmpegInstaller / Node; exports archive_url/checksum_url/cache_directory, max_download_bytes/max_executable_bytes (256 MiB), request_timeout (600 s), probe_timeout (10 s). busy/status_text track setup. platform_supported, start_install()->String, cancel, cached_executable. Signals status_changed(message), progress_changed(downloaded,total), finished(path,error). HTTPRequest downloads, worker SHA-256/ZIP/probe checks and atomic private-cache publication. No Remnant/context/authored-scene dependency. |
| addons/dev_toolkit/plugin.gd / uid://bj2iv3k6js3ug | @tool EditorPlugin; _enable_plugin/_disable_plugin conditionally manage own DevTools autoload; plugin.cfg descriptor. No runtime scene code. |

Scene dependency: addons/dev_toolkit/dev_tools.tscn contains context root plus reporter, inspector, console, logger and recorder CanvasLayers and default_commands.tres. Generic command script/resources live in addons/dev_toolkit/commands: help, set_flag, set_bb, set_score, teleport, shared movement_mode (fly/noclip), record, echo. Each handler inherits DevConsoleCommand and exports base metadata; movement_mode also exports its selected mode. Their only dependencies are context/adapter and the optional recorder. Data/Debug/commands.tres is a host-owned replaceable catalog referencing these resources.

Validation: Tests/dev_toolkit_test.tscn exercises arbitrary scripted command resources, aliases, longest-prefix dispatch, enabled flags, generated help, argument errors and standalone adapter/modal behavior. A copied-addon project with no Remnant autoloads also passed F1 JSON/PNG and actual rendered screenshot capture, F2/F3/F4 JSON save inspection, console and missing-FFmpeg behavior. Existing Remnant developer tools/menu regressions and byte-exact recorder plus rendered A/V capture passed.

The automatic installer was verified with an empty PATH/cache against the live Gyan provider, including SHA-256/encoder checks, recording auto-start, a finished MKV and fresh cache lookup. The reusable toolkit regression passed with the new dependency available entirely under the addon.

Tests/ffmpeg_installer_test.tscn also passed headless, rendered and copied-addon clean-project runs, covering offline integrity/failure/retry/cache cases, stalled-header/body cancellation and automatic recording after setup. The toolkit regression passed again in the clean project.

## Logging and review integration

The portable scene now includes `DevDebugLog` (F5) and its native `DevLogSink`. Use `context.log_info/log_warning/log_error(message, channel)` from portable code; `tool(&"logger")` exposes open/export/folder actions. Every bundled catalog includes the scripted `log` resource. Per-PID sessions preserve interrupted runs, exclude active instances and bound memory/file storage. The native sink uses `Logger`/`OS.add_logger` tested in Godot 4.7.2. Remnant configuration/API and crash-export limits: `Data/DEBUG_LOG.md`.

Modal state protects refusing/freed owners and deduplicates fallback contexts for separately instanced tools. Host input guards should use `any_modal_open()` so every tool is included. Console exports bound history (100), output (65,536 characters) and input (4,096 characters). Native logger, rendered viewer and addon-only regression runs passed.
