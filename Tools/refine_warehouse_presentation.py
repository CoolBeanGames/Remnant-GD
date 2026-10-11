"""Apply reviewed camera/light/office-placement refinements without rebuilding meshes.

The structural builder contains the same final values. This small, repeatable pass
updates the two saved presentation rigs and rerenders their six environment views.
Architecture GLB geometry/materials are unchanged.
"""
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import warehouse_common as w

ROOM=w.ROOT/'Models/Architecture/DilapidatedWarehouse'
ASSEMBLY=w.ROOT/'Models/Interiors/DilapidatedWarehouse'


def update_rig():
    scene=w.configure(128,1800,1200)
    rig=bpy.data.collections['PRESENTATION | warehouse daylight and cameras']
    for light in rig.objects:
        if light.type=='LIGHT' and light.data.type=='AREA':
            light.visible_camera=False;light.visible_glossy=False;light.visible_transmission=False
    for name,pos,target in [('04 | broken machinery',(-9,-.6,2.2),(-3.4,6,1.8)),
                            ('05 | warehouse exterior',(-33,-37,17),(0,0,4.5))]:
        o=bpy.data.objects[name];o.location=pos;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    scene.camera=bpy.data.objects['01 | production hall']
    return scene


bpy.ops.wm.open_mainfile(filepath=str(ROOM/'Source/dilapidated_warehouse.blend'))
update_rig();bpy.ops.wm.save_as_mainfile(filepath=str(ROOM/'Source/dilapidated_warehouse.blend'))
bpy.ops.wm.open_mainfile(filepath=str(ASSEMBLY/'warehouse_assembly.blend'))
scene=update_rig()
bpy.data.objects['LandlinePhone'].location=(5.95,13.72,4.995)
bpy.data.objects['PileOfMail'].location=(6.40,13.21,4.997)
manifest=ASSEMBLY/'assembly_manifest.json'
info=json.loads(manifest.read_text())
for instance in info['instances']:
    if instance['name']=='LandlinePhone':instance['position_m']=[5.95,13.72,4.995]
    if instance['name']=='PileOfMail':instance['position_m']=[6.40,13.21,4.997]
manifest.write_text(json.dumps(info,indent=2)+'\n')
bpy.ops.wm.save_as_mainfile(filepath=str(ASSEMBLY/'warehouse_assembly.blend'))
views={'production_floor':'01 | production hall','catwalk':'02 | upper catwalk','office':'03 | production office',
       'machines':'04 | broken machinery','exterior':'05 | warehouse exterior','overview':'06 | architectural cutaway'}
for name,cam in views.items():
    scene.camera=bpy.data.objects[cam];scene.render.filepath=str(w.RENDERS/f'{name}.png')
    if name=='overview':
        room_instance=bpy.data.objects['Warehouse shell'];room_instance.hide_render=True
        source=bpy.data.collections['ARCHITECTURE | dilapidated warehouse']
        # Linked datablocks are read-only; make a local temporary collection for cutaway.
        cut=bpy.data.collections.new('TEMPORARY | cutaway');scene.collection.children.link(cut)
        for original in source.objects:
            bounds=[original.matrix_world@Vector(c) for c in original.bound_box] if original.type=='MESH' else [original.location]
            centre=sum(bounds,Vector())/len(bounds)
            ceiling=original.name.startswith(('ROOF |','Truss ','West rafter','East rafter','Roof purlin','Broken rooflight','Rooflight crossbar','Office ceiling'))
            perimeter=(centre.x < -11.1 or centre.y < -17.0) and not original.name.startswith('Jointed concrete slab')
            if not ceiling and not perimeter:
                copy=original.copy();cut.objects.link(copy)
    print('WAREHOUSE REFINED RENDER',name,flush=True);bpy.ops.render.render(write_still=True)
    if name=='overview':
        for obj in list(cut.objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(cut);room_instance.hide_render=False
print('WAREHOUSE REFINEMENT COMPLETE; complete native model preserved',flush=True)
