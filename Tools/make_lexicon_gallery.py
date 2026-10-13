"""Embed the reviewed Lexicon editor and standalone Godot test captures."""
from pathlib import Path
from make_trip_gallery import picture

ROOT = Path(__file__).resolve().parents[1]


def main():
    output = ROOT / 'Reports/Lexicon'
    theme = (ROOT / 'Reports/report_theme.css').read_text(encoding='utf8')
    body = '<section class="hero"><div><p class="eyebrow">13 OCTOBER 2026 / STORY AUTHORING</p><h1>Words.<br>Pictures.<br>Voices.</h1></div><p class="intro">Lexicon is a separate reusable editor with a portable Godot SDK. These are actual editor screenshots and engine views from an isolated test project. The sample words and images are test fixtures.</p></section>'
    for identity, heading, description, views in [
        ('notes', 'A note, kept together.', 'Name, image and typed transcript. Copied media and stable IDs survive reopening and export to another game.', [('notes_editor', 'Notes / desktop editor'), ('notes_phone', 'Notes / narrow layout')]),
        ('dialog', 'A conversation can branch.', 'Edit individual lines, optional voice, starting line, next line and labelled choices. Preview follows the same targets. End closes the conversation.', [('dialog_editor', 'Dialog / lines, voice and branch choices'), ('branch_preview', 'Preview / chosen branch')]),
        ('flavor', 'Flavor stays linear.', 'Ordered text and optional voice without branch controls. Reuse the host’s look or interaction system to trigger it.', [('flavor_editor', 'Flavor / linear line editor')]),
        ('sdk', 'Use it in another game.', 'The SDK loads real exported images, audio and resources in Godot without Remnant autoloads. This is the optional draft presenter; hosts can use physical notes and in-world interfaces.', [('runtime_choices', 'Godot / playable branch choices'), ('runtime_note', 'Godot / optional draft image and transcript view')]),
    ]:
        body += '<section id="' + identity + '"><h2>' + heading + '</h2><p>' + description + '</p><div class="views">'
        for name, caption in views:
            body += picture(output / (name + '.png'), caption)
        body += '</div></section>'
    nav = '<nav><a data-local="../development_summary.html#lexicon" data-online="../index.html#lexicon" href="../development_summary.html#lexicon">SUMMARY</a><a data-local="../index.html" data-online="../Archive/index.html" href="../index.html">ARCHIVE</a><a data-local="../../.wiki/index.html#page-lexicon" data-online="../Wiki/index.html#page-lexicon" href="../../.wiki/index.html#page-lexicon">GUIDE</a><a href="#sdk">GODOT SDK</a></nav>'
    extra = '.views{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px;align-items:start}figure{margin:0 0 24px;min-width:0}.views img{width:100%;height:auto;display:block}figcaption{font:12px Consolas,monospace;margin-top:10px;color:var(--muted)}@media(max-width:650px){.views{grid-template-columns:1fr}}'
    doc = '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Remnant / Lexicon authoring</title><style>' + theme + extra + '</style></head><body><header><div class="wrap"><a class="brand" href="#">REMNANT / FIELD NOTES</a><span class="stamp">LEXICON / NOTES / DIALOG / FLAVOR</span></div></header><main class="wrap">' + nav + body + '<footer>Seven reviewed captures. Export, browser, local server and independent Godot runtime checks supplement the views. Existing story scenes remain separate until new content is explicitly connected.</footer></main><script>document.querySelectorAll("[data-local]").forEach(a=>a.href=location.protocol==="file:"?a.dataset.local:a.dataset.online);</script></body></html>'
    (output / 'index.html').write_text(doc, encoding='utf8')
    print('Lexicon gallery / seven reviewed editor and engine captures')


if __name__ == '__main__':
    main()
