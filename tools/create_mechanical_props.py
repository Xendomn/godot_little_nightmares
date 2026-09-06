"""Original Clockwork Lullaby prop workshop. Blender 5.x, no external dependencies.
blender -b --python tools/create_mechanical_props.py [-- --heroes / --no-render]
Geometry uses Blender Z up/-Y front; GLB export converts to Godot Y up/+Z front.
"""
import bpy, math, json, struct, sys, zlib
import numpy as np
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
M=R/'assets/models/props'; S=R/'assets/sources/props'; T=R/'assets/textures/props'; P=S/'previews'
for d in [M,S,T,P]: d.mkdir(parents=True,exist_ok=True)
TAU=math.tau
def png(path,a):
    a=np.clip(a,0,255).astype('uint8'); h,w,c=a.shape
    def chunk(k,v):return struct.pack('>I',len(v))+k+v+struct.pack('>I',zlib.crc32(k+v)&0xffffffff)
    raw=b''.join(b'\0'+row.tobytes() for row in a)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,6))+chunk(b'IEND',b''))
def textures():
    y,x=np.mgrid[:2048,:2048]; rng=np.random.default_rng(109)
    for family in ['metal','wood','cloth']:
        if (T/f'{family}_normal_2k.png').exists() and '--rebuild-textures' not in sys.argv:continue
        noise=rng.random(x.shape)
        if family=='wood':
            grain=np.sin(x*.18+np.sin(y*.004)*7+np.sin(y*.03))*.5+.5
            h=grain*.10+noise*.045; color=np.array([119,82,45]); rough=.73; metal=0
        elif family=='cloth':
            h=(np.sin(x*1.1)*np.sin(y*1.1)+1)*.1+noise*.05; color=np.array([180,179,150]);rough=.9;metal=0
        else:
            corrosion=(np.sin(x*.0123+y*.007)+np.cos(y*.023-x*.014)+np.sin(x*.043+y*.027)) / 3
            h=noise*.035+np.maximum(corrosion-.55,0)*.15
            color=np.array([126,140,128]);rough=.54;metal=1
        albedo=color[None,None,:]*(.72+h[:,:,None])
        if family=='metal':albedo+=((corrosion>.55)[:,:,None])*np.array([3,-5,-9])
        dy,dx=np.gradient(h); normal=np.stack((128-dx*120,128-dy*120,np.full_like(h,250)),2)
        for channel,a in dict(albedo=albedo,normal=normal,roughness=np.repeat(np.clip(rough+h*.4,0,1)[:,:,None]*255,3,2),metallic=np.full((2048,2048,3),metal*255),orm=np.stack((np.full_like(h,255),np.clip(rough+h*.4,0,1)*255,np.full_like(h,metal*255)),2)).items():png(T/f'{family}_{channel}_2k.png',a)
textures()
materials={}
material_specs={}
def mat(name,family,color,metallic=None):
    material_specs[name]=(family,color,metallic)
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
    n=m.node_tree.nodes;l=m.node_tree.links; bs=n.get('Principled BSDF')
    for channel in ['albedo','normal','roughness','metallic']:
        tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(T/f'{family}_{channel}_2k.png'),check_existing=True)
        if channel!='albedo':tex.image.colorspace_settings.name='Non-Color'
        if channel=='albedo':
            mix=n.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*color,1);l.new(tex.outputs['Color'],mix.inputs[1]);l.new(mix.outputs[0],bs.inputs['Base Color'])
            # glTF supports a texture multiplied by a constant via a multiply mix.
        elif channel=='normal':
            normal=n.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.32;l.new(tex.outputs[0],normal.inputs['Color']);l.new(normal.outputs[0],bs.inputs['Normal'])
        elif channel=='metallic' and metallic is not None:bs.inputs['Metallic'].default_value=metallic
        else:l.new(tex.outputs[0],bs.inputs[channel.title()])
    materials[name]=m;return m
