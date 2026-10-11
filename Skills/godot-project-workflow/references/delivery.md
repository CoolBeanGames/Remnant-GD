# Delivery workflow

Remnant has standing user authorization for normal GitHub pushes and Windows builds after each meaningful coding prompt (2026-10-11). Other projects use their own explicit preferences/destinations. Simple answers/no changes need no empty commit/build. External failure does not prevent independent work, but do not claim delivery succeeded.

## Documentation and summaries

Update README, relevant guides, offline wiki content/sidebar/search and timestamped maintenance log. Validate unique page IDs and all navigation/search targets. Remnant wiki lists Globals first, then Scripts subfolders. Document script path/class/inheritance, UID/autoload, signals, configuration/runtime state, API and dependencies.

Create/update self-contained responsive HTML in the reports folder. Match the game's restrained style, make it readable on a phone, explain changed behavior/controls, verification/build and limits. Preserve useful old sections/dated history and real commit links. Visually inspect layout and links. Local HTML remains useful if publication is unavailable.

For configured Notion summaries, use connected tools, fetch destination and read enhanced-Markdown spec first. Append dated project/objective/change/verification/build/commit/summary/status entry; preserve history and approval colours. Proposed tasks are not complete without evidence. If unavailable/unconfigured, keep a local Markdown summary and report the missing external step; do not invent a shared destination.

Phone publication follows existing destination/access. For Sites read its skill, prepare source/build archive, satisfy source commit/deploy requirements and verify deployed status. Owner-private stays owner-private; no new site or broader access without authorization. Private links require the same account.

## Windows build

Discover actual Godot version, Windows Desktop preset and matching templates. Reuse existing preset/helper without overwriting designer settings. Obtain official matching templates if necessary for the authorized export and verify checksums; avoid engine upgrades. Use an ignored timestamped build folder.

Godot --headless --path PROJECT --export-release PRESET OUTPUT.exe produces a release export; label debug exports accurately when diagnosing. Keep large PCK separate, include renderer runtime DLLs, exclude tests/reports/skills/local issues/saves/recordings/build output. Check logs and smoke the export with isolated data; merely finding a file is insufficient.

Remnant helper: Tools/build_windows.py --godot ENGINE. Read it before first use. It resolves verified official templates, exports, smokes and writes manifest/logs under Builds/. Manifest identifies source/worktree, engine, mode/time, output hashes and actual checks. Don't commit binaries/templates/credentials or publish GitHub releases without authorization.

## Git

After verification review intended diff/status/remote/branch, including authorized earlier uncommitted work from this task chain. Preserve unrelated changes. Stage intended sources/docs/assets and required UIDs; inspect for accidentally tracked local reports, saves, recordings, diagnostic ZIPs or builds. Commit a meaningful resulting-behavior message. No force-push or unrelated history rewrite.

Push to configured authorized GitHub branch and verify remote revision equals local commit. If remote changed, inspect/integrate without discarding work; pause only for consequential ambiguous conflicts. Do not invent a new remote or re-ask already granted normal-push authorization. Attach every created PR via app attach_artifact and use reviewer-focused description/tests if a PR is part of the request.

Final: behavior/controls, meaningful verification, executable, HTML/Notion links, confirmed commit and material blockers. Complete required work rather than offering to do it later.
