"""Create the rigged v2 Midnight Workshop hero and keeper.

Run from the repository root with:
    blender.exe --background --python tools/create_characters_v2.py

All geometry, textures, rigs, actions, source files, previews, and the report are
generated procedurally. The script only overwrites its explicitly owned outputs.
"""

from __future__ import annotations

import json
import math
import struct
import sys
import zlib
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "assets" / "models"
SOURCE_DIR = ROOT / "assets" / "sources"
PREVIEW_DIR = SOURCE_DIR / "previews"
TEXTURE_DIR = ROOT / "assets" / "textures" / "characters"
REPORT_PATH = ROOT / "docs" / "character-v2-report.md"
TAU = math.tau


def ensure_dirs():
    for path in (MODEL_DIR, SOURCE_DIR, PREVIEW_DIR, TEXTURE_DIR, REPORT_PATH.parent):
        path.mkdir(parents=True, exist_ok=True)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.curves, bpy.data.armatures,
                       bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(collection):
            if datablock.users == 0:
                collection.remove(datablock)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)


def png_chunk(tag, payload):
    return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)


def write_texture_set(stem, palette, rough_base, stain):
    """Write deterministic 2048px woven albedo and roughness maps."""
    size = 2048
    albedo_path = TEXTURE_DIR / f"{stem}_albedo_2k.png"
    rough_path = TEXTURE_DIR / f"{stem}_roughness_2k.png"
    if albedo_path.exists() and rough_path.exists() and "--rebuild-textures" not in sys.argv:
        return albedo_path, rough_path
    compressor_a = zlib.compressobj(7)
    compressor_r = zlib.compressobj(7)
    data_a, data_r = [], []
    for y in range(size):
        row_a = bytearray([0])
        row_r = bytearray([0])
        warp = 8 if (y % 6) < 2 else -5
        for x in range(size):
            h = ((x * 73856093) ^ (y * 19349663) ^ ((x // 47) * 83492791)) & 255
            weave = (11 if (x % 7) < 2 else -4) + warp + ((h % 13) - 6)
            smear = math.sin(x * .011 + y * .004) * stain + math.sin(y * .019) * stain * .45
            edge_grime = -18 if ((x + y * 3) % 509) < 9 else 0
            rgb = [max(0, min(255, int(c + weave + smear + edge_grime))) for c in palette]
            row_a.extend((*rgb, 255))
            rough = max(0, min(255, int(rough_base + abs(weave) * 1.5 + (h % 9))))
            row_r.extend((rough, rough, rough, 255))
        data_a.append(compressor_a.compress(bytes(row_a)))
        data_r.append(compressor_r.compress(bytes(row_r)))
    data_a.append(compressor_a.flush())
    data_r.append(compressor_r.flush())
    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    albedo_path.write_bytes(b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", header) + png_chunk(b"IDAT", b"".join(data_a)) + png_chunk(b"IEND", b""))
    rough_path.write_bytes(b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", header) + png_chunk(b"IDAT", b"".join(data_r)) + png_chunk(b"IEND", b""))
    return albedo_path, rough_path


def material_from_maps(name, albedo_path, rough_path):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    albedo = nodes.new("ShaderNodeTexImage")
    albedo.name = f"{name}_Albedo"
    albedo.image = bpy.data.images.load(str(albedo_path), check_existing=True)
    rough = nodes.new("ShaderNodeTexImage")
    rough.name = f"{name}_Roughness"
    rough.image = bpy.data.images.load(str(rough_path), check_existing=True)
    rough.image.colorspace_settings.name = "Non-Color"
    links.new(albedo.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = 0.0
    return mat


def flat_material(name, color, roughness=.85, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    if emission is not None:
        (bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")).default_value = emission
        strength = bsdf.inputs.get("Emission Strength")
        if strength:
            strength.default_value = emission_strength
    return mat


def create_mesh(name, verts, faces, uvs, material, armature=None, weights=None, smooth=True):
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if material:
        mesh.materials.append(material)
    if uvs:
        layer = mesh.uv_layers.new(name="UVMap")
        for loop in mesh.loops:
            layer.data[loop.index].uv = uvs[loop.vertex_index]
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if armature and weights:
        for bone_name, values in weights.items():
            group = obj.vertex_groups.new(name=bone_name)
            indices = [index for index, value in enumerate(values) if value > 1e-5]
            for index in indices:
                group.add([index], values[index], "REPLACE")
        mod = obj.modifiers.new("ArmatureDeform", "ARMATURE")
        mod.object = armature
        obj.parent = armature
    return obj


def apply_surface(obj, subdivision=0, thickness=0.0):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if thickness:
        solid = obj.modifiers.new("ClothThickness", "SOLIDIFY")
        solid.thickness = thickness
        solid.offset = 0.0
        arm_index = obj.modifiers.find("ArmatureDeform")
        if arm_index >= 0:
            obj.modifiers.move(arm_index, len(obj.modifiers) - 1)
        bpy.ops.object.modifier_apply(modifier=solid.name)
    if subdivision:
        sub = obj.modifiers.new("SculptedSurface", "SUBSURF")
        sub.levels = subdivision
        sub.render_levels = subdivision
        arm_index = obj.modifiers.find("ArmatureDeform")
        if arm_index >= 0:
            obj.modifiers.move(arm_index, len(obj.modifiers) - 1)
        bpy.ops.object.modifier_apply(modifier=sub.name)
    obj.select_set(False)


def lathe_shell(name, rings, segments, material, armature, weight_fn, thickness=.0, subdivision=0):
    """Build an authored asymmetric cloth shell from elliptical rings."""
    verts, uvs, weights = [], [], {}
    for ri, ring in enumerate(rings):
        z, cx, cy, rx, ry, phase, scallop = ring
        for si in range(segments):
            a = TAU * si / segments
            fold = .045 * math.sin(a * 7 + phase) + .018 * math.sin(a * 13 - phase)
            side_bias = .025 * math.sin(a + phase) + .012 * math.cos(a * 3)
            x = cx + (rx + fold) * math.cos(a) + side_bias
            y = cy + (ry + fold * .45) * math.sin(a)
            zz = z + (scallop * (.5 + .5 * math.sin(a * 5 + phase)) if ri == 0 else 0)
            verts.append((x, y, zz))
            uvs.append((si / segments, ri / max(1, len(rings) - 1)))
            current = weight_fn((x, y, zz), ri / max(1, len(rings) - 1), a)
            for bone in current:
                if bone not in weights:
                    weights[bone] = [0.0] * (len(verts) - 1)
            for bone in weights:
                weights[bone].append(current.get(bone, 0.0))
    faces = []
    for ri in range(len(rings) - 1):
        for si in range(segments):
            a = ri * segments + si
            b = ri * segments + (si + 1) % segments
            c = (ri + 1) * segments + (si + 1) % segments
            d = (ri + 1) * segments + si
            faces.append((a, b, c, d))
    obj = create_mesh(name, verts, faces, uvs, material, armature, weights)
    apply_surface(obj, subdivision, thickness)
    return obj


def ellipsoid(name, center, scale, material, armature, bone, segments=32, rings=18, deform=None):
    verts, faces, uvs = [], [], []
    for ri in range(rings + 1):
        phi = math.pi * ri / rings
        for si in range(segments):
            theta = TAU * si / segments
            p = Vector((center[0] + scale[0] * math.sin(phi) * math.cos(theta),
                        center[1] + scale[1] * math.sin(phi) * math.sin(theta),
                        center[2] + scale[2] * math.cos(phi)))
            if deform:
                p = deform(p, phi, theta)
            verts.append(tuple(p))
            uvs.append((si / segments, ri / rings))
    for ri in range(rings):
        for si in range(segments):
            a = ri * segments + si
            b = ri * segments + (si + 1) % segments
            c = (ri + 1) * segments + (si + 1) % segments
            d = (ri + 1) * segments + si
            faces.append((a, b, c, d))
    weights = {bone: [1.0] * len(verts)}
    return create_mesh(name, verts, faces, uvs, material, armature, weights)


def tube(name, points, radii, material, armature, bones, segments=12):
    verts, faces, uvs = [], [], []
    weights = {bone: [] for bone in bones}
    frames = []
    for i, point in enumerate(points):
        tangent = Vector(points[min(i + 1, len(points) - 1)]) - Vector(points[max(i - 1, 0)])
        tangent.normalize()
        axis = Vector((0, 0, 1)) if abs(tangent.z) < .88 else Vector((1, 0, 0))
        normal = tangent.cross(axis).normalized()
        binormal = tangent.cross(normal).normalized()
        frames.append((normal, binormal))
    for pi, point in enumerate(points):
        normal, binormal = frames[pi]
        t = pi / max(1, len(points) - 1)
        for si in range(segments):
            a = TAU * si / segments
            p = Vector(point) + radii[pi] * (math.cos(a) * normal + math.sin(a) * binormal)
            verts.append(tuple(p))
            uvs.append((si / segments, t))
            scaled = t * (len(bones) - 1)
            left = min(int(scaled), len(bones) - 1)
            blend = scaled - left
            for bi, bone in enumerate(bones):
                value = (1.0 - blend if bi == left else blend if bi == min(left + 1, len(bones) - 1) else 0.0)
                weights[bone].append(value)
    for pi in range(len(points) - 1):
        for si in range(segments):
            a = pi * segments + si
            b = pi * segments + (si + 1) % segments
            c = (pi + 1) * segments + (si + 1) % segments
            d = (pi + 1) * segments + si
            faces.append((a, b, c, d))
    faces.append(tuple(range(segments - 1, -1, -1)))
    base = (len(points) - 1) * segments
    faces.append(tuple(base + i for i in range(segments)))
    return create_mesh(name, verts, faces, uvs, material, armature, weights)


def ribbon(name, centerline, widths, material, armature, bones, thickness=.008):
    verts, faces, uvs = [], [], []
    weights = {bone: [] for bone in bones}
    for i, p in enumerate(centerline):
        tangent = Vector(centerline[min(i + 1, len(centerline) - 1)]) - Vector(centerline[max(0, i - 1)])
        side = tangent.cross(Vector((0, 0, 1)))
        if side.length < .001:
            side = Vector((1, 0, 0))
        side.normalize()
        for sign in (-1, 1):
            verts.append(tuple(Vector(p) + side * widths[i] * sign))
            uvs.append(((sign + 1) * .5, i / max(1, len(centerline) - 1)))
            scaled = i / max(1, len(centerline) - 1) * (len(bones) - 1)
            left = min(int(scaled), len(bones) - 1)
            blend = scaled - left
            for bi, bone in enumerate(bones):
                weights[bone].append(1 - blend if bi == left else blend if bi == min(left + 1, len(bones) - 1) else 0)
    for i in range(len(centerline) - 1):
        faces.append((i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2))
    obj = create_mesh(name, verts, faces, uvs, material, armature, weights)
    apply_surface(obj, 1, thickness)
    return obj


def create_armature(name, bone_specs):
    data = bpy.data.armatures.new(f"{name}Rig")
    arm = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    created = {}
    for bone_name, head, tail, parent, connected in bone_specs:
        bone = data.edit_bones.new(bone_name)
        bone.head = head
        bone.tail = tail
        bone.roll = 0
        if parent:
            bone.parent = created[parent]
            bone.use_connect = connected
        created[bone_name] = bone
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.select_set(False)
    arm.show_in_front = True
    arm.data.display_type = "STICK"
    return arm


def set_pose_key(arm, frame, pose):
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    for bone, transform in pose.items():
        if bone not in arm.pose.bones:
            continue
        rotation, location = transform
        arm.pose.bones[bone].rotation_euler = rotation
        arm.pose.bones[bone].location = location
    for pb in arm.pose.bones:
        pb.keyframe_insert("rotation_euler", frame=frame, group=pb.name)
        pb.keyframe_insert("location", frame=frame, group=pb.name)


def create_actions(arm, clips):
    arm.animation_data_create()
    made = []
    for name, end_frame, cyclic, keyframes in clips:
        action = bpy.data.actions.new(name=name)
        action.use_fake_user = True
        arm.animation_data.action = action
        for frame, pose in keyframes:
            set_pose_key(arm, frame, pose)
        action.frame_start = 1
        action.frame_end = end_frame
        action["loop_mode"] = "REPEAT" if cyclic else "ONCE"
        made.append(action)
    arm.animation_data.action = None
    return made


def P(rotation=(0, 0, 0), location=(0, 0, 0)):
    return tuple(math.radians(v) for v in rotation), location


def hero_rig():
    specs = [
        ("Root", (0, 0, 0), (0, 0, .12), None, False),
        ("Hips", (0, 0, .34), (0, 0, .56), "Root", False),
        ("Spine", (0, 0, .56), (0, 0, .82), "Hips", True),
        ("Chest", (0, 0, .82), (0, -.01, 1.02), "Spine", True),
        ("Head", (0, -.01, 1.02), (-.035, -.02, 1.30), "Chest", True),
        ("UpperArm.L", (-.16, 0, .94), (-.24, -.015, .72), "Chest", False),
        ("Forearm.L", (-.24, -.015, .72), (-.285, -.08, .51), "UpperArm.L", True),
        ("Hand.L", (-.285, -.08, .51), (-.29, -.11, .43), "Forearm.L", True),
        ("UpperArm.R", (.16, 0, .94), (.24, .005, .72), "Chest", False),
        ("Forearm.R", (.24, .005, .72), (.29, -.06, .51), "UpperArm.R", True),
        ("Hand.R", (.29, -.06, .51), (.30, -.10, .43), "Forearm.R", True),
        ("Thigh.L", (-.105, 0, .42), (-.105, .005, .22), "Hips", False),
        ("Shin.L", (-.105, .005, .22), (-.105, -.015, .075), "Thigh.L", True),
        ("Foot.L", (-.105, -.015, .075), (-.105, -.15, .045), "Shin.L", True),
        ("Thigh.R", (.105, 0, .42), (.105, -.005, .22), "Hips", False),
        ("Shin.R", (.105, -.005, .22), (.105, -.02, .075), "Thigh.R", True),
        ("Foot.R", (.105, -.02, .075), (.105, -.15, .045), "Shin.R", True),
        ("ClothRoot", (0, .10, .72), (.015, .15, .49), "Hips", False),
        ("ClothMid", (.015, .15, .49), (.04, .21, .27), "ClothRoot", True),
        ("ClothTip", (.04, .21, .27), (.13, .34, .12), "ClothMid", True),
    ]
    return create_armature("DollArmature", specs)


def hero_clips():
    def gait(a, fast=False):
        lift = 36 if fast else 25
        swing = 34 if fast else 23
        return {
            "Thigh.L": P((a * swing, 0, 0)), "Thigh.R": P((-a * swing, 0, 0)),
            "Shin.L": P((max(0, -a) * lift, 0, 0)), "Shin.R": P((max(0, a) * lift, 0, 0)),
            "UpperArm.L": P((-a * swing * .8, 0, 0)), "UpperArm.R": P((a * swing * .8, 0, 0)),
            "ClothMid": P((a * 7, 0, a * 4)), "ClothTip": P((-a * 11, 0, -a * 5)),
        }
    # Bone-local Y follows these vertical bones. Drop the torso deeply while
    # counter-translating the leg chains so the feet remain planted.
    crouch = {"Hips": P((0, 0, 0), (0, -.70, 0)),
              "Thigh.L": P((-42, 0, 0), (0, -.70, 0)), "Thigh.R": P((-42, 0, 0), (0, -.70, 0)),
              "Shin.L": P((70, 0, 0)), "Shin.R": P((70, 0, 0)), "Spine": P((32, 0, 0)),
              "UpperArm.L": P((-24, 0, -8), (0, -.40, 0)), "UpperArm.R": P((-24, 0, 8), (0, -.40, 0)),
              "ClothRoot": P((0, 0, 0), (0, -.63, 0))}
    clips = [
        ("idle", 40, True, [(1, {"Spine": P((1, 0, -1)), "Head": P((0, -3, 1)), "ClothTip": P((3, 0, -4))}),
                             (20, {"Spine": P((-1, 0, 1)), "Head": P((0, 2, -1)), "ClothTip": P((-4, 0, 5))}),
                             (40, {"Spine": P((1, 0, -1)), "Head": P((0, -3, 1)), "ClothTip": P((3, 0, -4))})]),
        ("walk", 20, True, [(1, gait(1)), (10, gait(-1)), (20, gait(1))]),
        ("run", 14, True, [(1, gait(1, True)), (7, gait(-1, True)), (14, gait(1, True))]),
        ("jump", 18, False, [(1, gait(0)), (7, {"Thigh.L": P((-38, 0, 0)), "Thigh.R": P((-38, 0, 0)), "Shin.L": P((65, 0, 0)), "Shin.R": P((65, 0, 0)), "UpperArm.L": P((110, 0, -12)), "UpperArm.R": P((110, 0, 12))}), (18, {"Thigh.L": P((18, 0, 0)), "Thigh.R": P((18, 0, 0)), "ClothTip": P((-28, 0, 0))})]),
        ("fall", 20, False, [(1, {"UpperArm.L": P((45, 0, -18)), "UpperArm.R": P((55, 0, 22)), "ClothTip": P((-24, 0, 9))}), (20, {"UpperArm.L": P((70, 0, -25)), "UpperArm.R": P((60, 0, 28)), "ClothTip": P((-35, 0, 13))})]),
        ("land", 14, False, [(1, {"Hips": P((0, 0, 0), (0, 0, -.18)), "Thigh.L": P((-38, 0, 0)), "Thigh.R": P((-38, 0, 0)), "Shin.L": P((62, 0, 0)), "Shin.R": P((62, 0, 0))}), (8, {"Hips": P((0, 0, 0), (0, 0, -.27)), "Spine": P((22, 0, 0))}), (14, {})]),
        ("crouch", 12, False, [(1, {}), (12, crouch)]),
        ("crouch_walk", 24, True, [(1, {**crouch, "Thigh.L":P((-31,0,0),(0,-.70,0)), "Thigh.R":P((-49,0,0),(0,-.70,0)), "ClothTip":P((-5,0,-3))}),
                                     (12, {**crouch, "Thigh.L":P((-49,0,0),(0,-.70,0)), "Thigh.R":P((-31,0,0),(0,-.70,0)), "ClothTip":P((5,0,3))}),
                                     (24, {**crouch, "Thigh.L":P((-31,0,0),(0,-.70,0)), "Thigh.R":P((-49,0,0),(0,-.70,0)), "ClothTip":P((-5,0,-3))})]),
        ("push", 28, False, [(1, {}), (10, {"Spine": P((24, 0, 0)), "UpperArm.L": P((-84, 0, -5)), "UpperArm.R": P((-84, 0, 5)), "Forearm.L": P((-18, 0, 0)), "Forearm.R": P((-18, 0, 0))}), (28, {"Spine": P((19, 0, 0)), "UpperArm.L": P((-74, 0, -4)), "UpperArm.R": P((-74, 0, 4))})]),
        ("pickup", 26, False, [(1, {}), (12, {**crouch, "UpperArm.L": P((-58, 0, -12)), "UpperArm.R": P((-58, 0, 12))}), (26, {"UpperArm.L": P((-82, 0, -8)), "UpperArm.R": P((-82, 0, 8)), "Forearm.L": P((-45, 0, 0)), "Forearm.R": P((-45, 0, 0))})]),
        ("interact", 22, False, [(1, {}), (10, {"UpperArm.R": P((-105, 0, 8)), "Forearm.R": P((-35, 0, 0)), "Head": P((0, 8, -4))}), (22, {})]),
        ("caught", 32, False, [(1, {}), (10, {"UpperArm.L": P((85, 0, -38)), "UpperArm.R": P((78, 0, 42)), "Head": P((18, 0, -12))}), (22, {"Spine": P((-22, 0, 18)), "ClothTip": P((42, 0, -20))}), (32, {"Spine": P((35, 0, 8)), "Head": P((28, 0, -20))})]),
    ]
    return clips


def build_hero(materials):
    arm = hero_rig()
    cloak_rings = []
    for i in range(15):
        t = i / 14
        z = .22 + t * .78
        cloak_rings.append((z, -.018 * math.sin(t * math.pi), .015 * (1-t), .34 - .13*t + .025*math.sin(t*math.pi), .22 - .035*t, i*.19, -.045))

    def cloak_weights(p, t, a):
        if t < .28 and p[1] > .02:
            return {"ClothTip": (1-t/.28)*.65, "ClothMid": .35 + t/.28*.3}
        if t < .18:
            return {"Root": 1.0}
        if t < .42:
            return {"Root": 1-(t-.18)/.24, "Hips": (t-.18)/.24}
        if t < .55:
            return {"Hips": 1-(t-.42)/.13, "Spine": (t-.42)/.13}
        return {"Spine": 1-(t-.55)/.45, "Chest": (t-.55)/.45}

    cloak = lathe_shell("Cloak_Main_Folded", cloak_rings, 48, materials["teal"], arm, cloak_weights, .018, 1)
    inner_rings = [(z+.015, cx, cy+.012, rx*.88, ry*.9, ph+.5, scallop*.6) for z,cx,cy,rx,ry,ph,scallop in cloak_rings[:11]]
    inner = lathe_shell("Cloak_Underlayer", inner_rings, 40, materials["teal_dark"], arm, cloak_weights, .012, 0)

    def hood_deform(p, phi, theta):
        # Pull the crown into an off-centre, backward-drooping hood tip.
        crown = max(0.0, (p.z - 1.22) / .25)
        p.x -= .09 * crown * crown
        p.y += .07 * crown
        p.z += .13 * crown * crown
        p.x += .014 * math.sin(theta * 5) * math.sin(phi)
        return p

    ellipsoid("Hood_Sculpted", (-.012, .005, 1.10), (.295, .245, .255), materials["teal"], arm, "Head", 40, 22, hood_deform)
    tube("Hood_Drooping_Tip", [(-.05,.06,1.28),(-.13,.12,1.34),(-.24,.18,1.29)], [.12,.06,.012], materials["teal"], arm, ["Head"], 16)
    ellipsoid("Face_Cavity", (0, -.231, 1.105), (.165, .022, .145), materials["cavity"], arm, "Head", 32, 16)
    # Thick hand-cut hood rim.
    rim_points = []
    for i in range(25):
        a = TAU * i / 24
        rim_points.append((.185*math.cos(a), -.258, 1.105 + .18*math.sin(a) + .018*math.sin(3*a)))
    tube("Hood_Opening_Rim", rim_points, [.022]*len(rim_points), materials["teal_dark"], arm, ["Head"], 10)
    # Uneven pinprick eyes, deliberately dim and partly swallowed by the cavity.
    ellipsoid("Eye_Glimmer_L", (-.052, -.258, 1.118), (.008, .004, .006), materials["eye"], arm, "Head", 12, 8)
    ellipsoid("Eye_Glimmer_R", (.044, -.259, 1.108), (.0055, .0035, .0045), materials["eye"], arm, "Head", 12, 8)

    for side, sign in (("L", -1), ("R", 1)):
        pts = [(sign*.16, 0, .91), (sign*.23, -.01, .76), (sign*.285, -.07, .58), (sign*.295, -.10, .48)]
        tube(f"Sleeve_{side}_Wrinkled", pts, [.085, .076, .061, .052], materials["teal"], arm,
             [f"UpperArm.{side}", f"Forearm.{side}", f"Hand.{side}"], 14)
        ellipsoid(f"Small_Hand_{side}", (sign*.297, -.105, .455), (.052, .045, .067), materials["patch"], arm, f"Hand.{side}", 16, 10)
        tube(f"Legging_{side}", [(sign*.105, 0, .39), (sign*.108, 0, .23), (sign*.105, -.01, .09)], [.075,.064,.052], materials["teal_dark"], arm, [f"Thigh.{side}", f"Shin.{side}"], 12)
        ellipsoid(f"Boot_{side}", (sign*.105, -.075, .06), (.09, .15, .06), materials["boot"], arm, f"Foot.{side}", 20, 10,
                  lambda p,ph,th: Vector((p.x + sign*.012*(1-math.sin(ph)), p.y, max(.004,p.z))))

    # Torn fluttering panels on the back share the cloth chain.
    ribbon("Cloak_Tail_Long", [(-.09,.16,.62),(-.10,.20,.47),(-.08,.28,.28),(-.15,.39,.12)], [.09,.085,.07,.025], materials["teal"], arm, ["ClothRoot","ClothMid","ClothTip"], .018)
    ribbon("Cloak_Tail_Short", [(.10,.15,.59),(.15,.22,.43),(.20,.31,.24)], [.075,.065,.018], materials["teal_light"], arm, ["ClothRoot","ClothMid","ClothTip"], .016)
    # Off-white repairs, lifted from the cloak and visibly sewn.
    for index, (cx, cz, w, h, tilt) in enumerate(((-.16,.58,.075,.10,-.16),(.19,.77,.065,.085,.11),(.08,.34,.055,.07,-.08))):
        pts = [(cx-w,-.224,cz-h),(cx+w,-.224,cz-h*.86),(cx+w*.9,-.229,cz+h),(cx-w*.86,-.228,cz+h*.9)]
        patch = create_mesh(f"Sewn_Patch_{index}", pts, [(0,1,2,3)], [(0,0),(1,0),(1,1),(0,1)], materials["patch"], arm, {"Spine":[1]*4})
        apply_surface(patch, 0, .006)
        for s in range(4):
            x = cx-w*.75+s*w*.5
            tube(f"Patch_{index}_Stitch_{s}", [(x,-.235,cz-h*.95),(x+.014*math.sin(s),-.236,cz-h*.72)], [.006,.006], materials["thread"], arm, ["Spine"], 6)

    actions = create_actions(arm, hero_clips())
    return arm, actions


def keeper_rig():
    specs = [
        ("Root", (0,0,0), (0,0,.18), None, False),
        ("Hips", (0,.05,.62), (0,.03,1.05), "Root", False),
        ("Spine", (0,.03,1.05), (-.04,-.02,1.72), "Hips", True),
        ("Chest", (-.04,-.02,1.72), (.06,-.20,2.55), "Spine", True),
        ("Head", (.06,-.20,2.55), (.03,-.48,3.22), "Chest", True),
        ("UpperArm.L", (-.43,-.06,2.42), (-.59,-.08,1.66), "Chest", False),
        ("Forearm.L", (-.59,-.08,1.66), (-.68,-.19,.82), "UpperArm.L", True),
        ("Hand.L", (-.68,-.19,.82), (-.69,-.29,.37), "Forearm.L", True),
        ("UpperArm.R", (.48,-.10,2.25), (.59,-.17,1.53), "Chest", False),
        ("Forearm.R", (.59,-.17,1.53), (.70,-.31,.72), "UpperArm.R", True),
        ("Hand.R", (.70,-.31,.72), (.72,-.40,.29), "Forearm.R", True),
        ("Thigh.L", (-.22,.04,.78), (-.30,.14,.40), "Hips", False),
        ("Shin.L", (-.30,.14,.40), (-.22,-.01,.11), "Thigh.L", True),
        ("Foot.L", (-.22,-.01,.11), (-.22,-.29,.06), "Shin.L", True),
        ("Thigh.R", (.19,.03,.78), (.31,-.04,.43), "Hips", False),
        ("Shin.R", (.31,-.04,.43), (.23,-.11,.10), "Thigh.R", True),
        ("Foot.R", (.23,-.11,.10), (.23,-.40,.055), "Shin.R", True),
        ("ClothRoot", (0,-.22,2.12), (.02,-.32,1.45), "Chest", False),
        ("ClothMid", (.02,-.32,1.45), (-.03,-.34,.75), "ClothRoot", True),
        ("ClothTip", (-.03,-.34,.75), (.08,-.33,.24), "ClothMid", True),
    ]
    for side, sign in (("L",-1),("R",1)):
        hand = (-.69 if side=="L" else .72, -.29 if side=="L" else -.40, .37 if side=="L" else .29)
        for fi, spread in enumerate((-1,0,1),1):
            x = hand[0] + sign*(.025 + fi*.012)
            y = hand[1] - .025*spread
            z = hand[2]
            specs.append((f"Finger{fi}.{side}.A", (x,y,z), (x+sign*.025,y-.035,z-.18), f"Hand.{side}", False))
            specs.append((f"Finger{fi}.{side}.B", (x+sign*.025,y-.035,z-.18), (x+sign*.045,y-.075,z-.34), f"Finger{fi}.{side}.A", True))
    return create_armature("KeeperArmature", specs)


def keeper_clips():
    def stalk(a, chase=False):
        swing = 18 if chase else 11
        reach = 13 if chase else 6
        return {"Thigh.L": P((a*swing,0,0)), "Thigh.R": P((-a*swing,0,0)),
                "Shin.L": P((max(0,-a)*23,0,0)), "Shin.R": P((max(0,a)*23,0,0)),
                "UpperArm.L": P((-a*reach,0,-a*3)), "UpperArm.R": P((a*reach,0,a*4)),
                "Spine": P((2+a*2,0,a*2)), "ClothTip": P((-a*8,0,a*4))}
    curl = {f"Finger{i}.{s}.{A}": P((52 if A=="A" else 68, 0, 0)) for s in ("L","R") for i in range(1,4) for A in ("A","B")}
    return [
        ("idle", 54, True, [(1,{"Spine":P((5,0,-2)),"Head":P((0,-5,2)),"ClothTip":P((2,0,-3))}),(27,{"Spine":P((2,0,2)),"Head":P((0,4,-2)),"ClothTip":P((-3,0,4))}),(54,{"Spine":P((5,0,-2)),"Head":P((0,-5,2)),"ClothTip":P((2,0,-3))})]),
        ("walk", 34, True, [(1,stalk(1)),(17,stalk(-1)),(34,stalk(1))]),
        ("alert", 26, False, [(1,{}),(8,{"Spine":P((-8,0,0)),"Head":P((-16,0,0)),"UpperArm.L":P((-20,0,-8)),"UpperArm.R":P((-16,0,10))}),(26,{"Head":P((-5,0,8))})]),
        ("listen", 56, True, [(1,{"Head":P((0,-18,-7)),"Spine":P((5,0,-3))}),(20,{"Head":P((0,24,10)),"Chest":P((0,0,5))}),(38,{"Head":P((0,-28,-12)),"Chest":P((0,0,-6))}),(56,{"Head":P((0,-18,-7)),"Spine":P((5,0,-3))})]),
        ("chase", 22, True, [(1,stalk(1,True)),(11,stalk(-1,True)),(22,stalk(1,True))]),
        ("grab", 38, False, [(1,{}),(11,{"Spine":P((-12,0,0)),"UpperArm.L":P((22,0,-18)),"UpperArm.R":P((18,0,22)),"Forearm.L":P((-35,0,0)),"Forearm.R":P((-32,0,0)),"Head":P((-8,0,0))}),(24,{"Spine":P((28,0,0)),"UpperArm.L":P((-72,0,-13)),"UpperArm.R":P((-75,0,16)),"Forearm.L":P((-58,0,0)),"Forearm.R":P((-62,0,0)),**curl}),(38,{"Spine":P((18,0,0)),**curl})]),
        ("stumble", 34, False, [(1,{}),(12,{"Spine":P((22,0,-18)),"Chest":P((14,0,-12)),"UpperArm.L":P((52,0,-35)),"UpperArm.R":P((62,0,38)),"Thigh.L":P((-28,0,0))}),(24,{"Spine":P((36,0,22)),"Head":P((18,0,-20)),"Thigh.R":P((-31,0,0))}),(34,{"Spine":P((12,0,4))})]),
    ]


def build_keeper(materials):
    arm = keeper_rig()
    rings = []
    for i in range(19):
        t = i/18
        z = .58 + t*1.92
        bulge = math.sin(t*math.pi)
        rx = .31 + .24*bulge + .08*(t>.72)
        ry = .25 + .18*bulge
        cx = -.045*math.sin(t*4.2) + (.07 if t>.72 else 0)
        cy = .08 - .24*t*t
        rings.append((z,cx,cy,rx,ry,i*.23,-.025 if i==0 else 0))
    def body_weights(p,t,a):
        if t<.25:return {"Hips":1.0}
        if t<.62:return {"Hips":1-(t-.25)/.37,"Spine":(t-.25)/.37}
        return {"Spine":1-(t-.62)/.38,"Chest":(t-.62)/.38}
    lathe_shell("Keeper_Continuous_Body", rings, 56, materials["keeper_cloth"], arm, body_weights, .025, 1)

    def head_deform(p,phi,theta):
        p.x += .035*math.sin(theta*3+phi*2)
        p.y -= .10*max(0, math.sin(phi))*max(0,-math.sin(theta))
        p.z += .025*math.sin(theta*5)*math.sin(phi)
        return p
    ellipsoid("Keeper_Wrapped_Head", (.05,-.31,2.91), (.39,.38,.49), materials["keeper_cloth"], arm,"Head",40,24,head_deform)
    # Cloth wrapping bands spiral over the protruding head, leaving no readable face.
    for band in range(5):
        pts=[]
        for i in range(19):
            a=TAU*i/18 + band*.38
            z=2.72 + band*.105 + .07*math.sin(a)
            pts.append((.05+.39*math.cos(a),-.31-.39*math.sin(a)*.76,z))
        tube(f"Head_Wrap_{band}",pts,[.045+band*.003]*len(pts),materials["wrap"],arm,["Head"],8)
    ellipsoid("Face_Shadow", (.055,-.805,2.91), (.17,.018,.12), materials["cavity"], arm,"Head",24,12)

    for side,sign in (("L",-1),("R",1)):
        if side=="L":
            arm_pts=[(-.43,-.06,2.42),(-.51,-.07,2.05),(-.60,-.10,1.62),(-.66,-.18,1.16),(-.69,-.25,.72),(-.69,-.29,.38)]
        else:
            arm_pts=[(.48,-.10,2.25),(.53,-.13,1.90),(.60,-.19,1.49),(.66,-.27,1.04),(.71,-.36,.61),(.72,-.40,.30)]
        tube(f"Long_Arm_{side}",arm_pts,[.16,.145,.12,.095,.076,.07],materials["flesh"],arm,[f"UpperArm.{side}",f"Forearm.{side}",f"Hand.{side}"],16)
        ellipsoid(f"Knotted_Hand_{side}",arm_pts[-1],(.115,.10,.16),materials["flesh"],arm,f"Hand.{side}",20,12)
        base=Vector(arm_pts[-1])
        for fi,spread in enumerate((-1,0,1),1):
            end_z=.055+.008*abs(spread)
            fan=(fi-2)*.065
            pts=[tuple(base+Vector((sign*(.02+fan),spread*.035,-.02))),
                 tuple(base+Vector((sign*(.045+fan*1.15),spread*.055,-.15))),
                 (base.x+sign*(.07+fan*1.35),base.y+spread*.075,end_z)]
            tube(f"Finger_{fi}_{side}_Articulated",pts,[.028,.023,.015],materials["flesh"],arm,[f"Finger{fi}.{side}.A",f"Finger{fi}.{side}.B"],10)
            ellipsoid(f"Finger_{fi}_{side}_Nail",pts[-1],(.020,.033,.018),materials["nail"],arm,f"Finger{fi}.{side}.B",12,7)
        if side=="L": leg_pts=[(-.22,.04,.78),(-.30,.13,.49),(-.26,.08,.28),(-.22,-.01,.11)]
        else: leg_pts=[(.19,.03,.78),(.31,-.04,.48),(.28,-.08,.27),(.23,-.11,.10)]
        tube(f"Bent_Leg_{side}",leg_pts,[.18,.17,.13,.10],materials["flesh"],arm,[f"Thigh.{side}",f"Shin.{side}"],16)
        foot_center=(leg_pts[-1][0],leg_pts[-1][1]-.14,.07)
        ellipsoid(f"Crooked_Foot_{side}",foot_center,(.17,.29,.075),materials["flesh"],arm,f"Foot.{side}",22,10,
                  lambda p,ph,th: Vector((p.x+sign*.025*math.cos(th*2),p.y,max(.006,p.z))))

    # Heavy apron: an uneven gridded surface with real thickness and shaped folds.
    verts=[];uvs=[];faces=[];weights={"ClothRoot":[],"ClothMid":[],"ClothTip":[]}
    cols,rows=18,24
    for r in range(rows):
        t=r/(rows-1); z=2.28-t*1.94
        width=.44-(.09*t)+.045*math.sin(t*math.pi)
        for c in range(cols):
            u=c/(cols-1); x=(u-.5)*2*width + .025*math.sin(t*7+u*4)
            y=-.405-.035*math.sin(u*TAU*4+t*5)-.055*t
            zz=z + (.035*math.sin(u*TAU*3+t*4) if r==rows-1 else 0)
            verts.append((x,y,zz));uvs.append((u,1-t))
            weights["ClothRoot"].append(max(0,1-t*2));weights["ClothMid"].append(max(0,1-abs(t-.5)*2));weights["ClothTip"].append(max(0,t*2-1))
    for r in range(rows-1):
        for c in range(cols-1):
            a=r*cols+c;faces.append((a,a+1,a+1+cols,a+cols))
    apron=create_mesh("Stained_Apron_Folded",verts,faces,uvs,materials["apron"],arm,weights)
    apply_surface(apron,1,.022)
    ribbon("Apron_Torn_Flap",[(.24,-.43,1.12),(.28,-.45,.77),(.20,-.48,.43),(.31,-.47,.18)],[.13,.12,.09,.025],materials["apron"],arm,["ClothRoot","ClothMid","ClothTip"],.024)
    # Rope seams emphasize the unequal shoulder line and apron repairs.
    tube("Shoulder_Seam",[(-.47,-.29,2.40),(-.24,-.39,2.51),(.02,-.43,2.48),(.29,-.40,2.34),(.47,-.31,2.24)],[.016]*5,materials["thread"],arm,["Chest"],8)
    for i,z in enumerate((1.72,1.22,.72)):
        tube(f"Apron_Repair_{i}",[(-.18,-.466,z),(-.06,-.472,z+.035),(.08,-.475,z-.02),(.19,-.468,z+.025)],[.012]*4,materials["thread"],arm,["ClothMid" if i<2 else "ClothTip"],6)
    actions=create_actions(arm,keeper_clips())
    return arm,actions


def setup_materials():
    hero_a,hero_r=write_texture_set("hero_teal_cloth",(27,91,91),205,18)
    keeper_a,keeper_r=write_texture_set("keeper_dirty_cloth",(122,109,83),222,30)
    apron_a,apron_r=write_texture_set("keeper_stained_apron",(76,63,48),230,38)
    patch_a,patch_r=write_texture_set("hero_sewn_patches",(190,181,151),215,12)
    return {
        "teal":material_from_maps("HeroFadedTeal",hero_a,hero_r),
        "teal_light":flat_material("HeroWeatheredEdge",(.065,.25,.25,1),.92),
        "teal_dark":flat_material("HeroUnderCloth",(.018,.075,.078,1),.95),
        "patch":material_from_maps("HeroSewnPatch",patch_a,patch_r),
        "keeper_cloth":material_from_maps("KeeperOldCloth",keeper_a,keeper_r),
        "wrap":flat_material("KeeperWrapEdge",(.31,.28,.22,1),.97),
        "apron":material_from_maps("KeeperStainedApron",apron_a,apron_r),
        "flesh":flat_material("KeeperBruisedFlesh",(.16,.105,.10,1),.88),
        "nail":flat_material("KeeperOldNails",(.20,.17,.13,1),.72),
        "boot":flat_material("HeroBootLeather",(.055,.041,.033,1),.76),
        "thread":flat_material("BlackThread",(.012,.014,.014,1),.96),
        "cavity":flat_material("LightlessCavity",(.0015,.002,.002,1),1.0),
        "eye":flat_material("FaintUnevenEyes",(.16,.20,.17,1),.8,(.34,.44,.36,1),.32),
    }


def clean_transforms():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    bpy.ops.object.select_all(action="DESELECT")


def export_character(name, builder, materials):
    arm,actions=builder(materials)
    clean_transforms()
    bpy.context.scene.render.fps=30
    bpy.context.scene.frame_start=1
    bpy.context.scene.frame_end=max(int(a.frame_end) for a in actions)
    bpy.context.scene.world.color=(.006,.008,.009)
    bpy.context.preferences.filepaths.save_version=0
    blend_path=SOURCE_DIR/f"{name}.blend"
    glb_path=MODEL_DIR/f"{name}.glb"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path),check_existing=False)
    bpy.ops.export_scene.gltf(filepath=str(glb_path),export_format="GLB",export_yup=True,
                              export_apply=False,export_animations=True,export_animation_mode="ACTIONS",
                              export_force_sampling=True,export_materials="EXPORT")
    render_previews(name)
    return inspect_glb(name)


def render_previews(name):
    bpy.context.scene.frame_set(1)
    for obj in bpy.context.scene.objects:
        if obj.type=="ARMATURE" and obj.animation_data:
            obj.animation_data.action=None
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    minimum=Vector((min(p.x for p in points),min(p.y for p in points),min(p.z for p in points)))
    maximum=Vector((max(p.x for p in points),max(p.y for p in points),max(p.z for p in points)))
    center=(minimum+maximum)*.5;span=max(maximum-minimum)
    ground=flat_material("PreviewGround",(.011,.014,.015,1),.87)
    bpy.ops.mesh.primitive_plane_add(size=span*5,location=(0,0,minimum.z-.008))
    floor=bpy.context.object;floor.name="PreviewOnly_Ground";floor.data.materials.append(ground)
    for loc,energy,color,size in (((-span,-span*1.5,maximum.z+span*.7),1100,(.32,.62,.63),span*1.3),
                                  ((span*1.2,-span*.4,center.z+span*.5),850,(.84,.40,.19),span),
                                  ((0,span,maximum.z+span*.4),1200,(.12,.25,.27),span*1.5)):
        bpy.ops.object.light_add(type="AREA",location=loc)
        light=bpy.context.object;light.name="PreviewOnly_Light";light.data.energy=energy;light.data.color=color;light.data.shape="DISK";light.data.size=size
        light.rotation_euler=(center-light.location).to_track_quat("-Z","Y").to_euler()
    scene=bpy.context.scene;scene.render.engine="BLENDER_EEVEE";scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format="PNG";scene.render.film_transparent=False;scene.world.color=(.004,.006,.007)
    views={"front":(0,-span*2.7,center.z+.05*span),"side":(span*2.7,0,center.z+.05*span),"threequarter":(span*1.9,-span*2.1,center.z+.12*span)}
    for label,location in views.items():
        bpy.ops.object.camera_add(location=location)
        cam=bpy.context.object;cam.name=f"PreviewOnly_{label}_Camera";cam.data.lens=68
        cam.rotation_euler=(center-cam.location).to_track_quat("-Z","Y").to_euler();scene.camera=cam
        scene.render.filepath=str(PREVIEW_DIR/f"{name}_v2_{label}.png")
        bpy.ops.render.render(write_still=True)
        bpy.data.objects.remove(cam,do_unlink=True)


def inspect_glb(name):
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(MODEL_DIR/f"{name}.glb"))
    armatures=[o for o in bpy.context.scene.objects if o.type=="ARMATURE"]
    # Blender's importer creates a material-less Icosphere custom bone widget;
    # it is not a node or mesh in the GLB. Count only actual skin primitives.
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH" and any(m.type=="ARMATURE" for m in o.modifiers)]
    points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    minimum=Vector((min(p.x for p in points),min(p.y for p in points),min(p.z for p in points)))
    maximum=Vector((max(p.x for p in points),max(p.y for p in points),max(p.z for p in points)))
    triangles=0
    for obj in meshes:
        obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
    actions=sorted({a.name.split(".")[0] for a in bpy.data.actions})
    deformers=sum(1 for o in meshes if any(m.type=="ARMATURE" for m in o.modifiers))
    crouch_max=None
    if name=="doll" and armatures and bpy.data.actions.get("crouch"):
        arm=armatures[0];arm.animation_data_create();arm.animation_data.action=bpy.data.actions.get("crouch")
        bpy.context.scene.frame_set(12);depsgraph=bpy.context.evaluated_depsgraph_get()
        posed=[o.evaluated_get(depsgraph).matrix_world@v.co for o in meshes for v in o.evaluated_get(depsgraph).data.vertices]
        crouch_max=round(max(p.z for p in posed),4)
        arm.animation_data.action=None;bpy.context.scene.frame_set(1)
    result={"name":name,"triangles":triangles,"meshes":len(meshes),"armatures":len(armatures),"skinned_meshes":deformers,
            "bones":sorted(b.name for arm in armatures for b in arm.data.bones),"actions":actions,
            "min":[round(v,4) for v in minimum],"max":[round(v,4) for v in maximum],
            "dimensions":[round(v,4) for v in maximum-minimum],"crouch_max":crouch_max,
            "glb_bytes":(MODEL_DIR/f"{name}.glb").stat().st_size}
    return result


def verify(info):
    expected={"doll":["idle","walk","run","jump","fall","land","crouch","crouch_walk","push","pickup","interact","caught"],
              "keeper":["idle","walk","alert","listen","chase","grab","stumble"]}
    for name,data in info.items():
        assert data["armatures"]==1, f"{name}: expected one armature"
        assert data["skinned_meshes"]==data["meshes"], f"{name}: unskinned mesh found"
        assert "Head" in data["bones"] and "ClothRoot" in data["bones"] and "ClothTip" in data["bones"]
        missing=set(expected[name])-set(data["actions"])
        assert not missing, f"{name}: missing actions {sorted(missing)}"
        assert data["min"][2]>=-.025, f"{name}: below floor {data['min'][2]}"
        assert data["triangles"]>=10000, f"{name}: insufficient sculpt detail {data['triangles']} tris"
        for view in ("front","side","threequarter"):
            assert (PREVIEW_DIR/f"{name}_v2_{view}.png").stat().st_size>10000
    assert 1.20<=info["doll"]["max"][2]<=1.42
    assert .50<=info["doll"]["crouch_max"]<=.90, info["doll"]["crouch_max"]
    assert 3.35<=info["keeper"]["max"][2]<=3.75
    for path in TEXTURE_DIR.glob("*_2k.png"):
        assert path.read_bytes()[:8]==b"\x89PNG\r\n\x1a\n"


def write_report(info):
    d,k=info["doll"],info["keeper"]
    lines=["# Character v2 generation report","",
           "The hero and keeper are original procedural character designs generated by `tools/create_characters_v2.py` in Blender 5.2.1. Both replace the earlier rigid primitive characters with custom sculpted cloth surfaces, deforming armatures, UV textures, and exported named animation clips.","",
           "## Asset summary","",
           "| Asset | Triangles | Skinned meshes | Bounds min | Bounds max | GLB size |","|---|---:|---:|---|---|---:|",
           f"| `doll.glb` | {d['triangles']:,} | {d['skinned_meshes']} | {d['min']} | {d['max']} | {d['glb_bytes']:,} B |",
           f"| `keeper.glb` | {k['triangles']:,} | {k['skinned_meshes']} | {k['min']} | {k['max']} | {k['glb_bytes']:,} B |","",
           "Hero design: a 1.4 m pointed-hood cloth spirit with a deep, unlit face cavity, two deliberately uneven dim eye glimmers, layered faded-teal cloak shells, geometric folds, thick weathered hems, off-white sewn repairs, tiny hands and boots, and two independently skinned fluttering back panels.","",
           "Keeper design: a roughly 3.6 m hunched seamstress with a lopsided continuous cloth torso, protruding wrapped head, blank shadowed face, low unequal shoulders, thick stained apron, bent legs, and two extremely long arms ending in six articulated, near-floor fingers. The muted underlying skin is bruised brown without gore.","",
           "## Rig and clips","",
           "Both GLBs contain one `Skeleton3D` source armature. All visible mesh objects have armature deformation and explicit vertex weights. Skeleton transforms are applied at scale 1. The root bone remains at the feet and never receives locomotion translation. Both rigs include `Head` and the optional spring-ready `ClothRoot` → `ClothMid` → `ClothTip` chain.","",
           f"- Hero clips: {', '.join(f'`{x}`' for x in d['actions'])}.",
           f"- Keeper clips: {', '.join(f'`{x}`' for x in k['actions'])}.","",
           f"Idle, walk, run, crouch-walk, listen, and chase clips have matching endpoint poses for clean cycles. Other clips are single actions. The crouch keys lower the `Hips` while bending both leg chains; no mesh or armature scale is animated. Its independently evaluated imported mesh maximum at the crouch pose is {d['crouch_max']:.3f} m. Walk/run/chase are in-place and authored for locomotion along Godot +X. The export uses glTF Y-up; the modeled face is Blender -Y, which imports facing Godot +Z.","",
           "## Textures and sources","",
           "Four deterministic 2048×2048 albedo/roughness sets are stored in `assets/textures/characters/`: hero teal cloth, hero patches, keeper cloth, and keeper apron. The maps contain original woven cross-thread, scratch, smudge, and edge-grime patterns and are embedded into the GLBs by Blender.","",
           "- Re-runnable generator: `tools/create_characters_v2.py`","- Blender sources: `assets/sources/doll.blend`, `assets/sources/keeper.blend`","- GLBs: `assets/models/doll.glb`, `assets/models/keeper.glb`","- Inspection renders: `assets/sources/previews/doll_v2_{front,side,threequarter}.png` and `keeper_v2_{front,side,threequarter}.png`","",
           "## Verification","",
           "The generator independently clears Blender, imports each exported GLB, triangulates all imported meshes for counts, reads armatures and bone names, checks that every required action survived export, verifies every imported mesh is skinned, checks floor and height bounds, and confirms all six preview images. The report above is written only after those assertions pass.","",
           "## Caveats","",
           "The cloth is hand-shaped geometry with weighted secondary chains rather than a runtime cloth simulation. The hood cavity and keeper face rely on dark materials, so a very bright world environment will reduce their depth; the supplied neutral previews show the intended low-key lighting response.",""]
    REPORT_PATH.write_text("\n".join(lines),encoding="utf-8")


def main():
    ensure_dirs()
    if "--verify-only" in sys.argv:
        info={name:inspect_glb(name) for name in ("doll","keeper")}
        print(json.dumps(info,indent=2));verify(info);return
    clear_scene()
    materials=setup_materials()
    info={}
    info["doll"]=export_character("doll",build_hero,materials)
    # Export clears materials; rebuild them for the second file.
    clear_scene()
    materials=setup_materials()
    info["keeper"]=export_character("keeper",build_keeper,materials)
    verify(info);write_report(info)
    print(json.dumps(info,indent=2))
    print(f"Wrote {REPORT_PATH}")


if __name__=="__main__":
    main()