mat('Oxidized brass','metal',(.64,.41,.12),.8);mat('Dark iron','metal',(.095,.12,.115),.88);mat('Chipped teal enamel','metal',(.055,.32,.28),.3);mat('Copper contacts','metal',(.68,.22,.10),.9);mat('Warm ivory enamel','metal',(.9,.8,.58),.12);mat('Worn walnut','wood',(.58,.37,.19));mat('Rope and wicker','cloth',(.65,.43,.21));mat('Folded linen','cloth',(.57,.68,.62));mat('Water','metal',(.06,.4,.52),.15)
B='Oxidized brass';I='Dark iron';E='Chipped teal enamel';W='Worn walnut';C='Rope and wicker';IV='Warm ivory enamel'; root=None
def parent(o,p):
    bpy.context.view_layer.update()
    matrix=o.matrix_world.copy();o.parent=p or root;o.matrix_world=matrix;return o
def finish(o,name,material,p=None,bevel=0):
    o.name=name;o.data.materials.append(materials[material]);parent(o,p)
    if bevel:
        mod=o.modifiers.new('soft worn edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    if o.type=='MESH':
        for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
    return o
def box(n,loc,size,ma=I,p=None,bevel=.018):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,n,ma,p,bevel)
def cyl(n,loc,r,depth,ma=B,p=None,axis='Z',verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc);o=bpy.context.object
    if axis=='Y':o.rotation_euler[0]=math.pi/2
    elif axis=='X':o.rotation_euler[1]=math.pi/2
    return finish(o,n,ma,p,.006 if r>.03 else 0)
def ball(n,loc,size,ma=B,p=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=loc);o=bpy.context.object;o.scale=size;return finish(o,n,ma,p)
def line(n,points,r=.015,ma=B,p=None):
    cu=bpy.data.curves.new(n,'CURVE');cu.dimensions='3D';cu.resolution_u=1;cu.bevel_depth=r;cu.bevel_resolution=1
    sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
    for v,co in zip(sp.points,points):v.co=(*co,1)
    o=bpy.data.objects.new(n,cu);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o=bpy.context.object;o.select_set(False);return finish(o,n,ma,p)
def ring(n,loc,r,t=.018,ma=B,p=None,axis='Y',steps=32):
    x,y,z=loc;return line(n,[(x+r*math.cos(i*TAU/steps),y if axis=='Y' else y+r*math.sin(i*TAU/steps),z+r*math.sin(i*TAU/steps) if axis=='Y' else z) for i in range(steps+1)],t,ma,p)
def pivot(name,loc=(0,0,0)):
    o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;parent(o,root);return o
def rivets(x,y,z,w,h):
    for xx in [-w/2,w/2]:
        for zz in [-h/2,h/2]:ball('domed rivet',(x+xx,y,z+zz),(.018,.011,.018),B)
def stand():
    box('splayed foot',(0,0,.065),(.7,.45,.13),I);box('curved enamel pedestal',(0,.065,.58),(.28,.23,1.0),E,bevel=.065)
    box('walnut mounting shield',(0,.06,1.01),(.61,.15,.72),W,bevel=.10);rivets(0,-.035,1.01,.46,.53)
def gauge(x=0,z=1.25):
    cyl('gauge housing',(x,-.065,z),.15,.10,B,axis='Y');cyl('porcelain dial',(x,-.12,z),.126,.015,IV,axis='Y')
    for a in np.linspace(-.7,3.8,9):
        line('dial engraved tick',[(x+.095*math.cos(a),-.135,z+.095*math.sin(a)),(x+.11*math.cos(a),-.135,z+.11*math.sin(a))],.004,I)
    p=pivot('Needle',(x,-.148,z));line('needle',[(x,-.15,z),(x-.077,-.15,z+.05)],.007,'Copper contacts',p);ball('needle pin',(x,-.15,z),(.017,.012,.017),B,p)
