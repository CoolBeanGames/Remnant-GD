"""Lexicon's portable authoring model and owned-file Godot export transaction."""
from __future__ import annotations
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile

KINDS = ('notes', 'dialog', 'flavor')
CATALOGS = {'notes': 'note_db', 'dialog': 'conversation_db', 'flavor': 'flavor_db'}
SCRIPTS = {'notes': 'note', 'dialog': 'conversation', 'flavor': 'flavor'}
IDENTIFIER = re.compile(r'^[a-zA-Z][a-zA-Z0-9_-]{0,63}$')
IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.webp'}
AUDIO_EXTENSIONS = {'.wav', '.ogg', '.mp3'}


def empty_database():
    return {'version': 1, **{kind: [] for kind in KINDS}}


def validate(database):
    if not isinstance(database, dict) or database.get('version') != 1:
        raise ValueError('Unsupported Lexicon library version.')
    for kind in KINDS:
        entries = database.get(kind)
        if not isinstance(entries, list) or len(entries) > 5000:
            raise ValueError('Invalid ' + kind + ' list.')
        ids = set()
        for entry in entries:
            if not isinstance(entry, dict):
                raise ValueError(kind + ': invalid entry.')
            entry_id = entry.get('id', '')
            if not isinstance(entry_id, str) or not IDENTIFIER.fullmatch(entry_id) or entry_id.casefold() in ids:
                raise ValueError(f'{kind}: IDs must be unique letters/numbers/underscores, starting with a letter (64 maximum).')
            ids.add(entry_id.casefold())
            if entry_id.casefold() == CATALOGS[kind]:
                raise ValueError(entry_id + ': this ID is reserved for the catalog.')
            if not isinstance(entry.get('title'), str) or not entry['title'].strip():
                raise ValueError(entry_id + ': enter a name.')
            if kind == 'notes':
                if not isinstance(entry.get('text', ''), str):
                    raise ValueError(entry_id + ': invalid note text.')
                if not isinstance(entry.get('image', ''), str):
                    raise ValueError(entry_id + ': invalid image path.')
                continue
            lines = entry.get('lines', [])
            if not isinstance(lines, list) or len(lines) > 5000:
                raise ValueError(entry_id + ': invalid lines.')
            line_ids = set()
            for line in lines:
                if not isinstance(line, dict):
                    raise ValueError(entry_id + ': invalid line.')
                line_id = line.get('id', '')
                if not isinstance(line_id, str) or not IDENTIFIER.fullmatch(line_id) or line_id.casefold() in line_ids:
                    raise ValueError(entry_id + ': line IDs must be unique valid identifiers.')
                line_ids.add(line_id.casefold())
                for field in ('speaker', 'text', 'next', 'audio'):
                    if not isinstance(line.get(field, ''), str):
                        raise ValueError(entry_id + ': invalid line ' + field)
                choices = line.get('choices', [])
                if not isinstance(choices, list) or len(choices) > 100 or any(not isinstance(choice, dict) for choice in choices):
                    raise ValueError(entry_id + ': invalid choices (100 maximum).')
            actual_ids = {line['id'] for line in lines}
            if kind == 'dialog':
                if not isinstance(entry.get('start_line', ''), str) or entry.get('start_line', '') not in actual_ids | {''} or (lines and not entry.get('start_line')):
                    raise ValueError(entry_id + ': select a valid starting line.')
                for line in lines:
                    if line.get('next', '') not in actual_ids | {''}:
                        raise ValueError(f'{entry_id}/{line["id"]}: next line no longer exists.')
                    for choice in line.get('choices', []):
                        if not isinstance(choice.get('label'), str) or not choice['label'].strip() or not isinstance(choice.get('target', ''), str) or choice.get('target', '') not in actual_ids | {''}:
                            raise ValueError(f'{entry_id}/{line["id"]}: each choice needs a label and valid target (or End).')
            elif any(line.get('choices') or line.get('next') for line in lines):
                raise ValueError(entry_id + ': flavor lines cannot branch.')
    return database


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or '\\' in relative or relative.startswith('/'):
        raise ValueError('Invalid managed path.')
    target = (root / relative).resolve()
    if not target.is_relative_to(root.resolve()) or target == root.resolve():
        raise ValueError('Path escapes the selected project.')
    return target


