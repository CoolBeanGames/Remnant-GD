#!/usr/bin/env python3
"""Package only the public HTML archive for GitHub Pages (standard library)."""
from __future__ import annotations

import argparse
import hashlib
import html
from html.parser import HTMLParser
import json
from pathlib import Path
import posixpath
import re
import subprocess
from urllib.parse import unquote, urlsplit, urlunsplit

ROOT = Path(__file__).resolve().parents[1]
PRIVATE_ORIGIN = 'https://remnant-development-summary.callmehaptic.chatgpt.site'
PAGES_URL = 'https://coolbeangames.github.io/Remnant-GD/'


class References(HTMLParser):
    def __init__(self, source: str):
        super().__init__()
        self.ids: list[str] = []
        self.links: list[str] = []
        self.assets: list[str] = []
        self.feed(source)

    def handle_starttag(self, tag: str, attrs):
        values = dict(attrs)
        if values.get('id'):
            self.ids.append(values['id'])
        if tag == 'a' and values.get('href'):
            # These pages select their online path at runtime on HTTPS.
            self.links.append(values.get('data-online', values['href']))
        if values.get('src'):
            self.assets.append(values['src'])


def portable_html(source: str, route: str) -> str:
    """Keep old private-site links within this copy, including project subpaths."""
    parent = posixpath.dirname(route) or '.'

    def replace(match):
        value = html.unescape(match[2])
        if not value.startswith(PRIVATE_ORIGIN + '/') and value != PRIVATE_ORIGIN:
            return match[0]
        url = urlsplit(value)
        path = url.path.lstrip('/') or 'index.html'
        relative = posixpath.relpath(path, parent)
        target = urlunsplit(('', '', relative, url.query, url.fragment))
        return match[1] + html.escape(target, quote=True) + match[3]

    return re.sub(r'((?:href|data-online)=")([^"]+)(")', replace, source)


def validate(output: Path) -> dict:
    pages = {p.resolve(): References(p.read_text(encoding='utf8'))
             for p in output.rglob('*.html')}
    checked = 0
    for page, refs in pages.items():
        if len(refs.ids) != len(set(refs.ids)):
            raise ValueError('Duplicate HTML ids: ' + str(page.relative_to(output)))
        for value in refs.links + refs.assets:
            url = urlsplit(value)
            if url.scheme or url.netloc:
                continue
            if url.path.startswith('/'):
                raise ValueError('Root-relative path would escape the project site: ' + value)
            target = (page.parent / unquote(url.path)).resolve() if url.path else page
            if not target.is_relative_to(output) or not target.is_file():
                raise ValueError('Missing/escaping reference from ' + str(page.relative_to(output)) + ': ' + value)
            if url.fragment and target in pages and unquote(url.fragment) not in pages[target].ids:
                raise ValueError('Missing fragment: ' + value)
            checked += 1
    wiki = pages[(output / 'Wiki/index.html').resolve()]
    wiki_text = (output / 'Wiki/index.html').read_text(encoding='utf8')
    marker = re.search(r'const searchIndex\s*=\s*', wiki_text)
    index, _ = json.JSONDecoder().raw_decode(wiki_text[marker.end():])
    page_ids = {value for value in wiki.ids if value.startswith('page-')}
    if {row['id'] for row in index} != page_ids or len(index) != len(page_ids):
        raise ValueError('Wiki/search targets differ')
    return {'html_pages': len(pages), 'wiki_pages': len(index),
            'archive_entries': len(json.loads((output / 'Archive/index.json').read_text(encoding='utf8'))),
            'local_references_checked': checked}


def build(output: Path) -> dict:
    output = output.resolve()
    if not output.is_relative_to(ROOT / '.godot'):
        raise ValueError('Generated output must stay inside the ignored project .godot directory')
    routes = {'index.html': ROOT / 'Reports/development_summary.html',
              'Archive/index.html': ROOT / 'Reports/index.html',
              'Archive/index.json': ROOT / 'Reports/index.json',
              'Wiki/index.html': ROOT / '.wiki/index.html'}
    for gallery in sorted((ROOT / 'Reports').glob('*/index.html')):
        routes[gallery.parent.name + '/index.html'] = gallery
    expected = set(routes) | {'.nojekyll', 'build-info.json'}
    if output.exists():
        unknown = {p.relative_to(output).as_posix() for p in output.rglob('*') if p.is_file()} - expected
        if unknown:
            raise ValueError('Output contains unrelated files: ' + ', '.join(sorted(unknown)))
    for route, source in routes.items():
        target = output / route
        target.parent.mkdir(parents=True, exist_ok=True)
        text = source.read_text(encoding='utf8')
        target.write_text(portable_html(text, route) if source.suffix == '.html' else text, encoding='utf8')
    (output / '.nojekyll').write_text('', encoding='utf8')
    checks = validate(output)
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    metadata = {'source_commit': commit, 'site_url': PAGES_URL, 'checks': checks,
                'sha256': {name: hashlib.sha256((output / name).read_bytes()).hexdigest()
                           for name in sorted(routes)}}
    (output / 'build-info.json').write_text(json.dumps(metadata, indent=2) + '\n', encoding='utf8')
    print(json.dumps({'output': str(output), **checks}))
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / '.godot/documentation_site')
    args = parser.parse_args()
    build(args.output)


if __name__ == '__main__':
    main()