def lever(z=.82):
    p=pivot('Lever',(0,-.17,z));cyl('lever axle',(0,-.16,z),.065,.13,B,p,'Y');line('bent lever',[(0,-.22,z),(.12,-.23,z+.10),(.2,-.25,z+.28)],.023,I,p);ball('wood palm grip',(.2,-.25,z+.28),(.055,.046,.092),W,p);return p
def wheel(z=.85,r=.22):
    p=pivot('Rotor',(0,-.2,z));ring('scalloped valve wheel',(0,-.24,z),r,.03,B,p)
    for a in [0,TAU/3,TAU*2/3]:line('curved spoke',[(0,-.24,z),(r*.5*math.cos(a+.15),-.25,z+r*.5*math.sin(a+.15)),(r*math.cos(a),-.24,z+r*math.sin(a))],.018,B,p)
    cyl('wheel hub',(0,-.21,z),.063,.13,I,p,'Y');return p
def bell_shell(n,loc,r,h,p,ma=B):
    x,y,z=loc;profile=[(0,.12),(.12,.2),(.32,.29),(.60,.40),(.85,.62),(1,.96),(1.025,1),(.97,.86),(.82,.55),(.57,.33),(.3,.22),(.12,.14)]
    vs=[]
    for zz,rr in profile:
        for j in range(40):
            a=j*TAU/40;vs.append((x+r*rr*math.cos(a),y+r*rr*math.sin(a),z-zz*h))
    fs=[]
    for k in range(len(profile)-1):
        for j in range(40):a=k*40+j;b=k*40+(j+1)%40;fs.append((a,b,b+40,a+40))
    mesh=bpy.data.meshes.new(n);mesh.from_pydata(vs,[],fs);mesh.update();o=bpy.data.objects.new(n,mesh);bpy.context.collection.objects.link(o);finish(o,n,ma,p)
    ring('rolled bell lip',(x,y,z-h),r,.025*r/.25,ma,p,'Z');line('clapper stem',[(x,y,z-.15*h),(x,y,z-.96*h)],.025*r/.25,I,p);ball('clapper pear',(x,y,z-.96*h),(r*.16,r*.16,h*.12),I,p)
