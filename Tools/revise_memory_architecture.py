"""Close the warehouse shutter and remove the retired hospital exit leaves."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
bpy.context.preferences.filepaths.save_version = 0
for folder, stem, collection in [('DilapidatedWarehouse', 'dilapidated_warehouse', 'ARCHITECTURE | dilapidated warehouse'), ('DilapidatedHospital', 'dilapidated_hospital', 'ARCHITECTURE | dilapidated hospital')]:
    directory = ROOT / 'Models/Architecture' / folder
    bpy.ops.wm.open_mainfile(filepath=str(directory / 'Source' / (stem + '.blend')))
    architecture = bpy.data.collections[collection]
    if folder == 'DilapidatedWarehouse':
        samples = [o for o in architecture.objects if o.name.startswith('Jammed roller shutter')]
        if not samples:
            raise RuntimeError('Missing source shutter')
        prototype = samples[0]
        for i in range(25):
            name = f'Closed roller shutter / lower slat {i:02d}'
            if name in bpy.data.objects:
                continue
            obj = prototype.copy()
            obj.name = name
            architecture.objects.link(obj)
            obj.location.z = .08 + i * .14
        for material in bpy.data.materials:
            if 'office glazing' in material.name.lower():
                shader = material.node_tree.nodes.get('Principled BSDF')
                shader.inputs['Alpha'].default_value = .12
                shader.inputs['Roughness'].default_value = .12
    else:
        for obj in list(architecture.objects):
            if obj.name.startswith(('Closed far exit leaf', 'Closed far exit push bar')):
                bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(directory / 'Source' / (stem + '.blend')))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in architecture.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(directory / (stem + '.glb')), export_format='GLB', use_selection=True, export_apply=True, export_animations=False, export_cameras=False, export_lights=False, export_yup=True)
    print('REVISED', folder, flush=True)
