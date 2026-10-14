"""Self-contained reviewed controls/performance gallery in the established theme."""
from pathlib import Path
from make_trip_gallery import picture

ROOT = Path(__file__).resolve().parents[1]


def main():
    out = ROOT / 'Reports/ItemPileFollowup'
    theme = (ROOT / 'Reports/report_theme.css').read_text(encoding='utf8')
    body = '<section class="hero"><div><p class="eyebrow">14 OCTOBER 2026 / ITEM PILES + TOOL CONTROLS</p><h1>More items.<br>Fewer stalls.</h1></div><p class="intro">Bounded world updates, usable fan prompts, individual light cones, automatic Mulcher repairs and a flashlight you can find. These are actual reviewed Godot captures.</p></section>'
    groups = [
        ('controls', 'The controls stay clear.', 'Release-PCK control checks use the real prop, prompt and repair scripts. The plain inspection floor isolates their state; it is not a replacement level.', [('fan_controls', 'Fan / one Sweep prompt after repeated refreshes'), ('light_cone', 'Light / K chooses omni illumination'), ('light_omni', 'Light / K restores the cone'), ('flashlight_off', 'Flashlight / T recovery hint'), ('automatic_repair', 'Mulcher / paid automatic repair in progress')]),
        ('workshop', 'The real workshop.', 'The same 400-item workload before and after the world-update change, using authored stage lighting at 1280×720. The intake is disabled to keep exactly 400 items; lighting and animation remain. These views accompany measured frame times, rather than proving every possible contraption.', [('workshop_before', 'Previous release PCK / 400 sleeping items'), ('workshop_after', 'Updated source / same controlled 400-item workshop')]),
    ]
    for identity, heading, description, views in groups:
        body += '<section id="' + identity + '"><h2>' + heading + '</h2><p>' + description + '</p><div class="views">'
        for name, caption in views:
            body += picture(out / (name + '.png'), caption)
        body += '</div></section>'
    nav = '<nav><a data-local="../development_summary.html#item-pile-followup" data-online="../index.html#item-pile-followup" href="../development_summary.html#item-pile-followup">SUMMARY</a><a data-local="../index.html" data-online="../Archive/index.html" href="../index.html">ARCHIVE</a><a data-local="../../.wiki/index.html#page-physics-performance" data-online="../Wiki/index.html#page-physics-performance" href="../../.wiki/index.html#page-physics-performance">PERFORMANCE GUIDE</a></nav>'
    style = '.views{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px;align-items:start}figure{margin:0 0 24px;min-width:0}.views img{width:100%;height:auto;display:block}figcaption{font:12px Consolas,monospace;margin-top:10px;color:var(--muted)}@media(max-width:650px){.views{grid-template-columns:1fr}}'
    document = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Remnant / Item piles and tool controls</title><style>' + theme + style + '</style></head><body><header><div class="wrap"><a class="brand" href="#">REMNANT / FIELD NOTES</a><span class="stamp">PHYSICS / CONTROLS / REPAIRS</span></div></header><main class="wrap">' + nav + body + '<footer>Seven actual reviewed views. Private F1 images and saves stay local. The guide explains measured workloads, reproduction and limits.</footer></main><script>document.querySelectorAll("[data-local]").forEach(a=>a.href=location.protocol==="file:"?a.dataset.local:a.dataset.online);</script></body></html>'
    (out / 'index.html').write_text(document, encoding='utf8')
    print('Item-pile followup gallery / 7 reviewed views')


if __name__ == '__main__':
    main()
