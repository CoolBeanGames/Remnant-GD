#!/usr/bin/env python3
"""Verified Windows export using matching official Godot templates and isolated smoke data."""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, target: Path) -> None:
    request = urllib.request.Request(url, headers={'User-Agent': 'Godot-project-build'})
    partial = target.with_name(target.name + '.part')
    with urllib.request.urlopen(request, timeout=60) as source, partial.open('wb') as output:
        shutil.copyfileobj(source, output, 1024 * 1024)
    partial.replace(target)


def templates(root: Path, version: str, appdata: Path) -> dict:
    release_match = re.fullmatch(r'(\d+\.\d+(?:\.\d+)?)\.(stable|beta\d+|rc\d+)', version)
    if not release_match:
        raise RuntimeError('Custom/development engines require manually supplied matching export templates.')
    tag = release_match[1] + '-' + release_match[2]
    location = appdata / 'Godot' / 'export_templates' / version
    metadata = location / 'template-source.json'
    if metadata.exists():
        cached = json.loads(metadata.read_text(encoding='utf-8'))
        if cached.get('version') == version and all((location / name).is_file() and sha256(location / name) == digest for name, digest in cached.get('files', {}).items()) and 'windows_release_x86_64.exe' in cached.get('files', {}):
            return cached
    request = urllib.request.Request('https://api.github.com/repos/godotengine/godot-builds/releases/tags/' + tag, headers={'User-Agent': 'Godot-project-build'})
    with urllib.request.urlopen(request, timeout=30) as response:
        release = json.load(response)
    asset_name = 'Godot_v' + tag + '_export_templates.tpz'
    asset = next(asset for asset in release['assets'] if asset['name'] == asset_name)
    digest = asset.get('digest', '')
    if not digest.startswith('sha256:'):
        raise RuntimeError('Official release lacks a SHA-256 asset digest; verify templates manually instead.')
    archive = root / '.godot' / 'export_templates' / (tag + '.tpz')
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.exists():
        print('Downloading official matching export templates...', flush=True)
        download(asset['browser_download_url'], archive)
    if sha256(archive) != digest.split(':', 1)[1]:
        raise RuntimeError('Export template archive failed official SHA-256 verification.')
    location.mkdir(parents=True, exist_ok=True)
    files = {}
    with zipfile.ZipFile(archive) as bundle:
        for member in bundle.infolist():
            name = Path(member.filename).name
            if member.filename != 'templates/' + name or not (name.startswith('windows_') or name in ('version.txt', 'icudt_godot.dat')):
                continue
            target = location / name
            with bundle.open(member) as source, target.open('wb') as output:
                shutil.copyfileobj(source, output)
            files[name] = sha256(target)
    provenance = {'version': version, 'url': asset['browser_download_url'], 'archive_sha256': digest.split(':', 1)[1], 'files': files}
    metadata.write_text(json.dumps(provenance, indent=2) + '\n', encoding='utf-8')
    return provenance


def run(arguments: list[str], environment: dict, output: Path, timeout: int = 240) -> None:
    with output.open('w', encoding='utf-8') as log:
        completed = subprocess.run(arguments, stdout=log, stderr=subprocess.STDOUT, env=environment, timeout=timeout)
    content = output.read_text(encoding='utf-8', errors='replace')
    if completed.returncode or re.search(r'(?m)^(?:SCRIPT ERROR:|ERROR:|WARNING:)', content):
        raise RuntimeError('Godot failed verification; inspect ' + str(output))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True, type=Path)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--preset', default='Windows Desktop')
    parser.add_argument('--output', type=Path, help='New output folder inside project Builds/.')
    args = parser.parse_args()
    root = args.project.resolve()
    engine = args.godot.resolve(strict=True)
    if not (root / 'project.godot').is_file() or not (root / 'export_presets.cfg').is_file():
        raise RuntimeError('Project or export preset is missing.')
    raw_version = subprocess.check_output([str(engine), '--version'], text=True).strip().splitlines()[-1]
    version_match = re.match(r'(\d+\.\d+(?:\.\d+)?\.(?:stable|beta\d+|rc\d+))', raw_version)
    if not version_match:
        raise RuntimeError('Unrecognized Godot version: ' + raw_version)
    version = version_match[1]
    appdata = root / '.godot' / 'build_profile'
    appdata.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, APPDATA=str(appdata))
    source = templates(root, version, appdata)
    timestamp = dt.datetime.now().astimezone().strftime('%Y-%m-%d_%H-%M-%S')
    folder = (args.output or root / 'Builds' / ('Windows_' + timestamp)).resolve()
    builds_root = (root / 'Builds').resolve()
    if not folder.is_relative_to(builds_root) or folder == builds_root or folder.exists():
        raise RuntimeError('Choose a new output folder within project Builds/.')
    folder.mkdir(parents=True)
    executable = folder / 'Remnant.exe'
    print('Importing and exporting Windows ' + version + '...', flush=True)
    run([str(engine), '--headless', '--editor', '--path', str(root), '--quit', '--log-file', str(folder / 'import-engine.log')], environment, folder / 'import.log')
    run([str(engine), '--headless', '--path', str(root), '--export-release', args.preset, str(executable), '--log-file', str(folder / 'export-engine.log')], environment, folder / 'export.log', 600)
    if not executable.is_file() or not executable.with_suffix('.pck').is_file():
        raise RuntimeError('Export did not produce an executable and separate PCK.')
    smoke_environment = dict(os.environ, APPDATA=str(folder / 'smoke_profile'))
    run([str(executable), '--headless', '--quit-after', '90', '--log-file', str(folder / 'smoke-engine.log')], smoke_environment, folder / 'smoke.log', 60)
    revision = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    worktree = subprocess.check_output(['git', '-C', str(root), 'status', '--short'], text=True).strip().splitlines()
    manifest = {'created_at': dt.datetime.now().astimezone().isoformat(), 'engine': raw_version, 'mode': 'release', 'preset': args.preset, 'source_commit': revision, 'source_worktree_changes': worktree, 'templates': source, 'verification': ['editor import', 'Windows release export', 'isolated headless exported startup 90 frames'], 'files': {path.name: {'bytes': path.stat().st_size, 'sha256': sha256(path)} for path in folder.iterdir() if path.is_file() and path.suffix.lower() in ('.exe', '.pck', '.dll')}}
    (folder / 'build.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (builds_root / 'latest.txt').write_text(str(folder) + '\n', encoding='utf-8')
    print('Windows build verified: ' + str(executable), flush=True)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, StopIteration, subprocess.SubprocessError) as failure:
        print('Build failed: ' + str(failure), file=sys.stderr)
        raise SystemExit(1)
