"""Seed new studio GLB import settings before the Godot editor scans them.

Keep embedded textures inside imported resources instead of extracting duplicate
PNGs next to the exports. Existing sidecars, UIDs and custom settings are preserved.
Run after modelling and before the Godot editor's import pass.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
template = (ROOT / 'Models/Architecture/StudioApartment/studio_apartment.glb.import').read_text()
params = template.split('[params]', 1)[1]
assert 'gltf/embedded_image_handling=2' in params
created = 0
for manifest in sorted((ROOT / 'Models/Interiors/StudioFurniture').glob('*/asset_manifest.json')):
    info = json.loads(manifest.read_text())
    export = ROOT / info['export']
    sidecar = export.with_suffix('.glb.import')
    if sidecar.exists():
        continue
    resource = 'res://' + info['export']
    digest = hashlib.md5(resource.encode('utf-8')).hexdigest()
    imported = f'res://.godot/imported/{export.name}-{digest}.scn'
    sidecar.write_text(
        '[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n'
        f'path="{imported}"\n\n[deps]\n\nsource_file="{resource}"\n'
        f'dest_files=["{imported}"]\n\n[params]' + params,
        encoding='utf-8', newline='\n',
    )
    created += 1
print(f'Studio imports: {created} new sidecars; existing settings preserved')
