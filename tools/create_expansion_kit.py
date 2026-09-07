"""Original modular Midnight Workshop kit. Blender 5.2.1; no character regeneration.
Run: blender -b --python tools/create_expansion_kit.py [-- --no-render --only ladder]
Blender Z-up/-Y-front becomes Godot Y-up/+Z-front. All source feet at zero.
"""
import os
import bpy, math, json, struct, sys, hashlib
from pathlib import Path
from mathutils import Vector
import numpy as np
R=Path(__file__).resolve().parents[1]
M=R/'assets/models/expansion'; S=R/'assets/sources/expansion'; T=R/'assets/textures/expansion'; P=S/'previews'
for d in [M,S,T,P]: d.mkdir(parents=True,exist_ok=True)
(S/'.gdignore').touch()
# Reuse the project's original modeling primitives without executing its generator.
helper=(R/'tools/create_mechanical_props.py').read_text()
ns={'__file__':str(R/'tools/create_mechanical_props.py'),'__name__':'expansion_primitives'}
exec(helper[:helper.index('textures()\nmaterials={}')].replace("/props'","/expansion'"),ns)
# Only original 2K metal/cloth maps are copied; real CC0 wood drives new wooden surfaces.
import shutil
for family in ['metal','cloth']:
    for ch in ['albedo','normal','roughness','metallic','orm']:
        shutil.copyfile(R/f'assets/textures/props/{family}_{ch}_2k.png',T/f'{family}_{ch}_2k.png')
materials={}
def material(name,color,metal=0,wood=False):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.node_tree.nodes.clear();bs=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled');out=m.node_tree.nodes.new('ShaderNodeOutputMaterial');m.node_tree.links.new(bs.outputs[0],out.inputs['Surface']);bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=.58
    for ch,socket in [('albedo','Base Color'),('roughness','Roughness'),('normal','Normal')]:
        path=T/({'albedo':'weathered_planks_diff_2k.jpg','roughness':'weathered_planks_rough_2k.jpg','normal':'weathered_planks_nor_gl_2k.jpg'}[ch] if wood else f'metal_{ch}_2k.png')
        tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path),check_existing=True)
        if ch!='albedo':tex.image.colorspace_settings.name='Non-Color'
        if ch=='albedo' and not wood:
            mix=m.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*color,1);m.node_tree.links.new(tex.outputs[0],mix.inputs[1]);m.node_tree.links.new(mix.outputs[0],bs.inputs[socket])
        elif ch=='normal':
            normal=m.node_tree.nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.25;m.node_tree.links.new(tex.outputs[0],normal.inputs['Color']);m.node_tree.links.new(normal.outputs[0],bs.inputs[socket])
        else:m.node_tree.links.new(tex.outputs[0],bs.inputs[socket])
    materials[name]=m
B='Brass';I='Iron';E='Teal';W='Wood';IV='Ivory';C='Rope'
for name,color,metal,wood in [(B,(.68,.43,.14),.78,False),(I,(.09,.12,.12),.85,False),(E,(.06,.42,.35),.28,False),(W,(.5,.3,.12),0,True),(IV,(.82,.73,.50),.05,False),(C,(.44,.28,.13),0,False)]:material(name,color,metal,wood)
root=None
start=helper.index('def parent(');end=helper.index('def stand(')
exec(helper[start:end],globals())
TAU=math.tau
def clear(name):
    global root
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
def bolts(x,y,z,w,h):
    for a in [-1,1]:
        for b in [-1,1]:cyl('Hex bolt',(x+a*w/2,y,z+b*h/2),.025,.022,B,axis='Y',verts=6)
def frame(w,h,d):
    for x in [-w/2+.09,w/2-.09]:box('Cast upright',(x,0,h/2),(.18,d,h),E)
    for z in [.08,h-.08]:box('Riveted crossbeam',(0,0,z),(w,d,.16),I);bolts(0,-d/2-.012,z,w-.13,.06)
def rotor(name,z,r=.4,p=None):
    q=p or pivot(name,(0,0,z));ring('Rim',(0,0,z),r,.05,B,q)
    for a in np.linspace(0,TAU,6,endpoint=False):line('Spoke',[(0,0,z),(r*math.cos(a),0,z+r*math.sin(a))],.035,E,q)
    cyl('Hub',(0,0,z),.12,.25,I,q,'Y');return q
def gear(z=.35,r=.3,p=None):
    q=rotor('Rotor',z,r*.82,p)
    for a in np.linspace(0,TAU,16,endpoint=False):
        o=box('Machined tooth',(r*math.cos(a),0,z+r*math.sin(a)),(.09,.18,.09),B,q,.009);o.rotation_euler[1]=-a
    return q
