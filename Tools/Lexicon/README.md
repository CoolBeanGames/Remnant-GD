# Lexicon

External authoring for notes, branching conversations and linear flavor text. The standalone Windows executable includes Python, the editor and the portable Godot plugin. It opens a local browser window; it needs no account or internet connection. **Exit Tool** closes its local process. Closing only the browser tab leaves the tool running.

## Author content

Open `Lexicon.exe` from the latest `Builds/Lexicon_*` folder. Select the folder containing `project.godot` with Browse, then Open. The same executable works with other games. From source, run `python Tools/Lexicon/lexicon.py` (Python 3.10+, standard library; tkinter supports Browse).

Notes: select or create an entry, set its Name, typed transcript and optional PNG/JPEG/WebP image. Dialog: create a conversation, add/reorder/remove lines, set the starting line, speaker/text and optional WAV/OGG/MP3 voice per line. Set Next Line for a linear transition, or add labelled choices with target lines. End terminates the conversation. Flavor: edit ordered lines and optional voices, without branching. Preview plays the image/text/audio and lets you follow choices before export.

Save + Export, or Ctrl+S, updates all catalogs and the master list, copies media and installs `addons/lexicon`. Reopening a project reads its portable `lexicon/lexicon.source.json`. Keep Resource IDs and line IDs stable once a game refers to them. Names can change freely. Empty images and voices are supported. Referencing a removed line is blocked until corrected; removing a line in the editor clears its incoming references to End.

## Export ownership

The layout is `lexicon/lexicon_db.tres`, `notes/note_db.tres` and individual notes, `dialog/conversation_db.tres` and conversations, and `flavor/flavor_db.tres` and flavor entries. Note images live in `notes/images`; voices live in the corresponding `dialog/vocals` or `flavor/vocals`. All paths below the first component are under `lexicon/`. Filenames use stable IDs, so the first new entries are `note_1.tres`, `conversation_1.tres`, and `flavor_1.tres`.

Copied media uses content hashes. Shared assets remain until the last reference is removed. Unused owned resources/media are pruned during a successful save; original uploaded files are untouched. `.lexicon-manifest.json` records ownership and hashes. Unmanaged files and externally modified obsolete exports are protected. Replacement failures restore the previous files and manifest, including removed import descriptors. Unchanged files are left alone to avoid needless Godot imports. Individual media files are limited to 100 MB, with a 512 MB library budget. Keep ordinary project backups; an interrupted machine/disk failure is outside a process-level rollback guarantee.

## Godot integration

See `addons/lexicon/README.md`. Enable Lexicon in Project Settings > Plugins to get the catalog dock. Instance `addons/lexicon/player.tscn`, assign `lexicon/lexicon_db.tres`, and call `play("dialog", "conversation_1")`, `play("flavor", "flavor_1")`, or `play("notes", "note_1")`. Optional draft presentation types text, plays voice, accepts E to skip, waits for voice before advancing and offers choice buttons. Hosts can replace presentation/audio and connect their own interaction, prompts, flags and persistence. Resources contain content; they do not automatically decide game progression.

Remnant's optional `Scripts/Dialogue/lexicon_remnant_bridge.gd` routes voice through pooled Vocals and notes through the existing physical note/journal system. The portable addon has no Remnant dependency. Existing authored Remnant story content is not overwritten by installing Lexicon.

## Authoring by agents

Read the repository instructions and this guide before changing content. Open the selected project's `lexicon/lexicon.source.json`, preserve IDs and unrelated entries, and edit version 1 JSON. Note fields are `id/title/text/image`. Conversation fields are `id/title/start_line/lines`; each line has `id/speaker/text/audio/next/choices`, with choices containing `label/target`. Flavor uses `id/title/lines` with no nonempty `next` or `choices`. Media references may be copied project-relative paths or absolute source paths; successful export rewrites them to portable copied paths.

Use `python Tools/Lexicon/lexicon.py --project PROJECT_FOLDER --library JSON_FILE --export-only` to regenerate and validate resources and the master lists. The packaged executable accepts the same arguments. Never edit `.lexicon-manifest.json`, hand-prune shared assets, or publish local test libraries. Inspect generated resources in an isolated Godot project, then connect content through the host's existing systems. Use game-specific save/flag logic for when it is played.

## Verify and build

Run `python Tools/Lexicon/test_export.py` and `python Tools/Lexicon/test_server.py`. The standalone Godot test in `test_runtime.gd` expects an exported fixture with `note_1`, a two-line `conversation_1` (Remember -> line_2; Leave -> End), and `flavor_1`; it exercises actual resources, choices, voice and presentation. It runs in a separate project without game services. Browser tests exercise uploads, previews, save/reopen and invalid-target recovery; visually inspect both desktop and narrow layouts.

For Windows packaging, create an isolated Python environment, install `PyInstaller==6.22.3` there and run `Tools/build_lexicon.py` with that interpreter. The helper produces a fresh ignored `Builds/Lexicon_TIMESTAMP/Lexicon.exe`, log and provenance manifest. Launch the executable, exercise its local server/save/export, import the result in Godot and retain those results before treating a package as verified. Binaries, local libraries, recordings, reports and build environments stay out of Git.
