"""Three reviewed, reproducible Cycles angles per revised memory environment."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Reports/IssueOctober13'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').write_text('')
NATIVE = ROOT / 'Models/Interiors/IssuePresentation/Source'
NATIVE.mkdir(parents=True, exist_ok=True)
(NATIVE / '.gdignore').write_text('')
bpy.context.preferences.filepaths.save_version = 0
sets = [
    ('apartment', 'FurnishedStudio/studio_apartment_furnished.blend', [((-1.8, -2.4, 1.65), (3.4, 1, 1.1)), ((6.8, -.5, 1.65), (2, -.5, 1.1)), ((8.5, -.5, 1.65), (10.3, 1.5, .8))], [(3, 0, 2.65), (10, 0, 2.65)]),
    ('warehouse', 'DilapidatedWarehouse/warehouse_assembly.blend', [((0, -8, 2), (-5, 1, 1.1)), ((0, 12, 1.8), (0, 18, 2)), ((8.3, 11.5, 5.85), (6.4, 13.5, 5.0))], [(0, 0, 8), (7, 13.5, 7)]),
    ('hospital', 'DilapidatedHospital/hospital_assembly.blend', [((0, -7, 1.65), (-1.8, -9.4, 1.1)), ((5.8, .4, 1.65), (5.8, -1.7, 1.1)), ((0, 10, 1.65), (0, 12.94, 1.6))], [(0, 0, 3.1), (0, 10, 3.1), (5.8, 0, 3.1)]),
]
for name, native, views, lights in sets:
    selection = next((s.removeprefix('--only=') for s in sys.argv if s.startswith('--only=')), '')
    if selection and name not in selection.split(','):
        continue
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'Models/Interiors' / native))
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 960
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    prefs = bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type = 'OPTIX'
    prefs.refresh_devices()
    for device in prefs.devices:
        device.use = device.type == 'OPTIX'
    scene.cycles.device = 'GPU' if any(d.type == 'OPTIX' for d in prefs.devices) else 'CPU'
    rig = bpy.data.collections.new('PRESENTATION | October 13 reviewed views')
    scene.collection.children.link(rig)
    for index, point in enumerate(lights):
        data = bpy.data.lights.new('Inspection practical ' + str(index), 'AREA')
        data.energy = 120 if name == 'apartment' else 550
        data.size = 3
        obj = bpy.data.objects.new(data.name, data)
        rig.objects.link(obj)
        obj.location = point
    for index, (point, target) in enumerate(views):
        data = bpy.data.cameras.new(name + ' view ' + str(index + 1))
        data.lens = 22
        data.clip_start = .03
        obj = bpy.data.objects.new(data.name, data)
        rig.objects.link(obj)
        obj.location = point
        obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
        scene.camera = obj
        scene.render.filepath = str(OUT / f'{name}_blender_{index + 1}.png')
        bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(NATIVE / (name + '_presentation.blend')))
    print('RENDERED', name, 'three angles', flush=True)
