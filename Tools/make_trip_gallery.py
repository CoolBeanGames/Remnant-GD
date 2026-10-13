"""Package the reviewed Trip renders into the existing offline report style."""
import base64
import html
import json
from io import BytesIO
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Reports/TripModels'


def picture(path, caption):
    # Keep original PNG evidence; compress only the self-contained phone gallery.
    with Image.open(path) as source:
        width, height = source.size
        image = source.convert('RGB')
        packed = BytesIO()
        image.save(packed, format='JPEG', quality=90, optimize=True, subsampling=0)
    data = base64.b64encode(packed.getvalue()).decode('ascii')
    return '<figure><img loading="lazy" width="' + str(width) + '" height="' + str(height) + '" src="data:image/jpeg;base64,' + data + '" alt="' + html.escape(caption, quote=True) + '"><figcaption>' + html.escape(caption) + '</figcaption></figure>'


def main():
    theme = (ROOT / 'Reports/report_theme.css').read_text()
    extra = '.views{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.views img{width:100%;height:auto;display:block}figure{margin:0 0 24px}figcaption{font:12px Consolas,monospace;margin-top:9px;color:var(--muted)}details{padding:22px 0;border-top:1px solid var(--line)}details>summary{font-size:22px}details p{margin:15px 0}img{max-width:100%;height:auto}.room-views{display:grid;grid-template-columns:1fr 1fr;gap:18px}@media(max-width:650px){.views,.room-views{grid-template-columns:1fr}}'
    body = '<section class="hero"><div><p class="eyebrow">13 OCTOBER 2026 / ART INTEGRATION</p><h1>Real<br>objects.</h1></div><p class="intro">Thirty-two supplied models, an expanded one-bedroom apartment, repaired door UVs and verified gameplay. Actual Blender renders and Godot captures.</p></section>'
    body += '<section id="apartment"><h2>A room to remember.</h2><p>12.2 × 6.2 metres, with a 4.25 × 6.2 metre bedroom. Architecture and props remain independent editable assets. These four Cycles views use presentation lighting; the game views below show the authored darker atmosphere.</p><div class="room-views">'
    for name, caption in [('cutaway', 'Temporary cutaway / full apartment'), ('living', 'Living room / supplied couch, chair and TV'), ('bedroom', 'Bedroom / independent domestic bed'), ('doorway', 'Bedroom opening / view toward living room')]:
        body += picture(OUT / ('apartment_' + name + '.png'), caption)
    body += '</div></section><section id="engine"><h2>Inside the engine.</h2><p>Forward+ / D3D12. The door keeps its supplied panel UVs; its fixed frame and moving leaf have separate geometry. The computer sits on the cart with the existing interactive screen.</p><div class="room-views">'
    for name, caption in [('door_closed', 'Closed door / preserved wood panel UVs'), ('door_open', 'Open door / stationary frame'), ('terminal', 'Terminal / cart support and aligned in-world screen'), ('bedroom', 'Bedroom / actual game lighting'), ('apartment', 'Living room / actual game lighting')]:
        body += picture(OUT / 'game' / ('engine_' + name + '.png'), caption)
    body += '</div></section><section id="assets"><h2>Each asset, three ways.</h2><p>Expand an item to inspect front, reverse and upper angles. Supplied maps are embedded in the portable GLBs and packed into the native sources. Gameplay colliders and pickup targets are independent from the visual meshes.</p>'
    entries = json.loads((ROOT / 'Models/Imported/Trip/catalog.json').read_text())
    for entry in entries:
        title = entry['id'].replace('_', ' ').title()
        manifest = json.loads((ROOT / 'Models/Imported/Trip' / entry['id'] / 'asset_manifest.json').read_text())
        size = ' × '.join(f'{d:.3f}' for d in manifest['dimensions_m'])
        body += '<details id="asset-' + entry['id'] + '"><summary>' + html.escape(title) + '</summary><p>' + html.escape(entry['usage']) + ' · ' + size + ' m (Blender XYZ) · ' + str(manifest['triangles']) + ' triangles</p><div class="views">'
        for view in range(1, 4):
            body += picture(OUT / (entry['id'] + '_' + str(view) + '.png'), title + ' / view ' + str(view))
        body += '</div></details>'
    body += '<details id="asset-bedroom-bed"><summary>Bedroom bed / separate new asset</summary><p>1.66 × 2.18 × 1.23 m. Packed worn fabric and oak maps; separate native and export.</p><div class="views">'
    for view in range(1, 4):
        body += picture(OUT / ('bedroom_bed_' + str(view) + '.png'), 'Bedroom bed / view ' + str(view))
    body += '</div></details></section><footer>103 Blender views and five actual game captures reviewed. Selected physics, interactions, memory travel and persistence tests supplement these images; a complete manual playthrough remains user testing.</footer>'
    nav = '<nav><a data-local="../development_summary.html#trip-models-apartment" data-online="../index.html#trip-models-apartment" href="../development_summary.html#trip-models-apartment">SUMMARY</a><a data-local="../index.html" data-online="../Archive/index.html" href="../index.html">ARCHIVE</a><a data-local="../../.wiki/index.html#page-trip-models" data-online="../Wiki/index.html#page-trip-models" href="../../.wiki/index.html#page-trip-models">AUTHORING</a><a href="#assets">ASSETS</a></nav>'
    doc = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Remnant / Trip models and apartment</title><style>' + theme + extra + '</style></head><body><header><div class="wrap"><a class="brand" href="#">REMNANT / FIELD NOTES</a><span class="stamp">MODELS / SCALE / MATERIALS</span></div></header><main class="wrap">' + nav + body + '</main><script>document.querySelectorAll("[data-local]").forEach(a=>a.href=location.protocol==="file:"?a.dataset.local:a.dataset.online);</script></body></html>'
    (OUT / 'index.html').write_text(doc, encoding='utf8')
    print('Trip gallery: 103 native renders + five engine captures embedded')


if __name__ == '__main__':
    main()
