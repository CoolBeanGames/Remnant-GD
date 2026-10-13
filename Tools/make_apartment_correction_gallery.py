"""Publish the reviewed floor/TV correction in Remnant's existing report style."""
from pathlib import Path
import sys

from make_trip_gallery import picture

ROOT = Path(__file__).resolve().parents[1]


def main():
    fridge_review = '--fridge' in sys.argv
    output = ROOT / ('Reports/FridgeCorrection' if fridge_review else 'Reports/ApartmentCorrection')
    theme = (ROOT / 'Reports/report_theme.css').read_text(encoding='utf8')
    body = '<section class="hero"><div><p class="eyebrow">13 OCTOBER 2026 / APARTMENT CORRECTION</p><h1>A better<br>place.</h1></div><p class="intro">The wide floor strip is closed. The television and its stand sit beside the coffee table, with the phone and VCR moving together. Actual reviewed renders show the result.</p></section>'
    views = [('living', 'Living room / repaired floor and moved TV'), ('television', 'TV, stand, phone and VCR / beside the coffee table'), ('floor', 'Floor / ordinary board seam replaces the exposed strip'), ('doorway', 'Bedroom doorway / clear circulation into the living room')]
    if fridge_review:
        body = '<section class="hero"><div><p class="eyebrow">13 OCTOBER 2026 / FRIDGE ORIENTATION</p><h1>Facing<br>the room.</h1></div><p class="intro">The fridge doors face into the kitchen. Corrected rotation conversion keeps the linked Blender assembly consistent with the game scene. Actual reviewed renders show the result.</p></section>'
        views = [('front', 'Fridge / doors and handles face the kitchen'), ('kitchen', 'Kitchen / appliance fronts face into the room'), ('living', 'Living room / corrected fridge in context')]
    for identity, heading, description, prefix in [
        ('blender', 'The marked changes.', 'Four final Cycles views. The architecture and furniture remain independent linked assets; inspection lighting belongs only to the separate presentation native.', 'blender_'),
        ('game', 'Inside the game.', 'Four actual Forward+ / D3D12 captures against the Windows release PCK using the matching Godot editor renderer. Authored game lighting is retained. Floor probes, player capsule routes and story bindings also pass.', 'engine_'),
    ]:
        if fridge_review:
            heading = 'A clear front.' if identity == 'blender' else heading
            description = description.replace('Four', 'Three')
        body += '<section id="' + identity + '"><h2>' + heading + '</h2><p>' + description + '</p><div class="views">'
        for name, caption in views:
            body += picture(output / (prefix + name + '.png'), caption)
        body += '</div></section>'
    nav = '<nav><a data-local="../development_summary.html#apartment-floor-tv" data-online="../index.html#apartment-floor-tv" href="../development_summary.html#apartment-floor-tv">SUMMARY</a><a data-local="../index.html" data-online="../Archive/index.html" href="../index.html">ARCHIVE</a><a data-local="../../.wiki/index.html#page-trip-models" data-online="../Wiki/index.html#page-trip-models" href="../../.wiki/index.html#page-trip-models">AUTHORING GUIDE</a><a href="#game">GAME VIEWS</a></nav>'
    extra = '.views{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px;align-items:start}figure{margin:0 0 24px;min-width:0}.views img{width:100%;height:auto;display:block}figcaption{font:12px Consolas,monospace;margin-top:10px;color:var(--muted)}@media(max-width:650px){.views{grid-template-columns:1fr}}'
    doc = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Remnant / Apartment floor and TV</title><style>' + theme + extra + '</style></head><body><header><div class="wrap"><a class="brand" href="#">REMNANT / FIELD NOTES</a><span class="stamp">FLOOR / TV / PLAYER ROUTES</span></div></header><main class="wrap">' + nav + body + '<footer>Eight reviewed final views. Targeted geometry, interaction and movement checks supplement the pictures; a complete manual playthrough remains user testing. The supplied marked photo stays local.</footer></main><script>document.querySelectorAll("[data-local]").forEach(a=>a.href=location.protocol==="file:"?a.dataset.local:a.dataset.online);</script></body></html>'
    if fridge_review:
        doc = doc.replace('apartment-floor-tv', 'apartment-fridge').replace('Apartment floor and TV', 'Fridge orientation').replace('FLOOR / TV / PLAYER ROUTES', 'FRIDGE / KITCHEN / ORIENTATION').replace('Eight reviewed final views.', 'Six reviewed final views.').replace(' The supplied marked photo stays local.', '')
    (output / 'index.html').write_text(doc, encoding='utf8')
    print('Apartment correction gallery / %d reviewed final views' % (len(views) * 2))


if __name__ == '__main__':
    main()