def mechanism(name):
    stand()
    if name=='drain':
        line('cast elbow pipe',[(-.26,.07,.16),(-.26,.07,.38),(0,.07,.53),(0,.07,.88),(.26,.07,1.02),(.26,.07,1.35)],.065,E)
        for z in [.25,1.28]:cyl('bolted flange',(-.26 if z<1 else .26,.07,z),.106,.046,I)
        wheel()
    elif name=='fill':
        gauge();lever()
        for x in [-.24,.24]:
            cyl('water level tube',(x,-.06,.68),.029,.52,IV);cyl('blue water column',(x,-.092,.57),.019,.26,'Water')
            for z in [.4,.95]:cyl('tube brass union',(x,-.06,z),.048,.04,B)
    elif name.startswith('winch'):
        p=wheel(.84,.21);cyl('rope drum',(0,.005,.84),.18,.28,W,axis='Y')
        for y in np.linspace(-.13,.14,12):ring('wound rope',(0,float(y),.84),.18,.013,C)
        for a in np.linspace(0,TAU,18,endpoint=False):
            o=box('ratchet tooth',(.2*math.cos(a),-.12,.84+.2*math.sin(a)),(.045,.065,.055),I,p,0);o.rotation_euler[1]=-a
        line('hanging rope',[(.16,.05,.86),(.26,.09,.48),(.24,.06,.17)],.015,C)
        cyl('wood crank grip',(.2,-.30,.84),.037,.16,W,p,'Y');box('ratchet pawl',(.2,-.13,1.04),(.14,.06,.04),B)
        if name=='winch_b':ring('upper pulley',(0,.035,1.28),.12,.03,I);line('overhead rope',[(.12,.02,.88),(.12,.02,1.28),(0,.02,1.4),(-.12,.02,1.28),(-.12,.02,.65)],.014,C)
    elif name=='bell':
        line('crooked bell bracket',[(0,.07,.95),(0,.07,1.39),(0,-.13,1.39)],.035,I)
        ring('suspension link',(0,-.14,1.325),.047,.012,B)
        p=pivot('Bell',(0,-.14,1.33));bell_shell('hollow handbell',(0,-.14,1.29),.22,.38,p);ring('pull ring',(0,-.2,.77),.057,.014,B,p);line('pull cord',[(0,-.16,.96),(0,-.2,.82)],.011,C,p)
    elif name=='brake':
        gauge();lever();cyl('brake drum',(0,-.1,.67),.20,.11,I,axis='Y');ring('brass brake band',(0,-.16,.67),.202,.025,B)
        box('brake pawl',(.17,-.23,.7),(.16,.07,.06),B);line('tension spring',[(.24+.016*math.cos(a),-.13,.45+a*.008) for a in np.linspace(0,TAU*4,64)],.008,I)
    elif name=='wind':
        p=wheel(.85,.20)
        line('exposed spiral mainspring',[(.012*a*math.cos(a),-.13,.85+.012*a*math.sin(a)) for a in np.linspace(1,TAU*3,130)],.014,I)
        cyl('wood winding handle',(.18,-.30,.85),.037,.16,W,p,'Y');box('spring brass cage',(0,.02,.84),(.50,.10,.53),B)
    elif name=='release':
        lever();box('hammer latch housing',(0,-.07,1.24),(.36,.22,.23),I)
        line('latch linkage',[(.1,-.24,.9),(.12,-.2,1.15),(0,-.22,1.22)],.02,B);ring('catch eye',(-.2,-.1,1.24),.065,.025,I)
        box('catch jaw',(-.13,-.13,1.24),(.21,.11,.045),B)
    elif name=='fuse_box':
        box('enamel fuse cabinet',(0,-.025,1.00),(.53,.19,.67),E,bevel=.07);box('dark cabinet recess',(0,-.13,1.0),(.41,.04,.51),I)
        p=pivot('Fuse',(0,-.19,1));cyl('ivory fuse barrel',(0,-.19,1),.055,.27,IV,p)
        for z in [.84,1.16]:box('copper fuse contact',(0,-.19,z),(.19,.08,.07),'Copper contacts');cyl('fuse brass cap',(0,-.19,z),.062,.045,B,p)
        for z in [.79,1.22]:cyl('cabinet hinge',(-.27,-.05,z),.035,.1,B)
        door=box('ajar fuse cabinet lid',(-.35,-.17,1),(.18,.035,.59),E);door.rotation_euler[2]=-.65
    elif name=='power_switch':
        box('porcelain switch bed',(0,-.08,1),(.37,.12,.53),IV,bevel=.06);p=lever(.8)
        for x in [-.09,.09]:
            for z in [.82,1.18]:box('fork copper contact',(x,-.19,z),(.065,.1,.08),'Copper contacts')
            line('knife contact blade',[(x,-.23,.8),(x+.12,-.26,1.1)],.018,'Copper contacts',p)
        line('insulated cable',[(-.18,.05,.19),(-.22,.04,.5),(-.15,.04,.78)],.019,I)
