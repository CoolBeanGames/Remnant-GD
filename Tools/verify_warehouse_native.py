"""Blender-native checks: packed maps, relative links, physical window holes/stairs."""
from pathlib import Path
import json
import math
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
ROOM=ROOT/'Models/Architecture/DilapidatedWarehouse'
PROPS=ROOT/'Models/Interiors/WarehouseMachinery'
for path in [*sorted(PROPS.glob('*/asset_manifest.json')),ROOM/'asset_manifest.json']:
    info=json.loads(path.read_text());bpy.ops.wm.open_mainfile(filepath=str(ROOT/info['native']))
    col=bpy.data.collections[info['collection']]
    meshes=[o for o in col.objects if o.type=='MESH']
    assert len(meshes)==info['mesh_objects']
    assert not any(o.type in ('LIGHT','CAMERA') for o in col.objects)
    assert not any(o.hide_render or o.hide_viewport for o in col.objects),'Source saved with cutaway visibility'
    used=set()
    for obj in meshes:
        assert obj.data.uv_layers,obj.name
        assert obj.data.materials,obj.name
        for mat in obj.data.materials:
            for node in mat.node_tree.nodes:
                if node.type=='TEX_IMAGE' and node.image:used.add(node.image)
    assert used and all(im.packed_file for im in used)
    bpy.context.view_layer.update()
    pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
    assert (hi-lo-Vector(info['dimensions_blender_m'])).length<.001
    if path.parent.name=='ControlCabinet':
        pivot=col.objects['PIVOT | cabinet door hinge']
        assert len(pivot.children)==5
        assert abs(pivot.rotation_euler.z-math.radians(-69))<.0001
    print('WAREHOUSE NATIVE PASS',info['key'],len(meshes),'meshes;',len(used),'packed used maps',flush=True)
    if path.parent==ROOM:
        # Evaluated geometry, not authoring metadata, verifies missing glazing holes.
        vertices=[];polygons=[]
        dg=bpy.context.evaluated_depsgraph_get()
        for obj in meshes:
            ev=obj.evaluated_get(dg);me=ev.to_mesh();start=len(vertices)
            vertices.extend(obj.matrix_world@v.co for v in me.vertices)
            polygons.extend(tuple(start+i for i in p.vertices) for p in me.polygons)
            ev.to_mesh_clear()
        tree=BVHTree.FromPolygons(vertices,polygons)
        clear=solid=0
        for pane in info['window_panes']:
            centre=Vector(pane['centre']);side=1 if centre.x>0 else -1
            origin=centre-Vector((side*.40,0,0));direction=Vector((side,0,0))
            hit=tree.ray_cast(origin,direction,.8)[0]
            if pane['state'] in ('missing','broken'):
                # Structural diagonals occasionally cross a pane; test a nearby offset too.
                if hit is not None:hit=tree.ray_cast(origin+Vector((0,.16,.07)),direction,.8)[0]
                if hit is None:clear+=1
            elif hit is not None:solid+=1
        assert clear>=120,(clear,solid)
        assert solid>=70,(clear,solid)
        stairs=sorted([o for o in meshes if o.name.startswith('Steel stair tread')],key=lambda o:o.location.z)
        assert len(stairs)==24
        top=max((stairs[-1].matrix_world@Vector(c)).z for c in stairs[-1].bound_box)
        deck=col.objects['Catwalk deck'];deck_top=max((deck.matrix_world@Vector(c)).z for c in deck.bound_box)
        assert abs(top-deck_top)<.001,(top,deck_top)
        assert abs(stairs[-1].location.y+.29/2-(-3))<.02,'Stairs must reach the catwalk edge'
        # Ray down at office/walkway sample positions must hit their decks near 4.2m.
        for x,y in ((5,12),(10,16),(9.8,0),(9.8,8),(4,9.8)):
            hit=tree.ray_cast(Vector((x,y,4.35)),Vector((0,0,-1)),.30)[0]
            assert hit is not None and abs(hit.z-4.2)<.015,(x,y,hit)
        print('WAREHOUSE STRUCTURE PASS',clear,'real broken/missing window openings;',solid,'intact panes; stair/deck continuity',flush=True)
assembly=ROOT/'Models/Interiors/DilapidatedWarehouse'
info=json.loads((assembly/'assembly_manifest.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(ROOT/info['native']))
instances=bpy.data.collections['ASSEMBLY | linked architecture and independent props'].objects
assert len(instances)==17
for instance in instances:
    assert instance.instance_collection and instance.instance_collection.library
    assert instance.instance_collection.library.filepath.startswith('//')
    assert Path(bpy.path.abspath(instance.instance_collection.library.filepath)).exists()
    assert not instance.hide_render
    record=next(r for r in info['instances'] if r['name']==instance.name)
    assert (instance.location-Vector(record['position_m'])).length<.0001
    assert abs(instance.rotation_euler.z-math.radians(record['rotation_z_degrees']))<.0001


def world_bounds(instance,objects):
    points=[instance.matrix_world@obj.matrix_world@Vector(c) for obj in objects for c in obj.bound_box]
    return (Vector([min(p[i] for p in points) for i in range(3)]),
            Vector([max(p[i] for p in points) for i in range(3)]))


bpy.context.view_layer.update()
desk=instances['OfficeDesk 1']
stationery=[o for o in desk.instance_collection.objects if o.type=='MESH' and
            o.name.startswith(('Filing tray','Pencil cup','Closed logbook'))]
for key in ('LandlinePhone','PileOfMail'):
    instance=instances[key]
    low,high=world_bounds(instance,[o for o in instance.instance_collection.objects if o.type=='MESH'])
    for fixed in stationery:
        a,b=world_bounds(desk,[fixed])
        overlaps=all(high[i]>a[i]+.002 and b[i]>low[i]+.002 for i in range(3))
        assert not overlaps,(key,'intersects desktop stationery',fixed.name)
print('WAREHOUSE OFFICE PASS: instance transforms match manifest; phone/mail clear of fixed stationery',flush=True)
for obj in bpy.data.collections['ARCHITECTURE | dilapidated warehouse'].objects:
    assert not obj.hide_render
scene=bpy.context.scene
assert scene.camera.name=='01 | production hall'
assert scene.render.resolution_x==1800 and scene.render.resolution_y==1200
print('WAREHOUSE LINKED ASSEMBLY PASS: 17 relative collection instances; complete shell; final camera',flush=True)