def build(n):
    if n=='arch':
        for x in [-1.83,1.83]:box('Fluted pier',(x,0,2),(.34,.6,4),E);box('Plinth',(x,0,.14),(.5,.65,.28),I)
        for a in np.linspace(0,math.pi,19):
            o=box('Segmented voussoir',(1.83*math.cos(a),0,3.0+1.83*math.sin(a)),(.34,.60,.40),E);o.rotation_euler[1]=-a
        line('Inner brass molding',[(1.63*math.cos(a),-.325,3+1.63*math.sin(a)) for a in np.linspace(0,math.pi,60)],.035,B)
    elif n=='wall_panel':
        frame(4,5,.23)
        for x in np.linspace(-1.65,1.65,8):box('Recessed timber panel',(x,.03,2.5),(.45,.15,4.65),W)
        for z in [1.25,3.75]:box('Rail',(0,-.12,z),(4,.12,.12),B)
    elif n=='floor_panel':
        for x in np.linspace(-1.75,1.75,8):box('Floor board',(x,0,.10),(.48,3,.20),W,None,.018)
        for x in [-1.8,1.8]:
            for y in [-1.35,1.35]:cyl('Nail',(x,y,.203),.023,.008,I)
    elif n=='ladder':
        # Keep hand support above the 3.2 m landing, with the feet at zero.
        for x in [-.34,.34]:box('Wood rail',(x,0,2.275),(.12,.16,4.55),W)
        for step in range(15):cyl('Worn rung',(0,-.03,.25+step*.30),.045,.72,B,axis='X')
        for z in [.15,2.8,4.25]:
            for x in [-.34,.34]:box('Wall bracket',(x,.10,z),(.2,.35,.08),I)
    elif n in ['cargo_basket','floating_crate']:
        w,d,h=(2,1.6,1.3) if n=='cargo_basket' else (.95,.95,.95)
        for x in np.linspace(-w/2+.1,w/2-.1,6):box('Base plank',(x,0,.08),(w/6-.02,d,.16),W)
        for x in [-w/2+.06,w/2-.06]:
            for y in [-d/2+.06,d/2-.06]:box('Corner post',(x,y,h/2),(.12,.12,h),I)
        for z in np.linspace(.22,h-.08,5):
            for y in [-d/2,d/2]:box('Slatted side',(0,y,float(z)),(w,.08,.15),W)
            for x in [-w/2,w/2]:box('Slatted end',(x,0,float(z)),(.08,d,.15),W)
        for x in [-w*.32,w*.32]:
            for y in [-d/2-.05,d/2+.05]:box('Iron strap',(x,y,h/2),(.065,.025,h),E)
    elif n=='gate':
        q=pivot('Gate');frame(2.8,3,.3)
        for x in np.linspace(-1.13,1.13,9):box('Vertical gate bar',(x,0,1.5),(.065,.12,2.7),B,q)
        for z in [.6,2.4]:box('Gate crossbar',(0,0,z),(2.55,.16,.1),I,q)
    elif n=='conveyor':
        for y in [-.75,.75]:box('Channel rail',(0,y,.47),(4,.12,.3),E)
        for x in [-1.7,1.7]:
            for y in [-.65,.65]:box('Leg',(x,y,.22),(.15,.15,.44),I)
        q=pivot('Rollers',(0,0,.47))
        for x in np.linspace(-1.82,1.82,18):cyl('Roller',(float(x),0,.47),.11,1.4,I,q,'Y')
        for x in [-1.85,1.85]:cyl('Bearing',(x,-.84,.47),.1,.12,B,axis='Y')
    elif n=='press':
        frame(2.4,3.4,1.4);box('Anvil',(0,0,.3),(1.9,1.5,.6),I)
        q=pivot('Ram',(0,0,2.3));box('Press head',(0,0,2.3),(1.8,1.3,.45),E,q)
        for x in [-.7,.7]:cyl('Hydraulic piston',(x,0,2.9),.09,.9,B,q)
        for x in np.linspace(-.7,.7,7):o=box('Hazard inset',(float(x),-.661,2.3),(.08,.016,.4),IV,q);o.rotation_euler[1]=-.4
    elif n=='generator':
        box('Cast bed',(0,0,.12),(1.8,1.2,.24),I);cyl('Motor casing',(0,0,.78),.6,1.35,E,axis='X')
        for x in np.linspace(-.6,.6,12):line('Cooling fin',[(float(x),.61*math.cos(a),.78+.61*math.sin(a)) for a in np.linspace(0,TAU,40)],.023,I)
        q=pivot('Rotor',(.78,0,.78));cyl('Flywheel',(.78,0,.78),.48,.13,B,q,'X');box('Terminal box',(0,0,1.37),(.5,.5,.25),E)
    elif n in ['selector','control_pedestal','valve','winch','clutch']:
        box('Mounting foot',(0,0,.08),(.8,.6,.16),I);box('Pedestal',(0,.05,.58),(.24,.25,1),E);box('Walnut backboard',(0,.08,.93),(.7,.12,.7),W)
        if n in ['valve','winch','clutch']:q=rotor('Rotor',.85,.30)
        else:
            q=pivot('Lever',(0,-.12,.85));line('Lever shaft',[(0,-.15,.85),(.18,-.25,1.2)],.035,B,q);ball('Wood handle',(.18,-.25,1.2),(.07,.06,.1),W,q)
            cyl('Dial',(0,-.01,1.12),.17,.10,IV,axis='Y')
        if n=='winch':
            for y in np.linspace(.1,.4,10):ring('Wound rope',(0,float(y),.85),.23,.025,C)
        if n=='clutch':
            for x in [-.25,.25]:cyl('Clutch plate',(x,.1,.85),.30,.10,B,q,'X')
    elif n=='tank':
        box('Tank bottom',(0,0,.12),(3,2,.24),I)
        for y in [-.94,.94]:box('Enamel tank wall',(0,y,1.4),(3,.12,2.4),E)
        for x in [-1.44,1.44]:box('Enamel end',(x,0,1.4),(.12,2,2.4),E)
        for z in [.3,1.4,2.55]:
            for y in [-1.015,1.015]:box('Tank binding',(0,y,z),(3.05,.045,.07),B)
        line('Overflow elbow',[(1.4,0,2.45),(1.65,0,2.45),(1.65,0,1.5)],.08,I)
    elif n=='rack':
        frame(2.6,3.4,.75)
        for z in [.2,1.2,2.2,3.2]:box('Timber shelf',(0,0,z),(2.4,.8,.13),W)
        line('Diagonal brace',[(-1.2,.42,.2),(1.2,.42,3.2)],.03,B)
    elif n=='gear':gear()
    elif n=='wheel':rotor('Rotor',.65,.59)
    elif n=='pendulum':
        q=pivot('Pendulum',(0,0,2.9));line('Pendulum rod',[(0,0,2.9),(0,0,.42)],.038,B,q);cyl('Pendulum bob',(0,0,.42),.38,.2,B,q,'Y');cyl('Suspension pin',(0,0,2.9),.1,.28,I)
    elif n=='weight':
        box('Cast counterweight',(0,0,.33),(.65,.6,.66),I,bevel=.06);ring('Lifting eye',(0,0,.73),.10,.035,B)
        for z in [.17,.46]:box('Brass band',(0,-.31,z),(.67,.025,.07),B)
    elif n=='fuse':
        cyl('Ceramic fuse',(0,0,.25),.085,.36,IV)
        for z in [.055,.445]:cyl('Copper endcap',(0,0,z),.10,.11,B)
        line('Conductive spine',[(0,-.088,.1),(0,-.088,.4)],.012,B)
    elif n=='lamp':
        cyl('Lamp base',(0,0,.05),.22,.1,I);cyl('Glass glow core',(0,0,.36),.13,.44,IV)
        for a in np.linspace(0,TAU,6,endpoint=False):line('Protective cage',[(.19*math.cos(a),.19*math.sin(a),.1),(.19*math.cos(a),.19*math.sin(a),.62),(0,0,.72)],.014,B)
        ring('Handle',(0,0,.71),.08,.02,I)
