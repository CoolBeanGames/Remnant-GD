"""Read the user's Trip Models spreadsheet and safely extract its 32 sources.

The workbook/ZIP folder is user input, never copied into published reports.
"""
import json
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
INPUT = Path('D:/Downloads/Trip Models')
OUTPUT = ROOT / 'Models/Imported/Trip'
NAMES = [
    ('baby+bottle+3d+model.zip', 'baby_bottle', .24),
    ('beer+bottle+3d+model.zip', 'beer_bottle', .30),
    ('clipboard+with+papers+3d+model.zip', 'clipboard', .34),
    ('Computer.zip', 'computer', .68),
    ('garbage+bag+3d+model (1).zip', 'garbage_bag_a', .68),
    ('garbage+bag+3d+model.zip', 'garbage_bag_b', .64),
    ('lounger+chair.zip', 'lounger', 1.12),
    ('meat+slab+3d+model (1).zip', 'meat_slab_a', .28),
    ('meat+slab+3d+model.zip', 'meat_slab_b', .30),
    ('medical+syringe+3d+model.zip', 'syringe', .20),
    ('office+chair+3d+model.zip', 'office_chair', 1.18),
    ('old+television+3d+model.zip', 'television', .64),
    ('old+wooden+crate+3d+model.zip', 'mulch_bin', 1.0),
    ('paper+stack+3d+model.zip', 'paper_stack', .32),
    ('raw+meat+block+3d+model.zip', 'meat_block', .28),
    ('rusted+cart+3d+model.zip', 'computer_cart', 1.05),
    ('rusted+metal+siding+3d+model.zip', 'steel_plate', 2.4),
    ('rusted+waiting+chairs+3d+model.zip', 'waiting_chairs', 2.15),
    ('rustic+coffee+table+3d+model.zip', 'coffee_table', 1.15),
    ('rusty+hospital+bed+3d+model.zip', 'hospital_bed', 2.15),
    ('rusty+industrial+machine+3d+model (1).zip', 'industrial_machine_a', 2.45),
    ('rusty+industrial+machine+3d+model (2).zip', 'industrial_machine_b', 2.5),
    ('rusty+industrial+machine+3d+model.zip', 'industrial_machine_c', 2.35),
    ('rusty+lever+switch+3d+model.zip', 'lever', 2.05),
    ('rusty+mulcher+3d+model.zip', 'mulcher', 1.35),
    ('rusty+wheelchair+3d+model.zip', 'wheelchair', 1.13),
    ('steampunk+book+3d+model.zip', 'book', .34),
    ('teddy+bear+3d+model.zip', 'teddy_bear', .32),
    ('three-seat+couch+3d+model.zip', 'couch', 2.25),
    ('trash+ball+3d+model.zip', 'mulch_pellet', .24),
    ('wooden+desk+3d+model.zip', 'desk', 1.45),
    ('wooden+door+3d+model.zip', 'door', 3.18),
]


def workbook_rows():
    ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    with zipfile.ZipFile(INPUT / 'files.xlsx') as archive:
        shared = []
        if 'xl/sharedStrings.xml' in archive.namelist():
            shared = [''.join(si.itertext()) for si in ET.fromstring(archive.read('xl/sharedStrings.xml')).findall('s:si', ns)]
        sheet = ET.fromstring(archive.read('xl/worksheets/sheet1.xml'))
        rows = []
        for row in sheet.findall('.//s:row', ns):
            values = {}
            for cell in row.findall('s:c', ns):
                node = cell.find('s:v', ns)
                value = node.text if node is not None else ''.join(cell.find('s:is', ns).itertext()) if cell.find('s:is', ns) is not None else ''
                if cell.get('t') == 's':
                    value = shared[int(value)]
                values[''.join(c for c in cell.get('r') if c.isalpha())] = value
            rows.append(values)
    return {row['A']: {'usage': row.get('B', ''), 'processing': row.get('C', '')} for row in rows[1:] if row.get('A')}


if __name__ == '__main__':
    rows = workbook_rows()
    assert set(rows) == {name for name, _, _ in NAMES}, 'Spreadsheet ZIP list changed; review before importing'
    catalog = []
    for filename, name, size in NAMES:
        destination = OUTPUT / name / 'Source'
        destination.mkdir(parents=True, exist_ok=True)
        (destination / '.gdignore').write_text('')
        with zipfile.ZipFile(INPUT / filename) as archive:
            for member in archive.infolist():
                target = (destination / member.filename).resolve()
                if not target.is_relative_to(destination.resolve()):
                    raise RuntimeError('Unsafe ZIP member: ' + member.filename)
                if member.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_bytes(archive.read(member))
        catalog.append({'id': name, 'zip': filename, 'size': size, **rows[filename]})
    (OUTPUT / 'catalog.json').write_text(json.dumps(catalog, indent=2) + '\n')
    print('Safely extracted', len(catalog), 'spreadsheet assets')
