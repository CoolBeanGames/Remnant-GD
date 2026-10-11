# Windows development builds

After meaningful coding prompts, make a Windows x86_64 release export and commit/push verified source changes. Information-only answers need no redundant build or empty commit. The reusable workflow is Skills/godot-project-workflow/SKILL.md; future projects use their own configuration/destinations.

## Build

Run Python with `Tools/build_windows.py --godot PATH_TO_GODOT`. The current engine is Godot 4.7.2. The helper reads its actual version, locates the corresponding official godotengine/godot-builds release, verifies the export archive against the published SHA-256 asset digest, and caches Windows templates inside the ignored .godot/build_profile. No global Godot installation/settings are changed. A cached template set is reused only if its recorded per-file hashes still match. Custom/development engines or releases without a digest need manually verified templates.

`export_presets.cfg` defines Windows Desktop, x86_64, separate PCK, unsigned release export. Tests, Skills, Tools, Reports and Markdown guides are excluded. Runtime resources/addons remain included. Designer changes to the preset remain authoritative; do not replace them during routine builds.

The helper imports the editor resources, exports, inspects exit status/logs for errors/warnings, and starts the exported game headless for 90 frames with isolated save data. It writes Builds/Windows_TIMESTAMP/Remnant.exe plus Remnant.pck, optional renderer DLLs, logs and build.json. Builds/latest.txt records the newest successful output. Manifest fields include engine/mode/preset/time, source commit and worktree changes, verified template provenance, output sizes/hashes and actual checks. If the source was uncommitted, the manifest explicitly records that state; it does not pretend the old HEAD alone identifies the build.

Large build/template files remain local and ignored by Git. Builds are development executables, not signed installers or automatically published GitHub releases. Headless smoke proves startup/resources/scripts, not rendered appearance or all gameplay combinations. Rendered checks are additional evidence when applicable.

## Documentation and delivery

Maintain README, offline wiki/sidebar/search and timestamped guide entries. Update Reports/development_summary.html and append verified tasks to the configured Notion Agent Workflow Log. Preserve private site access. Review intended source/assets/docs, commit meaningful work, push normally to the configured remote and verify its revision. Never force-push, commit credentials/local reports/saves/recordings, or claim a failed test/export/push succeeded.

Script: Tools/build_windows.py (Python standard library, standalone CLI; no Godot UID/autoload/signals). APIs main(), templates(), run(), download(), sha256(); inputs --godot, --project, --preset, --output. Outputs must be a new folder within project Builds/. Export and smoke subprocesses use local APPDATA overrides; the real player save is not touched. Template downloads use HTTPS official GitHub release assets. Cached archives remain available for verification/reuse.
