"""Validate generated GLB geometry, articulated nodes and external PBR maps."""
import json, struct
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
NAMES = 'drain fill winch_a winch_b bell brake wind release fuse_box power_switch laundry_cart spool_carrier pressure_plate steam_pipe last_bell exit_workshop exit_laundry exit_vault exit_clocktower'.split()
PIVOTS = dict(drain=['Rotor'],fill=['Lever','Needle'],winch_a=['Rotor'],winch_b=['Rotor'],bell=['Bell'],brake=['Lever','Needle'],wind=['Rotor'],release=['Lever'],fuse_box=['Fuse'],power_switch=['Lever'],pressure_plate=['Deck'],steam_pipe=['Needle'],last_bell=['Bell','Hammer'])
def check():
    for name in NAMES:
        p = ROOT/'assets/models/props'/f'{name}.glb'
        assert p.exists(), f'Missing {p}'
        data=p.read_bytes(); size,kind=struct.unpack_from('<II',data,12)
        doc=json.loads(data[20:20+size]); nodes={n.get('name'):n for n in doc['nodes']}
        for pivot in PIVOTS.get(name,[]):
            assert pivot in nodes and nodes[pivot].get('children'), (name,pivot)
        tris=sum(doc['accessors'][p['indices']]['count']//3 for m in doc['meshes'] for p in m['primitives'])
        assert tris <= (25000 if name.startswith('exit_') or name=='last_bell' else 12000),(name,tris)
        for im in doc.get('images',[]):
            assert 'uri' in im and (p.parent/im['uri']).exists(),(name,im)
        for material in doc['materials']:
            pbr=material['pbrMetallicRoughness']
            assert 'baseColorFactor' in pbr and 'baseColorTexture' in pbr and 'normalTexture' in material,(name,material['name'])
            image=doc['images'][doc['textures'][pbr['metallicRoughnessTexture']['index']]['source']]
            assert '_orm_2k.png' in image['uri'],(name,image)
        assert (ROOT/'assets/sources/props'/f'{name}.blend').exists()
        print(f'{name}: {tris} triangles, articulated nodes valid')
    for family in ['metal','wood','cloth']:
        for channel in ['albedo','normal','roughness','metallic']:
            p=ROOT/'assets/textures/props'/f'{family}_{channel}_2k.png'
            data=p.read_bytes(); assert struct.unpack_from('>II',data,16)==(2048,2048),p
    print('PASS: all 19 mechanical assets and 12 shared 2K maps')
    reports=json.loads((ROOT/'assets/sources/props/measurements.json').read_text())
    for name,r in reports.items():
        w,h,d=r['godot_size']
        if name in ['laundry_cart','spool_carrier']:assert w<=1 and h<=1.05 and d<=.95,(name,w,h,d)
        elif name=='pressure_plate':assert w<=1.31 and h<=.13 and d<=1.31
        elif name=='steam_pipe':assert w<=.5 and h<=1.2
        elif name=='last_bell':assert w<=3.3 and h<=2.9 and r['blender_max'][2]<.01
        elif name.startswith('exit_'):assert w<=4 and d<=1.5,(name,w,d)
        else:assert .65<=w<=.95 and 1.25<=h<=1.6 and .4<=d<=.7,(name,w,h,d)
    try: import bpy
    except ImportError:return
    from mathutils import Vector
    for name in NAMES:
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
        bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/props'/f'{name}.glb'))
        for pivot in PIVOTS.get(name,[]):assert bpy.data.objects.get(pivot) and bpy.data.objects[pivot].children,(name,pivot)
        points=[o.matrix_world@Vector(v) for o in bpy.context.scene.objects if o.type=='MESH' for v in o.bound_box]
        sizes=[max(v[i] for v in points)-min(v[i] for v in points) for i in [0,2,1]]
        assert all(abs(a-b)<.005 for a,b in zip(sizes,reports[name]['godot_size'])),(name,sizes)
    print('PASS: Blender reimported all 19 GLBs; pivots and world bounds match')
if __name__=='__main__': check()
