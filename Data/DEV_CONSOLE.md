# Tilde developer console

The current implementation is portable under addons/dev_toolkit; the original Global/script paths are compatibility wrappers. See Data/DEV_TOOLS.md for adapter, resource commands, canonical scripts and API identities.
Press the tilde/backtick key (~ / `, usually below Escape) to open/close. Escape also closes. Type a command and press Enter. Scroll/select/copy output; Up/Down recalls history. Available from title, gameplay or pause; player commands require an active game. Opening pauses simulation and exposes the mouse; closing restores prior pause/input ownership. F1 replaces the console with a report; F2â€“F4 replace it with inspectors.

Commands ignore case. Straight or curly double quotes can surround names/strings:

```
Set flag "flag"
Set flag "flag" false
Set BB "key" "value"
Set BB "number" 42
Set BB "enabled" true
Set BB "inventory" [1, 2, {"name": "fan"}]
TP 10 2 -5
Noclip
Noclip off
Fly
Fly off
Set score 1000
record start
record stop
record status
record folder
help
```

Set flag defaults true and calls Flags.set_flag so existing listeners fire. Set BB parses JSON for typed booleans/numbers/null/arrays/dictionaries; quoted values remain strings, unquoted non-JSON text remains text. Empty names/unmatched quotes are rejected. Set score requires a nonnegative integer; it sets score directly without queueing reward sounds/combo. Existing systems react on their usual updates. TP sets world-space position, clears velocity/wind and updates Blackboard transform/position immediately. It does not transition portal state automatically; use the portal normally for that.

Fly disables gravity but keeps collisions. Noclip also permits free flight and temporarily disables player collision layer/mask, excluding sensor interactions. WASD follows camera direction, Space rises, Ctrl descends, Shift uses sprint speed. Toggle with no argument, or use on/off (true/false/1/0). Disabling noclip restores the previous layer/mask; fly can remain enabled independently. Flight stops footsteps/sprint breathing and respects input locks. Modes are session-only controller fields and aren't saved; state/score/teleport changes are saved through the normal save system. Commands do not evaluate scripts or OS commands.

Implementation: Global/dev_console.gd is a compatibility wrapper, UID uid://byupb10nfv7le; DevConsole autoload, layer95, PROCESS_MODE_ALWAYS. Its core is addons/dev_toolkit/dev_console.gd, a CanvasLayer exporting tools_context, toggle_key and enabled. Runtime is_open, context, output, entry, history/history_index; DevToolsContext owns prior pause/mouse/input state. API open_console(), close_console(), execute(command)->String, tokenize(command)->Array[String], help_text()->String; _submit and _entry_input drive submission/history. Execution and formatting use context/adapter hooks; only Scripts/Debug/remnant_dev_adapter.gd connects Remnant state/player services. Scripts/Player/player_move_controller.gd supplies debug_fly/debug_noclip, saved masks, set_debug_noclip(enabled), _debug_move(delta). Pause/options/computer/dialogue inputs are guarded while the console is open. Tests/dev_console_test.tscn covers parsing, flags/typed Blackboard, score validation, teleport, noclip movement/mask restoration and pause ownership.

Recording commands call GameplayRecorder. record folder opens its output directory. The console can remain paused while recording; close it to resume play. See Data/RECORDING.md.

Commands are scripted DevConsoleCommand resources selected by Data/Debug/commands.tres. Built-in handlers moved into addons/dev_toolkit/commands; the Remnant adapter contains player/state integration. See Data/Debug/README.md for custom execute handlers, aliases and editable settings.

The console exports `maximum_history=100`, `maximum_output_characters=65536` and `maximum_command_characters=4096` to bound memory and entry length. `log [open|export|folder]` controls F5 diagnostics; command execution breadcrumbs exclude raw argument values.
