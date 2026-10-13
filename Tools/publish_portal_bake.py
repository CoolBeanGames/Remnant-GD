"""Publish --stage portal output atomically, without partial editor-watched files."""
from pathlib import Path
import os
import json
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def atomic_write(target: Path, data: bytes) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.portal-bake-', suffix='.tmp', dir=target.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
        for attempt in range(40):
            try:
                os.replace(temporary, target)
                return
            except OSError:
                if attempt == 39:
                    raise
                time.sleep(.05)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> None:
    staged = ROOT / '.godot/portal_bake'
    destination = (ROOT / 'Scenes/Environments').resolve()
    manifest = json.loads((staged / 'bake_manifest.json').read_text(encoding='utf8'))
    files = sorted((staged / name).resolve() for name in manifest['files'])
    if len(set(files)) != len(files) or any(not p.is_relative_to(staged.resolve()) or p.suffix not in ('.tscn', '.tres') for p in files):
        raise ValueError('Invalid staged resource manifest')
    if not files:
        raise ValueError('Empty staged resource manifest')
    for source in files:
        target = (destination / source.relative_to(staged.resolve())).resolve()
        if not target.is_relative_to(destination):
            raise ValueError('Bake destination escapes Scenes/Environments')
        data = source.read_bytes()
        if not target.exists() or target.read_bytes() != data:
            atomic_write(target, data)
    print(f'Published {len(files)} staged portal resources atomically')


if __name__ == '__main__':
    main()