def externalize(path):
    raw=path.read_bytes();ln=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+ln]);payload=raw[28+ln:];views=doc['bufferViews'];out=bytearray();mapping={}
    image_views={im['bufferView'] for im in doc.get('images',[]) if 'bufferView' in im}
    for i,v in enumerate(views):
        if i in image_views:continue
        while len(out)%4:out.append(0)
        mapping[i]=len(mapping);start=v.get('byteOffset',0);new=dict(v);new['byteOffset']=len(out);out.extend(payload[start:start+v['byteLength']]);views[i]=new
    for im in doc.get('images',[]):
        idx=im.pop('bufferView');mime=im.pop('mimeType');v=doc['bufferViews'][idx];data=payload[v.get('byteOffset',0):v.get('byteOffset',0)+v['byteLength']]
        ext='jpg' if mime=='image/jpeg' else 'png';name=im.get('name','texture')+'.'+ext;dest=T/name
        if not dest.exists():dest.write_bytes(data)
        im['uri']='../../textures/expansion/'+name
    colors={'Brass':(.68,.43,.14),'Iron':(.09,.12,.12),'Teal':(.06,.42,.35),'Ivory':(.82,.73,.50),'Rope':(.44,.28,.13)}
    for material in doc.get('materials',[]):
        if material['name'] in colors:material['pbrMetallicRoughness']['baseColorFactor']=[*colors[material['name']],1]
    doc['bufferViews']=[views[i] for i in sorted(mapping)]
    for a in doc['accessors']:
        if 'bufferView' in a:a['bufferView']=mapping[a['bufferView']]
    doc['buffers'][0]['byteLength']=len(out)
    while len(out)%4:out.append(0)
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,28+len(js)+len(out))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(out),0x004e4942)+out)
NAMES='arch wall_panel floor_panel ladder cargo_basket gate conveyor press generator selector tank valve floating_crate rack winch gear clutch pendulum weight fuse wheel control_pedestal lamp'.split()
def save_portable_source(path):
    """Write source textures relative to the destination blend directory."""
    for image in bpy.data.images:
        if image.source == 'FILE' and image.filepath:
            absolute = bpy.path.abspath(image.filepath, library=image.library)
            image.filepath = '//' + os.path.relpath(absolute, path.parent)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(path), relative_remap=False)

