"""Apply October F1 architecture corrections without rebuilding imported materials.
Run Blender --background --python Tools/rework_memory_art.py. Renders retain a
separate diagnostic presentation rig; game warehouse/hospital lighting is black.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'Tools'))
import warehouse_common as w
bpy.context.preferences.filepaths.save_version=0
for kind in (('hospital',) if '--hospital-only' in sys.argv else ('hospital','warehouse')):
 folder=ROOT/'Models/Architecture'/('DilapidatedHospital' if kind=='hospital' else 'DilapidatedWarehouse')
 stem='dilapidated_'+kind;native=folder/'Source'/(stem+'.blend')
 bpy.ops.wm.open_mainfile(filepath=str(native))
 architecture=next(c for c in bpy.data.collections if c.name.startswith('ARCHITECTURE'))
 w.asset=architecture
 if kind=='hospital':
  for obj in list(architecture.objects):
   if obj.name.startswith('Corridor impact rail') and (abs(obj.location.y)<2.31 or (obj.location.x>0 and -5.8<obj.location.y< -1.7)):
    bpy.data.objects.remove(obj,do_unlink=True)
   elif obj.name.startswith('OUTER | end wall header'):
    # Source frame 1.7195 + half of the 3.18 m portal = 3.3095 m.
    obj.location.z=3.33;obj.dimensions.z=.04
  material=next(o.data.materials[0] for o in architecture.objects if o.type=='MESH' and o.name.startswith('Corridor impact rail'))
  if not any(o.name.startswith('Closed far exit') for o in architecture.objects):
   for x in (-.65,.65):
    w.box('Closed far exit leaf',(x,12.94,1.59),(1.295,.12,3.18),material,.006)
    w.box('Closed far exit push bar',(x,12.865,1.03),(.92,.035,.04),material,.004)
 else:
  material=next(o.data.materials[0] for o in architecture.objects if o.type=='MESH' and 'Worn safety nosing' in o.name)
  if not any(o.name.startswith('Catwalk rear gap guard') for o in architecture.objects):
   for z in (4.7,5.23):w.box('Catwalk rear gap guard rail',(2.0,10.60,z),(3.80,.045,.045),material,.004)
   for x in (.10,1.37,2.63,3.90):w.box('Catwalk rear gap guard post',(x,10.60,4.72),(.055,.055,1.04),material,.004)
   w.box('Catwalk rear gap guard toe board',(2.0,10.60,4.29),(3.8,.035,.12),material,.003)
 bpy.context.view_layer.update()
 bpy.ops.wm.save_as_mainfile(filepath=str(native))
 bpy.ops.object.select_all(action='DESELECT')
 for o in architecture.objects:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(folder/(stem+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False,export_extras=True,export_yup=True)
 info=json.loads((folder/'asset_manifest.json').read_text());info['october_issue_revision']='Taller hospital portal opening, supported rails, closed far exit / guarded warehouse rear balcony gap'
 (folder/'asset_manifest.json').write_text(json.dumps(info,indent=2)+'\n')
 scene=bpy.context.scene;scene.cycles.samples=24;scene.render.resolution_x=900;scene.render.resolution_y=600;scene.render.resolution_percentage=100
 output=ROOT/'Reports/IssueBatch'/kind;output.mkdir(parents=True,exist_ok=True)
 cams=sorted([o for o in bpy.data.objects if o.type=='CAMERA'],key=lambda o:o.name)[:3]
 for i,cam in enumerate(cams):
  scene.camera=cam;scene.render.filepath=str(output/(str(i+1)+'.png'));bpy.ops.render.render(write_still=True)
# Keep separately linked assemblies in sync with their current placement manifests.
for directory,filename,list_key in [('FurnishedStudio','studio_apartment_furnished.blend','linked_assets'),('DilapidatedHospital','hospital_assembly.blend','instances')]:
 folder=ROOT/'Models/Interiors'/directory;bpy.ops.wm.open_mainfile(filepath=str(folder/filename))
 entries=json.loads((folder/'assembly_manifest.json').read_text())[list_key]
 for o in bpy.data.objects:
  if o.type!='EMPTY' or o.instance_type!='COLLECTION':continue
  for e in entries:
   name=e.get('name',e.get('asset',''))
   if name.lower() in o.name.lower():
    o.location=e['position_m'];o.rotation_euler.z=math.radians(e['rotation_z_degrees']);break
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/filename))
print('MEMORY ART REWORK COMPLETE',flush=True)
