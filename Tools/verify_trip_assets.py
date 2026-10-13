"""Verify the portable spreadsheet exports without relying on engine caches."""
import json
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'Models/Imported/Trip'


def main():
    catalog = json.loads((BASE / 'catalog.json').read_text())
    assert len(catalog) == 32 and len({e['id'] for e in catalog}) == 32
    triangles = 0
    for entry in catalog:
        folder = BASE / entry['id']
        manifest = json.loads((folder / 'asset_manifest.json').read_text())
        assert (ROOT / manifest['native']).is_file() and (ROOT / manifest['source']).is_file()
        assert (folder / 'Source/.gdignore').is_file()
        raw = (ROOT / manifest['export']).read_bytes()
        magic, version, length = struct.unpack_from('<III', raw)
        assert magic == 0x46546C67 and version == 2 and length == len(raw)
        chunk_size, chunk_type = struct.unpack_from('<II', raw, 12)
        assert chunk_type == 0x4E4F534A
        asset = json.loads(raw[20:20 + chunk_size])
        assert not asset.get('cameras') and 'KHR_lights_punctual' not in asset.get('extensions', {})
        for image in asset['images']:
            assert 'bufferView' in image, entry['id'] + ': portable embedded texture'
        for mesh in asset['meshes']:
            for primitive in mesh['primitives']:
                assert 'TEXCOORD_0' in primitive['attributes'] and 'material' in primitive
                triangles += asset['accessors'][primitive['indices']]['count'] // 3
        assert len([p for p in (ROOT / 'Reports/TripModels').glob(entry['id'] + '_[123].png')]) == 3
        assert max(manifest['dimensions_m']) < 5
    print(f'Trip portable assets: PASS / {len(catalog)} textured GLBs / {triangles} triangles / 96 actual prop views')


if __name__ == '__main__':
    main()