def cart(name):
    box('wood undercarriage',(0,0,.23),(.83,.72,.10),W)
    for x in [-.38,.38]:
        for y in [-.29,.29]:cyl('iron caster',(x,y,.13),.125,.06,I,axis='X');cyl('brass hub',(x*1.10,y,.13),.045,.065,B,axis='X')
    if name=='laundry_cart':
        for z in np.linspace(.32,.82,15):
            for y in [-.34,.34]:line('woven horizontal strand',[(-.4,y,float(z)),(.4,y,float(z))],.009,C)
            for x in [-.4,.4]:line('woven end strand',[(x,-.34,float(z)),(x,.34,float(z))],.009,C)
        for x in np.linspace(-.39,.39,18):
            for y in [-.34,.34]:line('basket vertical reed',[(float(x),y,.30),(float(x)+.008,y,.56),(float(x),y,.84)],.009,C)
        for y in np.linspace(-.33,.33,15):
            for x in [-.4,.4]:line('basket end reed',[(x,float(y),.30),(x,float(y)+.008,.55),(x,float(y),.84)],.009,C)
        for z in [.30,.84]:line('basket bound rim',[(-.42,-.36,z),(.42,-.36,z),(.42,.36,z),(-.42,.36,z),(-.42,-.36,z)],.025,W)
        for i in range(3):
            o=box('folded cloth',(0,.04,.63+i*.075),(.64-i*.05,.52,.09),'Folded linen',bevel=.035);o.rotation_euler[2]=(i-1)*.06
            line('stitched hem',[(-.27,-.22,.67+i*.075),(.27,-.22,.67+i*.075)],.005,C)
    else:
        for x in [-.34,.34]:box('spool A frame upright',(x,0,.54),(.075,.50,.58),W)
        cyl('spool spindle',(0,0,.58),.053,.86,I,axis='X')
        for x in [-.25,.25]:cyl('wood spool flange',(x,0,.58),.27,.055,W,axis='X')
        cyl('thread core',(0,0,.58),.18,.48,C,axis='X')
        for x in np.linspace(-.22,.22,20):
            line('spool thread winding',[(float(x),.19*math.cos(a),.58+.19*math.sin(a)) for a in np.linspace(0,TAU,25)],.009,C)
        line('loose thread tail',[(.05,-.19,.58),(.14,-.27,.36),(.28,-.3,.30)],.009,C)
def plate():
    box('plate base',(0,0,.025),(1.3,1.3,.05),I);p=pivot('Deck',(0,0,.08));box('spring deck',(0,0,.09),(1.19,1.19,.06),E,p)
    for x in [-.49,.49]:
        for y in [-.49,.49]:cyl('deck brass stop',(x,y,.105),.041,.025,B,p)
    for x in np.linspace(-.40,.40,7):box('drain slot',(float(x),0,.123),(.028,.76,.003),I,p,0)
def steam():
    box('pipe foot',(0,0,.05),(.42,.40,.1),I);line('steam riser',[(0,0,.09),(0,0,.8),(.15,0,.96),(.15,-.16,1.09)],.062,E)
    for z in [.19,.59]:cyl('steam flange',(0,0,z),.11,.05,B)
    cyl('open nozzle',(.15,-.21,1.09),.076,.12,I,axis='Y');cyl('nozzle dark bore',(.15,-.273,1.09),.049,.002,I,axis='Y');gauge(-.09,.85)
def bigbell():
    p=pivot('Bell',(0,0,0));bell_shell('great hollow bell',(0,0,-.14),1.25,2.18,p)
    for z,r in [(-.75,.37),(-1.45,.65),(-2.12,1.12)]:ring('cast ornamental band',(0,0,z),r,.035,B,p,'Z')
    for a in np.linspace(0,TAU,12,endpoint=False):
        x,y=math.cos(a),math.sin(a);line('raised petal ornament',[(x*.45,y*.45,-.95),(x*.6,y*.6,-1.2),(x*.7,y*.7,-1.49)],.027,'Copper contacts',p)
    ring('crown hanging eye',(0,0,-.21),.16,.05,I,p)
    h=pivot('Hammer',(1.40,0,-.45));line('hammer curved haft',[(1.40,0,-.45),(1.43,0,-1.3),(1.25,-.1,-1.8)],.05,W,h);ball('hammer striking head',(1.23,-.1,-1.85),(.28,.21,.20),I,h)
    root.scale=(1.1,1.1,1.1)
