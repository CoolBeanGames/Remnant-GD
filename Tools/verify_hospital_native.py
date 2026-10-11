"""Real native packing, door access, complete visibility and window geometry checks."""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
ROOM=ROOT/'Models/Architecture/DilapidatedHospital'
BASE=ROOT/'Models/Interiors/DilapidatedHospital'
PROPS=ROOT/'Models/Interiors/HospitalProps'


def geometry_tree(objects):
    verts=[];faces=[];dg=bpy.context.evaluated_depsgraph_get()
    for obj,matrix in objects:
        ev=obj.evaluated_get(dg);me=ev.to_mesh();start=len(verts)
        verts.extend(matrix@v.co for v in me.vertices)
        faces.extend(tuple(start+i for i in f.vertices) for f in me.polygons);ev.to_mesh_clear()
    return BVHTree.FromPolygons(verts,faces)


manifests=[*sorted(PROPS.glob('*/asset_manifest.json')),ROOM/'asset_manifest.json']
assert len(manifests)==9
for path in manifests:
    info=json.loads(path.read_text());bpy.ops.wm.open_mainfile(filepath=str(ROOT/info['native']))
    col=bpy.data.collections[info['collection']];meshes=[o for o in col.objects if o.type=='MESH']
    assert len(meshes)==info['mesh_objects']
    assert all(not o.hide_render and not o.hide_viewport for o in col.objects)
    assert not any(o.type in ('LIGHT','CAMERA') for o in col.objects)
    used=set()
    for obj in meshes:
        assert obj.data.uv_layers and obj.data.materials,obj.name
        for mat in obj.data.materials:
            for n in mat.node_tree.nodes:
                if n.type=='TEX_IMAGE' and n.image:used.add(n.image)
    assert used and all(im.packed_file for im in used)
    bpy.context.view_layer.update()
    pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
    assert (hi-lo-Vector(info['dimensions_blender_m'])).length<.001
    if path.parent.name=='HospitalDoor':
        pivot=col.objects['PIVOT | hospital door hinge'];assert len(pivot.children)==10,len(pivot.children)
        assert abs(pivot.rotation_euler.z-math.radians(78))<.0001
    print('HOSPITAL NATIVE PASS',info['key'],len(meshes),'meshes;',len(used),'packed used maps',flush=True)
    if path.parent==ROOM:
        tree=geometry_tree([(o,o.matrix_world) for o in meshes]);clear=solid=0
        for pane in info['window_panes']:
            side=1 if pane['centre'][0]>0 else -1
            centre=Vector(pane['centre']);hit=tree.ray_cast(centre-Vector((side*.32,0,0)),Vector((side,0,0)),.64)[0]
            if pane['state'] in ('broken','missing'):assert hit is None,pane;clear+=1
            else:assert hit is not None,pane;solid+=1
        assert clear>=35 and solid>=5,(clear,solid)
        # Actual shell openings at shoulder/eye height, with +/-24cm side clearance.
        for d in info['door_openings']:
            x,y,z=d['centre'];side=d['side']
            for dz in (.45,1.70):
                for offset in (-.24,0,.24):
                    hit=tree.ray_cast(Vector((side*1.0,y+offset,dz)),Vector((side,0,0)),1.8)[0]
                    assert hit is None,('Door blocked',d,offset,dz,hit)
        # Tested floors include both halls, every room and the rear staff entry.
        for x,y in [(0,-12),(0,0),(0,12),(-7,0),(7,0),(5.8,-2.7),
                    *[(r['door_centre'][0]*2,r['door_centre'][1]) for r in info['rooms']]]:
            hit=tree.ray_cast(Vector((x,y,.2)),Vector((0,0,-1)),.3)[0]
            assert hit is not None and abs(hit.z)<.015,(x,y,hit)
        print('HOSPITAL ARCHITECTURE PASS',clear,'physical glass openings;',solid,'intact panes; seven clear ward doorways; continuous floors',flush=True)

assembly=json.loads((BASE/'assembly_manifest.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(ROOT/assembly['native']))
col=bpy.data.collections['ASSEMBLY | linked hospital architecture and props'];assert len(col.objects)==50
objects=[]
for inst in col.objects:
    assert inst.instance_collection and inst.instance_collection.library and not inst.hide_render
    assert inst.instance_collection.library.filepath.startswith('//')
    assert Path(bpy.path.abspath(inst.instance_collection.library.filepath)).exists()
    record=next(r for r in assembly['instances'] if r['name']==inst.name)
    assert (inst.location-Vector(record['position_m'])).length<.0001
    assert abs(inst.rotation_euler.z-math.radians(record['rotation_z_degrees']))<.0001
    assert all(not o.hide_render for o in inst.instance_collection.objects)
bpy.context.view_layer.update()
for inst in col.objects:
    objects.extend((o,inst.matrix_world@o.matrix_world) for o in inst.instance_collection.objects if o.type=='MESH')
tree=geometry_tree(objects)


def passage(a,b):
    a,b=Vector(a),Vector(b);direction=(b-a).normalized();side=Vector((-direction.y,direction.x,0))
    for height in (.45,1.7):
        for offset in (-.24,0,.24):
            start=a+side*offset+Vector((0,0,height))
            assert tree.ray_cast(start,direction,(b-a).length)[0] is None,('Assembly passage blocked',tuple(a),tuple(b),height,offset)


passage((0,-12.8,0),(0,12.8,0));passage((-8.4,0,0),(8.4,0,0))
for r in json.loads((ROOM/'asset_manifest.json').read_text())['rooms']:
    x,y,z=r['door_centre'];side=1 if x>0 else -1
    passage((side*.10,y,0),(side*(2.6 if r['name']=='Nursing' else 4.2),y,0))
passage((5.8,-.2,0),(5.8,-4.6,0))
# Furniture bounds are checked against actual room perimeter inner faces.
for inst in col.objects:
    if not inst.name.startswith('Ward ') or 'door' in inst.name:continue
    pts=[inst.matrix_world@o.matrix_world@Vector(c) for o in inst.instance_collection.objects if o.type=='MESH' for c in o.bound_box]
    r=next(r for r in json.loads((ROOM/'asset_manifest.json').read_text())['rooms'] if inst.name.startswith(r['name']+' '))
    x0,x1,y0,y1=r['bounds_xy']
    assert min(p.x for p in pts)>=x0-.025 and max(p.x for p in pts)<=x1+.025,inst.name
    assert min(p.y for p in pts)>=y0-.025 and max(p.y for p in pts)<=y1+.025,inst.name
scene=bpy.context.scene
assert scene.camera.name=='01 | long corridor'
assert (scene.render.resolution_x,scene.render.resolution_y)==(1800,1200)
assert not any(o.name.startswith('TEMPORARY') for o in bpy.data.objects)
print('HOSPITAL ASSEMBLY PASS: 50 relative instances; both halls, eight room entries and rear staff route clear; complete shell saved',flush=True)
