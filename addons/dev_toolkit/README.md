# Dev Toolkit for Godot

Copy the entire `addons/dev_toolkit/` folder into another Godot project. The addon contains the F1 issue reporter, F2/F3/F4 state inspectors, tilde console, F5 log/export, and F6 gameplay recorder. The core does not require Remnant scenes or its Blackboard, Flags, SaveGame, WorldState, or audio singletons.

The tested engine version is Godot 4.7.2. Other versions must support the APIs used here, including `OS.execute_with_pipe` for recording; compatibility with earlier releases has not been verified. The recorder needs FFmpeg with `libx264rgb`. On Windows x86_64 it can download a private copy when recording is first requested and FFmpeg is missing. Reporting, inspecting, and console commands do not require FFmpeg.

## Install

Choose one installation method:

1. In **Project Settings → Plugins**, enable **Dev Toolkit**. It adds the `DevTools` autoload pointing to `res://addons/dev_toolkit/dev_tools.tscn`.
2. Add that scene yourself as an autoload, or instance it once in your persistent application scene. This allows an inherited scene with your own adapter, command catalog, and hotkeys.

Use one toolkit instance per running application. The optional plugin never overwrites an existing `DevTools` autoload; disabling it removes only the exact autoload scene it installed. Remnant already supplies compatibility autoloads and a host adapter, so it does not need the plugin enabled.

## Controls

| Key | Tool |
|---|---|
| F1 | Capture the current game viewport and describe an issue |
| F2 | Scrollable Blackboard snapshot |
| F3 | Scrollable flag snapshot |
| F4 | Read the actual file configured by the adapter |
| F5 | Debug log, severity/channel filters and diagnostic ZIP export |
| Tilde / backtick | Command console; Enter submits, Up/Down recalls history |
| F6 | Start or stop native-size lossless recording with game audio |
| Escape | Close the open modal |

Keys are exported properties on the respective tool nodes, so each host can change or disable them. Menus preserve previous pause and mouse state. A reporter draft blocks other debug modals so typed text and its screenshot stay together. The adapter manages any additional host input-lock state. Host gameplay/menu input handlers should return when the toolkit reports an open modal; stopping a paused simulation alone does not stop nodes that process input while paused.

## Reports and recordings

F1 saves a local report description/context and sibling `screenshot.png`. The screenshot contains the game viewport before the popup; it does not record the desktop or automatically start an agent. Configure each tool's output directory. Project-local defaults are `.issues/inbox/` and `.recordings/`; exported projects fall back to writable `user://` storage. Add those project-local folders to `.gitignore` if reports and clips should remain private.

Have future coding agents inspect the inbox at the start of a session, read each pending report, actually view its screenshot, and record the implementation and checks in a sibling `resolution.md`. Keep the original description/image and mark a report resolved only after its request is addressed. Remnant's `ISSUE_REPORTER_WORKFLOW.md` and `AGENTS.md` provide a template; those repository policies are not required by the addon at runtime.

The recorder captures the rendered 8-bit RGB viewport without resizing or chroma subsampling, and stereo 32-bit float PCM from the game mix. It keeps playback audible. It does not raise graphics quality, capture a microphone, or make GPU readback/encoding free. The default is 60 FPS; reduce capture FPS to ease load. Delayed frames repeat to retain wall-clock timing. Full queues, audio overflow, encoder failure, or a changed window size stop a clip with an explanation. Normal application shutdown finalizes pending work; a forced process kill cannot guarantee a playable file.

### Automatic FFmpeg setup

The recorder first uses a nonempty `ffmpeg_path` override, otherwise searches PATH and its private cache. If none is available, **F6** or `record start` starts an asynchronous download on Windows x86_64. Download progress appears in the game; recording starts when setup finishes. Press F6 again or use `record stop` to cancel. A failed or cancelled setup can be retried with the normal start command.