def main():
    names=NAMES
    if '--only' in sys.argv:
        names=sys.argv[sys.argv.index('--only')+1].split(',')
        unknown=set(names)-set(NAMES)
        if unknown:raise ValueError(f'Unknown assets: {sorted(unknown)}')
    measurements=S/'measurements.json'
    reports=json.loads(measurements.read_text()) if measurements.exists() else {}
    for name in names:
        clear(name);build(name)
        for o in list(bpy.context.scene.objects):
            if o.type!='MESH':continue
            bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
        bpy.context.view_layer.update();pts=[o.matrix_world@Vector(v) for o in bpy.context.scene.objects if o.type=='MESH' for v in o.bound_box];lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
        # Adjust feet once on the complete hierarchy, preserving local articulation.
        root.location.z-=lo.z;bpy.context.view_layer.update();hi.z-=lo.z;lo.z=0
        pivots=[o.name for o in bpy.context.scene.objects if o.type=='EMPTY' and o!=root]
        reports[name]={'godot_size':[round(hi.x-lo.x,4),round(hi.z,4),round(hi.y-lo.y,4)],'pivots':pivots,'triangles':sum(len(p.vertices)-2 for o in bpy.context.scene.objects if o.type=='MESH' for p in o.data.polygons)}
        save_portable_source(S/f'{name}.blend');bpy.ops.export_scene.gltf(filepath=str(M/f'{name}.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False);externalize(M/f'{name}.glb')
        if '--no-render' not in sys.argv:
            ns.update({'bpy':bpy,'Vector':Vector,'P':P});exec(helper[helper.index('def render('):helper.index('def main():')],ns);ns['render'](name,(lo,hi))
        print('EXPORTED',name,reports[name],flush=True)
    (S/'measurements.json').write_text(json.dumps(reports,indent=2)+'\n')
    # Independent roundtrip: every model imports with nonempty mesh, UVs and all pivots.
    for name in names:
        bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);bpy.ops.import_scene.gltf(filepath=str(M/f'{name}.glb'))
        meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert meshes and all(o.data.uv_layers for o in meshes),name
        assert all(any(o.name==p for o in bpy.context.scene.objects) for p in reports[name]['pivots']),name
        reports[name]['roundtrip_verified']=True
    (S/'measurements.json').write_text(json.dumps(reports,indent=2)+'\n')
    if names!=NAMES:
        print('VERIFIED',len(names),'Blender GLB roundtrips',flush=True)
        return
    sheet=np.full((5*256,5*256,3),28,dtype=np.uint8)
    for i,name in enumerate(NAMES):
        path=P/f'{name}_threequarter.png'
        if not path.exists():continue
        im=bpy.data.images.load(str(path),check_existing=False);im.scale(256,256);pixels=np.array(im.pixels[:]).reshape(256,256,4)[::-1,:,:3];sheet[i//5*256:i//5*256+256,i%5*256:i%5*256+256]=np.clip(pixels*255,0,255).astype('uint8');bpy.data.images.remove(im)
    ns['png'](P/'contactsheet.png',sheet)
    print('VERIFIED',len(NAMES),'Blender GLB roundtrips',flush=True)
if __name__=='__main__':main()
