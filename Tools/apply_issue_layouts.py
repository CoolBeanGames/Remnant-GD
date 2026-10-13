"""Apply the October 13 walking-clearance and prop-placement revision idempotently."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def revise(filename, positions, scales=None, remove=()):
    path = ROOT / 'Scenes/Environments' / filename
    source = path.read_text(encoding='utf8')
    blocks = re.split(r'(?=^\[node )', source, flags=re.M)
    result = []
    for block in blocks:
        match = re.match(r'\[node name="([^"]+)"', block)
        if match is None:
            result.append(block)
            continue
        name = match[1]
        if name in remove:
            continue
        if name in positions or name in (scales or {}):
            transform = re.search(r'^transform = Transform3D\(([^)]+)\)', block, re.M)
            values = [float(v) for v in transform[1].split(',')] if transform else [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
            if name in positions:
                values[9:] = positions[name]
            if name in (scales or {}):
                length = sum(v*v for v in values[:3])**.5
                values[:9] = [v / length * scales[name] for v in values[:9]]
            line = 'transform = Transform3D(' + ', '.join(f'{v:.9g}' for v in values) + ')'
            if transform:
                block = block[:transform.start()] + line + block[transform.end():]
            else:
                block = re.sub(r'^position = .*\n|^rotation = .*\n|^scale = .*\n', '', block, flags=re.M)
                end = block.index('\n')
                block = block[:end+1] + line + '\n' + block[end+1:]
        result.append(block)
    path.write_text(''.join(result), encoding='utf8')


def main():
    revise('furnished_apartment.tscn', {
        'TrashCan': [-2.2, 0, 2.75], 'Couch': [3.2, 0, -1], 'CoffeeTable': [3.2, 0, 1.55],
        'TableAndChairs': [5.5, 0, -1.65], 'PileOfMail': [5.5, .781, -1.65],
        'Bookshelf': [7.59, 0, -2.15], 'FamilyPhoto': [7.54, 1.851, -2],
        'PottedPlant': [6.91, 0, -2.7], 'BedroomBed': [10.3, 0, -1.5],
        'BedroomLight': [10.2, 2.35, 0], 'InteriorLight': [3.4, 2.45, -1.3],
    }, remove=('BedroomDesk',))
    revise('dilapidated_warehouse.tscn', {
        'LandlinePhone': [5.86, 5.102, -13.764], 'PileOfMail': [6.4, 5.101, -13.152],
    }, {**{name: 1.65 for name in ['HydraulicPress 1', 'HydraulicPress 2', 'IndustrialLathe 1', 'IndustrialLathe 2', 'AirCompressor 1', 'ControlCabinet 1', 'ControlCabinet 2']}, 'OfficeDesk 1': 1.2})
    revise('dilapidated_hospital.tscn', {
        'Cross hall waiting bench': [3.5, 0, 1.22],
        'GarbageBag 3': [.9, 0, 9.5], 'GarbageBag 4': [-.9, 0, -9],
    })
    hospital = ROOT / 'Scenes/Environments/dilapidated_hospital.tscn'
    source = hospital.read_text(encoding='utf8').replace('res://Scenes/Environments/Art/Trip_ward_door.tscn', 'res://Scenes/Actors/memory_door.tscn')
    if 'id="world_door"' not in source:
        source = source.replace('[sub_resource', '[ext_resource type="PackedScene" path="res://Scenes/Actors/memory_door.tscn" id="world_door"]\n\n[sub_resource', 1)
        source += '\n[node name="StaffDoor" parent="Art" instance=ExtResource("world_door")]\nposition = Vector3(5.6, 0, -1.7)\nrotation = Vector3(0, 3.14159265, 0)\ndoor_title = "Staff Door"\n'
        source += '\n[node name="ClosedExitDoor" parent="Art" instance=ExtResource("world_door")]\nposition = Vector3(0, 0, -12.94)\nlocked = true\n'
    hospital.write_text(source, encoding='utf8')
    source = hospital.read_text(encoding='utf8').replace('position = Vector3(5.8, 0, -1.7)', 'position = Vector3(5.8, 0, 1.7)')
    hospital.write_text(source, encoding='utf8')
    print('Revised apartment routes, office/machine scale and hospital doors/clearances')


if __name__ == '__main__':
    main()