def exit_prop(name):
    if name=='exit_workshop':
        # Floor-mounted shipping chute: a shallow roller deck remains visible
        # above the existing continuous gameplay floor without new collisions.
        for y in [-.55,.55]:
            o=box('riveted shallow chute side',(0,y,.17),(3.7,.10,.28),E);o.rotation_euler[1]=.008
            for x in np.linspace(-1.60,1.60,12):ball('chute rivet',(float(x),y-.06,.20-.008*float(x)),(.025,.015,.025),B)
        o=box('shallow wood chute bed',(0,0,.025),(3.7,1.1,.03),W,bevel=.006);o.rotation_euler[1]=.008
        for x in np.linspace(-1.65,1.65,18):
            cyl('shipping bed roller',(float(x),0,.038-.008*float(x)),.014,1.02,I,axis='Y',verts=16)
        for x in [-1.55,1.5]:
            box('loading arch upright',(x,.42,2.0),(.20,.25,4),I);box('arch foot',(x,.42,.12),(.47,.5,.24),B)
        box('loading arch lintel',(0,.42,3.88),(3.6,.30,.24),W,bevel=.07)
        for x in [-1.5,1.5]:line('hanging chute chain',[(x,.42,3.8),(x,.4,.30-.008*x)],.024,I)
        ring('shipping eye',(0,.4,3.52),.18,.04,B)
        return
    for x in [-1.55,1.55]:
        box('doorway pier',(x,.1,1.8),(.36,.85,3.6),E if name=='exit_laundry' else W,bevel=.09);box('pier iron shoe',(x,.1,.15),(.55,1,.3),I)
        rivets(x,-.34,1.9,.20,3)
    if name=='exit_laundry':
        line('overhead bent laundry pipe',[(-1.55,.1,3.4),(-1.35,.1,3.75),(0,.1,3.85),(1.35,.1,3.75),(1.55,.1,3.4)],.18,E)
        for x in [-1.05,1.05]:cyl('pipe flange',(x,.1,3.77),.24,.1,B,axis='X')
        p=pivot('Door',(-1.4,.18,1.8));o=box('hatch parked open',(-1.54,.50,1.8),(.13,.90,2.95),E,p,bevel=.12)
        for z in [.5,3.1]:cyl('hatch hinge',(-1.39,.15,z),.075,.22,B)
    elif name=='exit_vault':
        box('sliding rack overhead rail',(0,.1,3.7),(3.7,.35,.28),I)
        p=pivot('Door',(1.45,.25,1.8));box('parked rack side',(1.48,.43,1.8),(.25,.55,3.2),I,p)
        for z in np.linspace(.4,3.1,9):box('rack shelf end',(1.46,.40,float(z)),(.42,.85,.06),B,p)
        for x in [-.85,.85]:cyl('rail trolley',(x,.1,3.85),.13,.20,B,axis='Y')
    else:
        for a in np.linspace(.03,math.pi-.03,20):
            x=1.6*math.cos(a);z=2.2+1.6*math.sin(a);o=box('broken clock arch segment',(x,.05,z),(.29,.55,.27),IV);o.rotation_euler[1]=-a
        for a in np.linspace(.18,math.pi-.18,11):
            x=1.36*math.cos(a);z=2.2+1.36*math.sin(a);o=box('clock hour baton',(x,-.25,z),(.055,.065,.20),B);o.rotation_euler[1]=math.pi/2-a
        line('broken clock hand',[(1.25,.25,2.3),(.9,.25,3.2)],.045,I)
        for x in [-1.25,1.3]:box('broken sill tooth',(x,.1,.16),(.25,.7,.32),IV)