The default source is Gyan's release essentials ZIP, linked by [FFmpeg's download page](https://ffmpeg.org/download.html#build-windows). The installer verifies the archive against the publisher's SHA-256 file before extracting the encoder. `ffmpeg_cache_directory` defaults to `user://dev_toolkit/ffmpeg`; later recordings and launches reuse the cached executable. Setup does not change PATH, replace an existing installation, or require a system install. No download occurs merely because the project starts, or when recording is requested from headless/Movie Maker execution.

Set `auto_download_ffmpeg = false` for manual setup. Set `ffmpeg_path` to a local executable to use a particular build; this override is authoritative, so an invalid override reports an error rather than downloading a replacement. Other platforms need a manually installed FFmpeg build with `libx264rgb`, available on PATH or through the override. Network, verification, extraction and unsupported-platform errors are shown in the recorder status.

For a custom setup flow, `ffmpeg_installer.gd` exposes `DevFFmpegInstaller`, a Node with `start_install()`, `cancel()`, `cached_executable()` and `platform_supported()`. Add it to the tree before starting. `start_install()` returns an empty String on successful dispatch, or an immediate error; `finished(path, error)` reports completion. `status_changed(message)` and `progress_changed(downloaded, total)` drive a host UI. Exported source URLs, size limits and timeouts can be configured before starting. Archive and checksum sources use HTTPS; loopback HTTP supports local test mirrors. Staging and cache discovery preserve a valid prior build on failure and verify executable digests on later launches. The cached build includes provenance metadata and available provider license/readme files. See Remnant's `Data/RECORDING.md` for full API identities and defaults.

## Connect your game's state

The scene root is `DevToolsContext`. Its exported **Adapter** is a `DevToolsAdapter` Resource; **Command Catalog** is a `DevCommandCatalog` Resource. The default adapter keeps an in-memory `values` Dictionary and `flag_values` Dictionary. This makes the menus usable in an empty project immediately; it does not implement your game's persistence.

For a real host, write a script extending `DevToolsAdapter` and assign a resource using that script to Adapter. Override the methods that map to your game's services:

| Adapter API | Host responsibility |
|---|---|
| `blackboard_snapshot()`, `set_blackboard(key, value)` | Read all your live values and write a value |
| `flags_snapshot()`, `set_flag(key, enabled)` | Read all flags and update flags through the host's normal signal-aware API |
| `save_snapshot()` | Read the configured disk save without loading, mutating, or saving the game |
| `player()`, `movement()` | Resolve your active player and movement controller |
| `teleport(position)` | Move the player and update any persistence/velocity state |
| `set_movement_mode(mode, requested)` | Implement `fly`/`noclip` for your controller; `requested` is an empty String for toggle, or the user's on/off argument |
| `report_context()` | Add useful, serializable host context to the issue report |
| `capture_input_lock()`, `set_input_locked(enabled)`, `restore_input_lock(state)` | Preserve the host's input lock across debug modals |

The base adapter exports `save_path`, `save_format` (Variant or JSON), `input_lock_key`, `player_path`, and `movement_path`. Assign the save format your project actually writes. Empty/missing save files show an explanatory inspection result. The generic input lock uses `player_input_blocked` in its value dictionary; overriding it lets your host use a different mechanism. Unsupported player/movement operations return an explanation rather than pretending to work.

`context.tool("reporter")`, `tool("inspector")`, `tool("console")`, and `tool("recorder")` resolve the registered UI services. `any_modal_open()` lets host input handlers protect their shortcuts while typing. Custom tool nodes can join with `register_tool(name, node)` and use `enter_modal(name)` / `leave_modal(name)` for the same ownership rules. Custom modals should implement `close()` so switching tools can release their ownership. The `modal_changed(active_tool: StringName)` signal reports modal changes; an empty name means no toolkit modal is open.

Context runtime state includes `tools`, `active_modal`, and `modal_snapshot`; the snapshot stores prior pause/mouse/input-lock state. `blackboard_snapshot()` hides the toolkit's temporary input-lock override. Each core UI node exports `tools_context` for explicit context lookup and `enabled` to disable its shortcut handler. Reporter/console/recorder use `toggle_key`; the inspector uses `blackboard_key`, `flags_key`, and `save_key`. Disabling shortcut handling does not prevent calling a tool's public methods directly. Core UI scripts are CanvasLayers and can also be reused individually under a context.

## Add a command resource

Each command is a Resource whose script extends `DevConsoleCommand`. Set its `command` prefix, optional `aliases`, `usage`, `description`, and `enabled` in the Inspector, then put that resource into your catalog's `commands` array. Add or replace commands by editing the catalog; the console itself does not need a new branch.

For example, save this as your own command script:

```gdscript
extends DevConsoleCommand

func execute(arguments: Array[String], context: DevToolsContext) -> String:
    if arguments.size() != 1:
        return 'Usage: greet "name"'
    var recipient := context.parse_name(arguments[0])
    context.adapter.set_blackboard("last greeting", recipient)
    return "Hello, " + recipient
```

Create a Resource using that script and set `command = "greet"`, `usage = 'greet "name"'`, and a description. Add it to a `DevCommandCatalog`. Typing `greet "friend"` now runs that resource's script. Resource scripts are trusted project code: the console does not evaluate arbitrary text as GDScript or shell commands.

Prefixes and aliases ignore case. Matching chooses the longest token prefix, so `weather` and `weather forecast` can coexist. Arguments retain their original quoting; `parse_name()` decodes quoted names. Use `tokenize()` for quoted command text and parse JSON explicitly for values when needed. A handler validates its own argument count/types and returns a String explaining its result or usage. Disabled resources do not execute or appear in generated help. Keep prefixes and aliases unique to avoid ambiguous matches.

The default catalog provides `help`, `set flag`, `set bb`, `set score`, `tp`, `fly`, `noclip`, `record`, and `echo`. It can be duplicated and edited per project. `context.register_command(resource)` also adds a resource at runtime. `context.execute(text)` is the programmatic dispatch API, and `help_text()` derives documentation from the current resources.

## Optional editor installer

`plugin.gd` is an `@tool` EditorPlugin with no runtime dependencies or exported state. `_enable_plugin()` installs `DevTools` only when absent; `_disable_plugin()` removes it only when its path still matches this addon's scene. `plugin.cfg` supplies the name/version/description. Manual scene installation does not require these editor files.

## Verification

`Tests/dev_toolkit_test.tscn` checks a custom scripted command Resource, longest-prefix dispatch, aliases, disabled commands, validation/usage, generated help, typed Blackboard values, flags, score and modal restoration. It also runs when copied into a clean host project containing only this addon. A separate clean-host smoke check exercised every menu, JSON save inspection without changing the file, local report JSON/PNG output, actual rendered viewport capture, and graceful missing-encoder handling. The editor installer was checked for installation, matching-path removal, and preservation of a pre-existing foreign autoload. Remnant's existing developer-tool and recorder regression scenes remain available for broader integration coverage.

Automatic FFmpeg setup was also verified against the live default provider with an empty PATH/private cache: checked download, native recording auto-start, a completed MKV and a fresh cached-executable lookup. The toolkit regression passed after integrating setup.

`Tests/ffmpeg_installer_test.tscn` passed headless/rendered runs and a copied-addon clean project. Offline fixtures exercise HTTP/integrity/archive/size/probe failures, extraction safety, cache preservation/corruption, retry and cancellation while response headers or bodies stall. Native checks cover automatic recording, progress, cancel/late completion, duplicate-start protection, cache reuse and manual setup. The tests do not contact public download servers; real executable/capture checks use a local FFmpeg when available.

## Logging and review integration

The portable scene now includes `DevDebugLog` (F5) and its native `DevLogSink`. Use `context.log_info/log_warning/log_error(message, channel)` from portable code; `tool(&"logger")` exposes open/export/folder actions. Every bundled catalog includes the scripted `log` resource. Per-PID sessions preserve interrupted runs, exclude active instances and bound memory/file storage. The native sink uses `Logger`/`OS.add_logger` tested in Godot 4.7.2. Remnant configuration/API and crash-export limits: `Data/DEBUG_LOG.md`.

Modal state protects refusing/freed owners and deduplicates fallback contexts for separately instanced tools. Host input guards should use `any_modal_open()` so every tool is included. Console exports bound history (100), output (65,536 characters) and input (4,096 characters). Native logger, rendered viewer and addon-only regression runs passed.

## Optional recorder input overlay

F7 toggles a Windows DirectShow camera preview at the top-left 15% of viewport width with native aspect ratio; F6 still controls lossless recordings. Microphone input uses AudioStreamMicrophone on a private muted capture bus while recording, mixed with the existing game audio. Enable audio/driver/enable_input in the host project before restarting. Set input_mode_key, webcam_width_fraction and microphone_gain on the recorder. Missing cameras/permissions are optional. First DirectShow video device and AudioServer Default microphone are used; camera pipe IO stays on its worker, buffers stay bounded and disabling/exit releases owned devices/processes. Camera source caps at 1,280 pixels/30 FPS; game output retains native lossless quality. See Data/RECORDING.md for setup/download/lifecycle limits.
