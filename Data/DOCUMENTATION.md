# Development archive and system wiki

The development summaries, archive index, current system wiki and new world-interface gallery share the paper/ink/rust design in Reports/report_theme.css. Each final HTML file embeds the CSS and required search data, so opening it locally needs no server, CDN or network. Historical chapters and all existing wiki page IDs remain available.

## Read or find earlier work

Open Reports/index.html for the searchable index of dated summaries and render galleries. Open Reports/development_summary.html for the complete development history. Open .wiki/index.html for current authoring guides, script APIs and scene relationships. INDEX / SUMMARY / SYSTEM WIKI links connect the three views in both local files and the existing phone site. Current guides take precedence over retired designs in dated chapters.

The wiki keeps Overview followed by Globals and Scripts categories. Search includes title, category, keywords, summary and full stored reference text. Press / to focus search. Query characters are literal text, not regular expressions or HTML. Search results, sidebar links, hash URLs and browser back/forward select the same page. On phones SYSTEMS / SEARCH opens the category list. Code-copy buttons select text if clipboard permission is unavailable.

## Maintain the archive

Append new dated chapters to Reports/development_summary.html while preserving useful history and real verification. Run Tools/rebuild_report_index.py to regenerate Reports/index.html and index.json from section headings and the known gallery folders. Add new gallery folders to the generator rather than deleting older entries. Include meaningful controls, actual test/build results, reviewed images and verified source commit links.

Update the wiki's page content, sidebar target and embedded searchIndex together. Tools/rebuild_wiki.py preserves these three collections, validates page/search IDs and reapplies the common theme plus Tools/wiki_theme.css and Tools/wiki_behavior.js. It refreshes the physical-interface and documentation guide pages from their Markdown sources. The output is self-contained; the tool files are authoring sources, not web dependencies. Rebuilding twice must leave the same file contents.

## Local and phone paths

The established private phone site keeps the summary at /index.html, the archive at /Archive/index.html, the wiki at /Wiki/index.html and galleries at their named folders. data-local/data-online navigation picks file paths when opened locally and deployed paths on the website. Preserve the site's existing account access; do not broaden it for publication.

Game sources are built and committed before wiki restyling, as requested for this change. The world-interface release is Windows_2026-10-12_00-52-16. Eleven selected suites, isolated release startup and the rendered packaged-PCK interface probe passed. The following documentation changes do not alter runtime exports.