def clear(name):
    global root
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
def unwrap():
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH':continue
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
def external_glb(path):
    raw=path.read_bytes();jl=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+jl]);binary=raw[28+jl:];removed=set()
    for im in doc.get('images',[]):
        if 'bufferView' not in im:continue
        idx=im.pop('bufferView');removed.add(idx);im.pop('mimeType',None)
        stem=im.get('name','texture');src=T/f'{stem}.png'
        # Blender's ORM packing is another shared derived map.
        if not src.exists():
            view=doc['bufferViews'][idx];src.write_bytes(binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
        im['uri']='../../textures/props/'+src.name
    views=[];mapping={};out=bytearray()
    for idx,v in enumerate(doc.get('bufferViews',[])):
        if idx in removed:continue
        while len(out)%4:out.append(0)
        start=v.get('byteOffset',0);payload=binary[start:start+v['byteLength']];v['byteOffset']=len(out);out.extend(payload);mapping[idx]=len(views);views.append(v)
    doc['bufferViews']=views
    # Explicit standard glTF factors preserve shared images without exporter-baked
    # per-material copies; ORM packing keeps G roughness / B metallic correct.
    for material in doc.get('materials',[]):
        family,color,metallic=material_specs[material['name']]
        pbr=material['pbrMetallicRoughness'];pbr['baseColorFactor']=[*color,1]
        pbr['metallicFactor']=metallic if metallic is not None else 1
        image_idx=len(doc['images']);doc['images'].append({'name':family+'_orm_2k','uri':'../../textures/props/'+family+'_orm_2k.png'})
        texture_idx=len(doc['textures']);doc['textures'].append({'source':image_idx});pbr['metallicRoughnessTexture']={'index':texture_idx}
    for a in doc['accessors']:
        if 'bufferView' in a:a['bufferView']=mapping[a['bufferView']]
    doc['buffers'][0]['byteLength']=len(out)
    while len(out)%4:out.append(0)
    js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*((-len(js))%4)
    path.write_bytes(struct.pack('<III',0x46546c67,2,12+8+len(js)+8+len(out))+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(out),0x004e4942)+out)
def render(name,bounds,view='threequarter'):
    lo,hi=bounds; center=(lo+hi)/2;span=max(hi-lo)
    bpy.ops.object.camera_add();cam=bpy.context.object;cam.name='Preview camera';cam.location=center+Vector((span*.95,-span*1.75,span*.65) if view=='threequarter' else (0,-span*2,span*.20));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=span*1.4 if view!='near' else span*.95;bpy.context.scene.camera=cam
    lights=[]
    for loc,power,size in [((-.9,-1.5,2),1000,2),((1,.7,1.3),1400,1.5),((1,-1,.4),350,2)]:
        bpy.ops.object.light_add(type='AREA',location=center+Vector(loc)*span);o=bpy.context.object;o.data.energy=power*span*span*.35;o.data.shape='DISK';o.data.size=size*span;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler();lights.append(o)
    sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True;sc.world.color=(.11,.11,.11);sc.render.resolution_x=640;sc.render.resolution_y=640;sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';sc.render.filepath=str(P/f'{name}_{view}.png');sc.view_settings.view_transform='AgX';bpy.ops.render.render(write_still=True)
    for o in lights+[cam]:bpy.data.objects.remove(o,do_unlink=True)
