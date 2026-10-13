#!/usr/bin/env python3
"""Package Lexicon as a standalone Windows executable using an isolated builder."""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import shutil
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    root = args.project.resolve()
    folder = (args.output or root / 'Builds' / ('Lexicon_' + dt.datetime.now().astimezone().strftime('%Y-%m-%d_%H-%M-%S'))).resolve()
    if not folder.is_relative_to(root / 'Builds') or folder == root / 'Builds' or folder.exists():
        raise ValueError('Choose a new output folder within Builds/.')
    # Run this helper from the isolated build environment, never the game's runtime.
    version = subprocess.check_output([sys.executable, '-m', 'PyInstaller', '--version'], text=True).strip()
    folder.mkdir(parents=True)
    packaging = root / '.godot/lexicon_packaging'
    command = [sys.executable, '-m', 'PyInstaller', '--noconfirm', '--clean', '--onefile', '--windowed', '--name', 'Lexicon', '--specpath', str(packaging), '--workpath', str(packaging / 'work'), '--distpath', str(folder), '--add-data', str(root / 'Tools/Lexicon/index.html') + ':.', '--add-data', str(root / 'addons/lexicon') + ':plugin', str(root / 'Tools/Lexicon/lexicon.py')]
    with (folder / 'build.log').open('w', encoding='utf8') as log:
        subprocess.run(command, cwd=root, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=600)
    executable = folder / 'Lexicon.exe'
    if not executable.is_file():
        raise RuntimeError('No executable was produced.')
    shutil.copy2(root / 'Tools/Lexicon/README.md', folder / 'README.md')
    revision = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    manifest = {'created_at': dt.datetime.now().astimezone().isoformat(), 'source_commit': revision, 'source_worktree_changes': subprocess.check_output(['git', '-C', str(root), 'status', '--short'], text=True).strip().splitlines(), 'python': sys.version, 'pyinstaller': version, 'file': {'name': executable.name, 'bytes': executable.stat().st_size, 'sha256': hashlib.sha256(executable.read_bytes()).hexdigest()}, 'verification': ['Packaging complete; functional executable test is a separate required check.']}
    (folder / 'build.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf8')
    (root / 'Builds/latest_lexicon.txt').write_text(str(folder) + '\n', encoding='utf8')
    print('Lexicon packaged: ' + str(executable), flush=True)


if __name__ == '__main__':
    main()