def atomic_write(path: Path, data: bytes):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


class ResourceText:
    def __init__(self, script):
        self.external = [('Script', 'res://addons/lexicon/' + script + '.gd')]
        self.fields = ['script = ExtResource("1")']

    def reference(self, kind, path):
        entry = (kind, path)
        if entry not in self.external:
            self.external.append(entry)
        return 'ExtResource("%d")' % (self.external.index(entry) + 1)

    def field(self, name, value):
        self.fields.append(name + ' = ' + value)

    def finish(self):
        text = '[gd_resource type="Resource" load_steps=%d format=3]\n\n' % (len(self.external) + 1)
        for index, (kind, path) in enumerate(self.external, 1):
            text += '[ext_resource type=%s path=%s id="%d"]\n' % (json.dumps(kind), json.dumps(path), index)
        return (text + '\n[resource]\n' + '\n'.join(self.fields) + '\n').encode('utf8')


def export(project: Path, database: dict, plugin: Path) -> dict:
    """Validate everything first; roll back replacement failures; prune owned files only."""
    project = project.resolve()
    validate(database)
    if not (project / 'project.godot').is_file():
        raise ValueError('Choose the folder containing your Godot project.godot.')
    content = copy.deepcopy(database)
    outputs = {}
    assets_used = set()

    def asset(reference, kind):
        if not reference:
            return None
        source = safe_path(project, reference) if not Path(reference).is_absolute() else Path(reference).resolve()
        allowed = IMAGE_EXTENSIONS if kind == 'notes' else AUDIO_EXTENSIONS
        if not source.is_file() or source.suffix.lower() not in allowed:
            raise ValueError('Missing or unsupported asset: ' + str(source))
        if source.stat().st_size > 100 * 1024 * 1024:
            raise ValueError('An asset exceeds 100 MB: ' + source.name)
        data = source.read_bytes()
        folder = 'images' if kind == 'notes' else 'vocals'
        relative = f'lexicon/{kind}/{folder}/{digest(data)}{source.suffix.lower()}'
        outputs[relative] = data
        if sum(len(value) for value in outputs.values()) > 512 * 1024 * 1024:
            raise ValueError('This library exceeds the 512 MB media budget.')
        assets_used.add(relative)
        return relative

    for kind in KINDS:
        paths = []
        for entry in content[kind]:
            resource = ResourceText(SCRIPTS[kind])
            resource.field('id', '&' + json.dumps(entry['id'], ensure_ascii=False))
            resource.field('title', json.dumps(entry['title'], ensure_ascii=False))
            if kind == 'notes':
                resource.field('text', json.dumps(entry.get('text', ''), ensure_ascii=False))
                image = asset(entry.get('image', ''), kind)
                entry['image'] = image or ''
                if image:
                    resource.field('image', resource.reference('Texture2D', 'res://' + image))
            else:
                if kind == 'dialog':
                    resource.field('start_line', json.dumps(entry.get('start_line', '')))
                rendered = []
                for line in entry.get('lines', []):
                    audio = asset(line.get('audio', ''), kind)
                    line['audio'] = audio or ''
                    fields = [json.dumps(key) + ': ' + json.dumps(line.get(key, ''), ensure_ascii=False) for key in ('id', 'speaker', 'text')]
                    if audio:
                        fields.append('"audio": ' + resource.reference('AudioStream', 'res://' + audio))
                    if kind == 'dialog':
                        fields.extend(['"next": ' + json.dumps(line.get('next', '')), '"choices": ' + json.dumps(line.get('choices', []), ensure_ascii=False)])
                    rendered.append('{' + ', '.join(fields) + '}')
                resource.field('lines', 'Array[Dictionary]([' + ',\n'.join(rendered) + '])')
            relative = f'lexicon/{kind}/{entry["id"]}.tres'
            outputs[relative] = resource.finish()
            paths.append(relative)
        catalog = ResourceText('catalog')
        references = [catalog.reference('Resource', 'res://' + path) for path in paths]
        catalog.field('entries', 'Array[Resource]([' + ', '.join(references) + '])')
        outputs[f'lexicon/{kind}/{CATALOGS[kind]}.tres'] = catalog.finish()
    master = ResourceText('database')
    for kind in KINDS:
        master.field(kind, master.reference('Resource', f'res://lexicon/{kind}/{CATALOGS[kind]}.tres'))
    outputs['lexicon/lexicon_db.tres'] = master.finish()
    # This is the portable editable source, for reopening and agent authoring.
    outputs['lexicon/lexicon.source.json'] = (json.dumps(content, indent=2, ensure_ascii=False) + '\n').encode('utf8')
    for source in plugin.rglob('*'):
        if source.is_file() and source.suffix in {'.gd', '.uid', '.cfg', '.md', '.tscn'}:
            outputs['addons/lexicon/' + source.relative_to(plugin).as_posix()] = source.read_bytes()
    manifest_path = safe_path(project, 'lexicon/.lexicon-manifest.json')
    old = json.loads(manifest_path.read_text()) if manifest_path.exists() else {'version': 1, 'files': {}}
    if not isinstance(old, dict) or old.get('version') != 1 or not isinstance(old.get('files'), dict):
        raise ValueError('Invalid export ownership manifest.')
    owned = old['files']
    stale = set(owned) - set(outputs)
    for relative in set(outputs) | stale:
        if not relative.startswith(('lexicon/', 'addons/lexicon/')):
            raise ValueError('Ownership manifest contains an unrelated path.')
        target = safe_path(project, relative)
        if target.exists() and relative not in owned and target.read_bytes() != outputs.get(relative):
            raise ValueError('An unmanaged file would be overwritten: ' + relative)
        if relative in stale and target.exists() and digest(target.read_bytes()) != owned[relative]:
            raise ValueError('A removed export was edited outside Lexicon; preserve/move it first: ' + relative)
    backups = {relative: safe_path(project, relative).read_bytes() if safe_path(project, relative).exists() else None for relative in set(outputs) | stale}
    for relative in stale:
        if Path(relative).suffix.lower() in IMAGE_EXTENSIONS | AUDIO_EXTENSIONS:
            companion = safe_path(project, relative + '.import')
            if companion.is_file():
                backups[relative + '.import'] = companion.read_bytes()
    original_manifest = manifest_path.read_bytes() if manifest_path.exists() else None
    try:
        for folder in ('lexicon/notes/images', 'lexicon/dialog/vocals', 'lexicon/flavor/vocals'):
            safe_path(project, folder).mkdir(parents=True, exist_ok=True)
        for relative, data in outputs.items():
            if backups[relative] != data:
                atomic_write(safe_path(project, relative), data)
        for relative in stale:
            target = safe_path(project, relative)
            if target.is_file():
                target.unlink()
            # Godot's generated import descriptor may refer to a deleted media file.
            if target.suffix.lower() in IMAGE_EXTENSIONS | AUDIO_EXTENSIONS:
                companion = safe_path(project, relative + '.import')
                if companion.is_file():
                    companion.unlink()
        manifest = {'version': 1, 'files': {path: digest(data) for path, data in outputs.items()}}
        atomic_write(manifest_path, (json.dumps(manifest, indent=2) + '\n').encode())
    except Exception:
        for relative, data in backups.items():
            target = safe_path(project, relative)
            if data is None:
                target.unlink(missing_ok=True)
            else:
                atomic_write(target, data)
        if original_manifest is None:
            manifest_path.unlink(missing_ok=True)
        else:
            atomic_write(manifest_path, original_manifest)
        raise
    return {'database': content, 'files': len(outputs), 'assets': len(assets_used), 'removed': len(stale)}


def open_library(project: Path):
    path = project / 'lexicon/lexicon.source.json'
    return validate(json.loads(path.read_text(encoding='utf8'))) if path.exists() else empty_database()
