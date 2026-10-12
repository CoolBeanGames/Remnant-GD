# Remnant reporting configuration

Read AGENTS.md, guide.txt, README.md and Skills/godot-project-workflow/SKILL.md. Meaningful coding prompts require tests, a Windows build, documentation, HTML/Notion summaries and a normal GitHub push. Data/WINDOWS_BUILDS.md and Tools/build_windows.py define export and isolated startup verification. Binaries stay in ignored Builds/.

## Source and style

Reports/development_summary.html contains append-only dated development chapters. Reports/report_theme.css is the shared source theme; final HTML embeds it. Reports/index.html and index.json are searchable history. .wiki/index.html embeds all reference content, searchIndex and scripts. Tools/wiki_theme.css and wiki_behavior.js add the reference layout/behavior while keeping the same visual language.

Use feature/article, chapter-head/number/h2/lead, callout, details and commit styles from the existing summary. Reuse report_theme rather than inventing a new design. New galleries belong in Reports/Topic/index.html, self-contained with embedded reviewed images. Keep source screenshots there and add a .gdignore to exclude authoring output from Godot. Existing galleries/history stay intact.

Tools/rebuild_report_index.py preserves chapter IDs and a known gallery list; add a new gallery to that list. Tools/rebuild_wiki.py preserves pages/sidebar/search and refreshes configured Markdown authoring guides; register any new maintained guide instead of silently leaving a stale wiki page. Validate repeated rebuilds leave identical contents. Current guide changes must update page text, sidebar and search together; keep Globals first followed by Scripts categories.

## Hosting

Configured remote: https://github.com/CoolBeanGames/Remnant-GD (main; inspect actual git state first).
Primary phone archive: https://coolbeangames.github.io/Remnant-GD/
Routes: /index.html#chapter-id, /Archive/index.html, /Wiki/index.html#page-id and /Topic/index.html. Hosted paths include /Remnant-GD/. Historical owner-private site remains unchanged; do not replace or broaden its access.

.github/workflows/documentation-pages.yml automatically packages/deploys doc changes on main. Pages is already enabled with Actions; do not enable it again. Tools/build_documentation_site.py packages the self-contained HTML/JSON into ignored .godot/documentation_site, validates internal links/fragments/assets/IDs/search and creates build-info.json with source_commit/checks/sha256. Its GitHub sparse checkout includes wiki/reports/tools, so do not add an undeclared build-time dependency on game assets or Skills.

Use local HTTP and a real browser to inspect packaged pages at 390px and a desktop width, then check successful Publish documentation run for the pushed revision. Fetch live build-info.json and each file hashed there, consume responses and confirm matching SHA-256. Linux checkout can normalize text newlines, so live hashes are verified against its own manifest. Use bounded checks/backoff; report an unavailable service rather than inventing deployment success. Never log credentials.

## Notion and completion records

Append to the existing Agent Workflow Log, page ID 3f606a7c5a6481cc83eac72f35a7c8c4, https://app.notion.com/p/3f606a7c5a6481cc83eac72f35a7c8c4 . Fetch first and use connector enhanced Markdown. User authorization for this project log persists; Item Ideas is a different approval page. Read back the appended heading and delivery references.

A source commit cannot embed its own final hash. Record a verified implementation/build commit in the chapter; a later small delivery-record commit may add final push/live outcomes. Verify remote HEAD and the latest published source after the last commit. Never claim that an earlier build manifest identifies later code changes: record its worktree state honestly. Documentation-only follow-up needs no redundant game export.
