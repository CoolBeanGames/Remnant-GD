"""Read-only checks for the clipping atlas, UVs and real daylight openings."""
from pathlib import Path
import json

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
ROOM=ROOT/'Models/Architecture/StudioApartment'
bpy.ops.wm.open_mainfile(filepath=str(ROOM/'Source/studio_apartment.blend'))
collection=bpy.data.collections['APARTMENT | permanent architecture']
paper=[o for o in collection.objects if o.get('window_covering')]
assert len(paper)==48
assert all(o.data.uv_layers and o.get('print_faces_room') for o in paper)
assert all(all(0 <= v <= 1 for v in o['atlas_crop']) for o in paper)
atlas=[n.image for m in bpy.data.materials if m.name=='Newspaper / faded photographic clippings' for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'scan_atlas' in n.image.name]
assert len(atlas)==1 and atlas[0].packed_file
vertices,faces=[],[]
graph=bpy.context.evaluated_depsgraph_get()
for obj in paper:
    evaluated=obj.evaluated_get(graph)
    mesh=evaluated.to_mesh()
    base=len(vertices)
    vertices.extend(evaluated.matrix_world @ v.co for v in mesh.vertices)
    faces.extend(tuple(base+i for i in p.vertices) for p in mesh.polygons)
    evaluated.to_mesh_clear()
tree=BVHTree.FromPolygons(vertices,faces)
openings={'north':[(.11,.145,.17,.32),(.285,.33,.64,.71),(.475,.493,.08,.34),(.478,.501,.47,.73),(.70,.738,.31,.40),(.85,.884,.80,.87)],
          'east':[(.16,.19,.12,.39),(.38,.435,.57,.65),(.61,.632,.26,.55),(.81,.858,.74,.82)]}
for side,masks in openings.items():
    start,width,bottom,height=(-.425,3.65,.74,1.76) if side=='north' else (-.68,2.46,.92,1.58)
    for a,b,c,d in masks:
        along=start+(a+b)/2*width
        z=bottom+(c+d)/2*height
        origin=Vector((along,0,z) if side=='north' else (0,along,z))
        direction=Vector((0,1,0) if side=='north' else (1,0,0))
        assert tree.ray_cast(origin,direction,5)[0] is None,('Blocked daylight opening',side,(a,b,c,d))
info=json.loads((ROOM/'asset_manifest.json').read_text())
assert info['window_coverings']['sheets']==48
assert len([o for o in collection.objects if o.type=='MESH'])==info['architecture_meshes']
print('NEWSPAPER PASS: 48 packed/UV-mapped independent clippings; 10 geometric daylight rays clear',flush=True)
