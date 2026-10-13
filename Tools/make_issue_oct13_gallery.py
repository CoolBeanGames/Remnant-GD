"""Embed reviewed October 13 renders in the established offline report style."""
from pathlib import Path
from make_trip_gallery import picture

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Reports/IssueOctober13'


def main():
    groups = [
        ('rooms', 'More room to move.', 'Three final Cycles views per revised room. Presentation lights are separate from engine assets.',
         [(f'{room}_blender_{view}', f'{room.title()} / Blender view {view}') for room in ['apartment', 'warehouse', 'hospital'] for view in range(1, 4)]),
        ('game', 'Through the player camera.', 'Actual Forward+ / D3D12 captures with the real player flashlight. The TEST TITLE/TEST AUTHOR sleeve is fixture data, not shipped story text.',
         [(name, caption) for name, caption in [
             ('apartment_routes', 'Living room / clear entrance and bedroom route'), ('bedroom_clearance', 'Bedroom / desk removed'),
             ('editable_book_sleeve', 'One independently authored spine'), ('warehouse_closed_shutter', 'Warehouse / closed shutter'),
             ('warehouse_office', 'Office / larger desk and transparent glass'), ('hospital_open_ward', 'Ward / open movable door'),
             ('hospital_staff_door', 'Staff entrance / real doorway and clearance'), ('hospital_locked_exit', 'Far EXIT / locked main door'),
             ('combo_text_contrast', 'Outlined text / pale background'), ('loading_screen', 'Loading / visible before initialization')]]),
        ('workshop', 'Fits, hinges and pivots.', 'Actual engine captures verify the continuous shaft, independent leaf and fitted CRT. Blender views retain supplied textures.',
         [(name, name.replace('_', ' ').title()) for name in ['door_closed', 'door_open', 'lever_idle', 'lever_pulled', 'terminal_idle', 'terminal_focused', 'mulcher_bin']]
         + [(f'lever_{view}', f'Lever / Blender view {view}') for view in range(1, 4)]),
    ]
    theme = (ROOT / 'Reports/report_theme.css').read_text(encoding='utf8')
    body = '<section class="hero"><div><p class="eyebrow">13 OCTOBER 2026 / 27 F1 REPORTS</p><h1>Room.<br>To move.</h1></div><p class="intro">Revised memories, working doors, editable books, clearer controls and bounded physical debris. Actual reviewed renders and game captures.</p></section>'
    count = 0
    for identifier, title, lead, entries in groups:
        body += f'<section id="{identifier}"><h2>{title}</h2><p>{lead}</p><div class="room-views">'
        for name, caption in entries:
            path = OUT / (name + '.png')
            if path.exists():
                body += picture(path, caption)
                count += 1
        body += '</div></section>'
    nav = '<nav><a data-local="../development_summary.html#issues-october-13" data-online="../index.html#issues-october-13" href="../development_summary.html#issues-october-13">SUMMARY</a><a data-local="../index.html" data-online="../Archive/index.html" href="../index.html">ARCHIVE</a><a data-local="../../.wiki/index.html#page-issues-october-13" data-online="../Wiki/index.html#page-issues-october-13" href="../../.wiki/index.html#page-issues-october-13">AUTHORING</a><a href="#game">GAME VIEWS</a></nav>'
    extra = '.room-views{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:20px}figure{margin:0 0 24px;min-width:0}img{width:100%;height:auto;display:block}figcaption{font:12px Consolas,monospace;margin-top:9px;color:var(--muted)}@media(max-width:650px){.room-views{grid-template-columns:1fr}}'
    document = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Remnant / October 13 issue views</title><style>' + theme + extra + '</style></head><body><header><div class="wrap"><a class="brand" href="#">REMNANT / FIELD NOTES</a><span class="stamp">MEMORIES / CONTROLS / DIAGNOSTICS</span></div></header><main class="wrap">' + nav + body + '<footer>Selected automated checks supplement these reviewed views. A complete manual playthrough remains user testing. Local F1 screenshots are not published.</footer></main><script>document.querySelectorAll("[data-local]").forEach(a=>a.href=location.protocol==="file:"?a.dataset.local:a.dataset.online);</script></body></html>'
    (OUT / 'index.html').write_text(document, encoding='utf8')
    print('October 13 gallery:', count, 'embedded final views')


if __name__ == '__main__':
    main()