def main():
    names='drain fill winch_a winch_b bell brake wind release fuse_box power_switch laundry_cart spool_carrier pressure_plate steam_pipe last_bell exit_workshop exit_laundry exit_vault exit_clocktower'.split()
    if '--heroes' in sys.argv:names=['drain','bell','exit_workshop']
    if '--only' in sys.argv:names=sys.argv[sys.argv.index('--only')+1].split(',')
    reports={}
    for name in names:
        clear(name)
        if name.startswith('exit_'):exit_prop(name)
        elif name in ['laundry_cart','spool_carrier']:cart(name)
        elif name=='pressure_plate':plate()
        elif name=='steam_pipe':steam()
        elif name=='last_bell':bigbell()
        else:mechanism(name)
        unwrap();bpy.context.view_layer.update()
        points=[o.matrix_world@Vector(v) for o in bpy.context.scene.objects if o.type=='MESH' for v in o.bound_box]
        lo=Vector(tuple(min(v[i] for v in points) for i in range(3)));hi=Vector(tuple(max(v[i] for v in points) for i in range(3)))
        tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH')
        pivots=[o.name for o in bpy.context.scene.objects if o.type=='EMPTY' and o!=root]
        reports[name]={'triangles':tris,'blender_min':list(lo),'blender_max':list(hi),'godot_size':[hi.x-lo.x,hi.z-lo.z,hi.y-lo.y],'pivots':pivots}
        bpy.context.preferences.filepaths.save_version=0
        for im in bpy.data.images:
            if im.source=='FILE' and im.filepath:im.filepath='//../../textures/props/'+Path(im.filepath).name
        bpy.ops.wm.save_as_mainfile(filepath=str(S/f'{name}.blend'),relative_remap=False)
        bpy.ops.export_scene.gltf(filepath=str(M/f'{name}.glb'),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
        external_glb(M/f'{name}.glb')
        if '--no-render' not in sys.argv:
            render(name,(lo,hi))
            if name in ['drain','bell','exit_workshop']:
                render(name,(lo,hi),'front');render(name,(lo,hi),'near')
        print('PROP_REPORT',name,json.dumps(reports[name]),flush=True)
    previous=json.loads((S/'measurements.json').read_text()) if (S/'measurements.json').exists() else {};previous.update(reports);(S/'measurements.json').write_text(json.dumps(previous,indent=2))
    rows=['# Mechanical prop assets','', 'Original modeled assemblies in worn walnut, oxidized brass, teal enamel, dark iron and woven linen. No text labels. GLBs use shared external 2K PBR textures; keep assets/textures/props beside the models directory hierarchy. Blender sources preserve articulated empty parents.','', 'Regenerate: `blender -b --python tools/create_mechanical_props.py`. Use `-- --heroes` for initial three hero previews or `-- --no-render` for export only. Verify: `python tests/check_mechanical_assets.py`.','', 'Godot axes: Y up, +Z front. Normal origins at ground; last_bell origin is top suspension. Rotor, Lever, Bell, Hammer and Needle animate around local Godot Z; Deck translates local Y. Fuse can be hidden/removed. Exit Door assemblies are parked open.','', '| Asset | Triangles | Godot width x height x depth (m) | Pivots |','|---|---:|---|---|']
    for n,r in previous.items():rows.append(f"| {n} | {r['triangles']} | {' x '.join(f'{v:.3f}' for v in r['godot_size'])} | {', '.join(r['pivots']) or '-'} |")
    rows += ['', 'The workshop chute sits above the existing continuous floor: shallow rollers run from local Godot Y approximately 0.065 at the left entry to 0.039 at the right exit, with raised side rails approximately 0.30 m tall. The deck slopes gently toward +X and does not change gameplay collisions. Other exits keep their central passage open.', '', 'Twelve source PBR maps are shared across the family. Three derived ORM maps pack roughness into G and metallic into B; base color factors preserve the brass/iron/enamel variants without duplicated albedo textures. Sources use relative texture paths. Preview contact sheet reads left-to-right in the generator asset list order.']
    (R/'docs/mechanical-assets.md').write_text('\n'.join(rows)+'\n')
    # Generate an all-prop contact sheet using Blender image buffers (no Pillow dependency).
    all_names='drain fill winch_a winch_b bell brake wind release fuse_box power_switch laundry_cart spool_carrier pressure_plate steam_pipe last_bell exit_workshop exit_laundry exit_vault exit_clocktower'.split()
    sheet=np.full((4*256,5*256,3),36,dtype=np.uint8)
    for i,n in enumerate(all_names):
        path=P/f'{n}_threequarter.png'
        if not path.exists():continue
        im=bpy.data.images.load(str(path),check_existing=False);im.scale(256,256);pixels=np.array(im.pixels[:]).reshape(256,256,4)[::-1,:,:3];sheet[(i//5)*256:(i//5+1)*256,(i%5)*256:(i%5+1)*256]=np.clip(pixels*255,0,255);bpy.data.images.remove(im)
    png(P/'all_props_contactsheet.png',sheet)
if __name__=='__main__':main()
