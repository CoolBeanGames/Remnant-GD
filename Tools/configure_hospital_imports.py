"""Seed compressed embedded PBR import settings; preserve existing Godot UIDs."""
from pathlib import Path
import hashlib
import json
ROOT=Path(__file__).resolve().parents[1]
template=(ROOT/'Models/Architecture/StudioApartment/studio_apartment.glb.import').read_text()
params=template.split('[params]',1)[1];assert 'gltf/embedded_image_handling=2' in params
paths=[ROOT/'Models/Architecture/DilapidatedHospital/asset_manifest.json',
       *sorted((ROOT/'Models/Interiors/HospitalProps').glob('*/asset_manifest.json'))]
assert len(paths)==9
created=0
for p in paths:
    info=json.loads(p.read_text());export=ROOT/info['export'];sidecar=export.with_suffix('.glb.import')
    if sidecar.exists():continue
    resource='res://'+info['export'];digest=hashlib.md5(resource.encode()).hexdigest()
    imported=f'res://.godot/imported/{export.name}-{digest}.scn'
    sidecar.write_text('[remap]\n\nimporter="scene"\nimporter_version=1\ntype="PackedScene"\n'
        f'path="{imported}"\n\n[deps]\n\nsource_file="{resource}"\ndest_files=["{imported}"]\n\n[params]'+params,
        encoding='utf-8',newline='\n');created+=1
print('Hospital imports:',created,'new sidecars; existing UIDs/settings preserved')
