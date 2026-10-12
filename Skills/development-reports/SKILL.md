---
name: development-reports
description: Create and maintain development reports after meaningful project changes, using the established paper-and-ink HTML style, searchable history and wiki, verified delivery records, Notion summaries and GitHub Pages hosting. Use for project delivery reports, not unrelated websites or marketing pages.
---

# Development reports

Report the completed behavior and its evidence in the same restrained format as Remnant's archive. Maintain reports after each meaningful development prompt when this is the project's standing preference. Questions and no-change work need no empty chapter, build or commit.

## Sources and format

Read the current project instructions and existing summary/theme/index/wiki before writing. Current authoring guides describe the current design; dated reports preserve history. For Remnant, read [references/remnant.md](references/remnant.md) for exact destinations and maintained tools. Other projects use their own configuration and authorization.

Use the existing shared theme when present. [assets/report_theme.css](assets/report_theme.css) and [assets/report_template.html](assets/report_template.html) reproduce the preferred format for a new project: warm paper, dark ink, restrained rust/acid accents, large condensed-looking bold headings, monospaced dates/labels, thin rules and square feature rows. Keep the result useful on a phone; no dashboard decoration, rounded card theme, CDN, external font or invented screenshots.

Each dated chapter has a permanent unique section ID, numbered or dated eyebrow, concrete h2, concise lead and parallel feature rows. Explain resulting behavior, controls and editable choices before implementation details. Add evidence/limits in a callout or expandable details. Include actual test results, build path/version/mode, source commit link and publication outcome. Scale detail to the change. A pending build/push remains pending; replace its status after verification. Keep older chapters and IDs intact.

Images are actual reviewed game screenshots/renders. Embed PNG/JPEG data URLs in the final gallery so it works offline; keep source images when the project wants editable history. Link the gallery into summary and archive. Never publish local F1 screenshots, save dumps, logs or recordings merely because they were available during debugging.

## Archive, wiki and Notion

Update current README/authoring guides and timestamped guide log. Maintain wiki content, sidebar and embedded search together, preserving incoming IDs and literal-safe search. Summary, searchable archive and system wiki share typography/navigation and link to one another. File links and hosted project-prefix links must both work. Rebuild tools must retain history and be idempotent.

Append a dated entry to the configured Notion workflow log after fetching it and reading the connector's Markdown format. Include project/objective, behavior and controls, verification, actual Windows build, commit/source and hosted summary links, and any limitation. Preserve earlier entries and approvals; do not replace a whole page or write to an ideas/approval page instead of the delivery log.

## Verify and publish to GitHub

The user's preferred host for these reports is GitHub Pages alongside the source repository. Reuse its existing Pages Actions workflow and destination; preserve existing publication access. For another project, determine the configured remote/Pages prefix and obtain any missing external authorization before creating hosting or changing visibility. A report skill does not grant unrelated GitHub mutations or authorize a private repository's content to become public.

Package only intended documentation HTML/JSON/media. Validate all local navigation, fragments, unique IDs, sidebar/search correspondence and assets. Record exact source revision and generated-file hashes in build metadata. Run the existing package validator and inspect actual browser rendering at phone and desktop widths. Exercise archive filtering, wiki search, sidebar, back/forward, cleared search and new fragment links; inspect the resulting screenshots. A static parse does not prove usability.

Finish verified game changes/builds under the project's coding workflow, then commit/push the intended reports/docs normally. Do not force-push, add binaries or include private local inputs. Wait for the Pages deployment for that source commit and fetch the live metadata/pages. Compare published hashes against the live manifest, rather than assuming Windows and Linux source line endings match. Report hosting as complete only after live verification; keep offline deliverables and explain actual blockers if external delivery fails.

The final response stays short: resulting behavior, meaningful checks, executable/local report when applicable, phone-readable GitHub summary link and confirmed commit. Do not dump the entire report into chat.
