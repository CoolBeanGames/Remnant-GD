"""Seed embedded compressed texture imports, preserving any existing asset UIDs."""
from pathlib import Path
import hashlib
import json
ROOT=Path(__file__).resolve().parents[1]
template=(ROOT/'Models/Architecture/StudioApartment/studio_apartment.glb.import').read_text()
params=template.split('[params]',1)[1]
assert 'gltf/embedded_image_handling=2' in params
manifests=[ROOT/'Models/Architecture/DilapidatedWarehouse/asset_manifest.json',
           *sorted((ROOT/'Models/Interiors/WarehouseMachinery').glob('*/asset_manifest.json'))]
created=0
for path in manifests:
    info=json.loads(path.read_text());export=ROOT/info['export'];sidecar=export.with_suffix('.glb.import')
    if sidecar.exists():continue
    resource='res://'+info['export'];digest=hashlib.md5(resource.encode()).hexdigest()
    imported=f'res://.godot/imported/{export.name}-{digest}.scn'
    sidecar.write_text('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n'
        f'path="{imported}"\n\n[deps]\n\nsource_file="{resource}"\ndest_files=["{imported}"]\n\n[params]'+params,
        encoding='utf-8',newline='\n');created+=1
print('Warehouse imports:',created,'new sidecars; existing UIDs/settings preserved')
