import os
import bpy,sys,math,json
from pathlib import Path
R=Path(__file__).resolve().parents[3];sys.path.insert(0,str(R/'tools'))
import create_characters_v2 as c
bpy.ops.wm.open_mainfile(filepath=str(R/'assets/sources/doll.blend'))
arm=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
# Exact authored skeleton retained. No existing mesh, material, rig or clip is overwritten.
original_actions=[a.name for a in bpy.data.actions]
# Repair the sewn cloth patches, not the correctly bound hands. The original
# generator gave them separate approximate positions/weights, which floated
# in front of the cloak and read as extra hands when the arms were raised.
from mathutils import Vector
from mathutils.bvhtree import BVHTree
cloak=bpy.data.objects['Cloak_Main_Folded']
bvh=BVHTree.FromPolygons([v.co for v in cloak.data.vertices],[list(p.vertices) for p in cloak.data.polygons])
patch_material=bpy.data.materials.new('ExpansionMendedCloth');patch_material.use_nodes=True;patch_material.node_tree.nodes.clear()
bs=patch_material.node_tree.nodes.new('ShaderNodeBsdfPrincipled');out=patch_material.node_tree.nodes.new('ShaderNodeOutputMaterial');patch_material.node_tree.links.new(bs.outputs[0],out.inputs['Surface'])
bs.inputs['Base Color'].default_value=(.022,.065,.047,1);bs.inputs['Roughness'].default_value=.92
repaired=[]
for o in bpy.context.scene.objects:
    if not (o.name.startswith('Sewn_Patch_') or o.name.startswith('Patch_')):continue
    if o.name.startswith('Sewn_Patch_'):
        # A fine surface grid follows folds; projecting a solid eight-vertex box
        # would collapse its depth and leave intersecting pale triangles.
        xmin=min(v.co.x for v in o.data.vertices);xmax=max(v.co.x for v in o.data.vertices);zmin=min(v.co.z for v in o.data.vertices);zmax=max(v.co.z for v in o.data.vertices)
        verts=[(xmin+(xmax-xmin)*x/6,0,zmin+(zmax-zmin)*z/6) for z in range(7) for x in range(7)]
        faces=[(z*7+x,z*7+x+1,(z+1)*7+x+1,(z+1)*7+x) for z in range(6) for x in range(6)]
        mesh=bpy.data.meshes.new(o.name+'ConformingMesh');mesh.from_pydata(verts,[],faces);mesh.update();o.data=mesh;o.data.materials.append(patch_material)
        for poly in mesh.polygons:poly.use_smooth=True
    for group in list(o.vertex_groups):o.vertex_groups.remove(group)
    for v in o.data.vertices:
        hit,normal,face,distance=bvh.ray_cast(Vector((v.co.x,-2,v.co.z)),Vector((0,1,0)))
        if hit is None:hit,normal,face,distance=bvh.find_nearest(v.co)
        v.co=hit+normal*(.012 if o.name.startswith('Sewn_Patch_') else .016)
        # Interpolate the exact nearby cloak vertex weights on the hit polygon.
        weights={};norm=0
        for index in cloak.data.polygons[face].vertices:
            cv=cloak.data.vertices[index];factor=1/max((cv.co-hit).length,1e-5)**2;norm+=factor
            for g in cv.groups:
                name=cloak.vertex_groups[g.group].name;weights[name]=weights.get(name,0)+g.weight*factor
        for name,weight in weights.items():
            group=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);group.add([v.index],weight/norm,'REPLACE')
    repaired.append(o.name)
print('REPAIRED_CLOTH_PATCHES',repaired)
clips=[]
for name in ['carry_idle','carry_walk','pull','climb']:
    keys=[]
    for frame,phase in [(1,0),(9,math.pi/2),(17,math.pi),(25,math.pi*1.5),(33,math.tau)]:
        s=0 if name=='carry_idle' else math.sin(phase);pose={}
        for side,sign in [('L',1),('R',-1)]:
            pose['UpperArm.'+side]=c.P(((-52 if name.startswith('carry') else -70 if name=='pull' else -130)+sign*s*(5 if name!='climb' else 22),0,sign*(-12)))
            pose['Forearm.'+side]=c.P((-25 if name.startswith('carry') else -15 if name=='pull' else -35,0,0))
            pose['Thigh.'+side]=c.P((sign*s*(12 if name.startswith('carry') else 20 if name=='pull' else 40),0,0))
            pose['Shin.'+side]=c.P((max(0,-sign*s)*(15 if name!='climb' else 55),0,0))
        pose['Spine']=c.P((-7 if name.startswith('carry') else 13 if name=='pull' else -4,0,0));keys.append((frame,pose))
    clips.append((name,33,True,keys))
c.create_actions(arm,clips)
bpy.context.scene.render.fps=30
def save_portable_source(path):
    """Write source textures relative to the destination blend directory."""
    for image in bpy.data.images:
        if image.source == 'FILE' and image.filepath:
            absolute = bpy.path.abspath(image.filepath, library=image.library)
            image.filepath = '//' + os.path.relpath(absolute, path.parent)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(path), relative_remap=False)

save_portable_source(R/'assets/sources/expansion/doll_interactions.blend')
bpy.ops.export_scene.gltf(filepath=str(R/'assets/models/expansion/doll_interactions.glb'),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_skins=True)
assert all(bpy.data.actions.get(n) for n in original_actions)
print('ANIMATION_LIBRARY_DONE',original_actions)
