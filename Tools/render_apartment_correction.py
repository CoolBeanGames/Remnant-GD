"""Four actual Cycles views of the floor repair and relocated TV assembly."""
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Reports/ApartmentCorrection'
OUT.mkdir(parents=True, exist_ok=True)
(OUT / '.gdignore').write_text('')
NATIVE = ROOT / 'Models/Interiors/ApartmentCorrectionPresentation/Source'
NATIVE.mkdir(parents=True, exist_ok=True)
(NATIVE / '.gdignore').write_text('')
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'Models/Interiors/FurnishedStudio/studio_apartment_furnished.blend'))
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 32
scene.cycles.use_denoising = True
scene.render.resolution_x, scene.render.resolution_y = 1280, 853
scene.render.resolution_percentage = 100
prefs = bpy.context.preferences.addons['cycles'].preferences
try:
    prefs.compute_device_type = 'OPTIX'
    prefs.refresh_devices()
    for device in prefs.devices:
        device.use = device.type == 'OPTIX'
    scene.cycles.device = 'GPU' if any(d.type == 'OPTIX' for d in prefs.devices) else 'CPU'
except Exception:
    scene.cycles.device = 'CPU'
rig = bpy.data.collections.new('PRESENTATION | floor and TV review')
scene.collection.children.link(rig)
for index, point in enumerate([(3, 0, 2.65), (10, 0, 2.65)]):
    data = bpy.data.lights.new('Inspection practical ' + str(index), 'AREA')
    data.energy, data.size = 120, 3
    obj = bpy.data.objects.new(data.name, data)
    rig.objects.link(obj)
    obj.location = point
views = [
    ('living', (6.8, -.5, 1.65), (2, -.5, 1.1), 22),
    ('television', (3.1, .65, 1.65), (4.55, -2.8, .9), 28),
    ('floor', (5.5, -.65, 1.0), (3.9, .15, .015), 27),
    ('doorway', (8.4, -.575, 1.65), (5.5, -.575, 1.1), 22),
]
for name, point, target, lens in views:
    data = bpy.data.cameras.new('Correction / ' + name)
    data.lens, data.clip_start = lens, .03
    obj = bpy.data.objects.new(data.name, data)
    rig.objects.link(obj)
    obj.location = point
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = obj
    scene.render.filepath = str(OUT / ('blender_' + name + '.png'))
    bpy.ops.render.render(write_still=True)
scene.camera = bpy.data.objects['Correction / living']
bpy.ops.wm.save_as_mainfile(filepath=str(NATIVE / 'apartment_presentation.blend'))
print('Apartment correction: four final Cycles views', flush=True)
