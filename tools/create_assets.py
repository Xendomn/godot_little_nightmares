"""Generate original low-poly Midnight Workshop models and synthesized audio.

Run with:
    blender.exe --background --python tools/create_assets.py

The script uses only Blender's Python API and the Python standard library.
"""

from __future__ import annotations

import json
import math
import random
import struct
import sys
import wave
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[1]
MODEL_DIR = ROOT / "assets" / "models"
AUDIO_DIR = ROOT / "assets" / "audio"
SOURCE_DIR = ROOT / "assets" / "sources"
REPORT_PATH = ROOT / "docs" / "assets-report.md"
SAMPLE_RATE = 44_100

PALETTE = {
    "teal": ((0.035, 0.27, 0.29, 1.0), 0.72, 0.0),
    "teal_light": ((0.08, 0.52, 0.50, 1.0), 0.58, 0.0),
    "wood": ((0.30, 0.14, 0.055, 1.0), 0.78, 0.0),
    "wood_light": ((0.50, 0.28, 0.10, 1.0), 0.70, 0.0),
    "brass": ((0.45, 0.25, 0.055, 1.0), 0.38, 0.66),
    "iron": ((0.035, 0.045, 0.05, 1.0), 0.62, 0.55),
    "cloth_dark": ((0.045, 0.06, 0.065, 1.0), 0.92, 0.0),
    "ivory": ((0.47, 0.43, 0.33, 1.0), 0.88, 0.0),
    "thread": ((0.015, 0.018, 0.019, 1.0), 0.9, 0.0),
}


def ensure_dirs() -> None:
    for directory in (MODEL_DIR, AUDIO_DIR, SOURCE_DIR, REPORT_PATH.parent):
        directory.mkdir(parents=True, exist_ok=True)
    (SOURCE_DIR / ".gdignore").write_text(
        "# Keep Blender source files out of Godot's importer.\n", encoding="utf-8"
    )


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def make_material(name: str, color, roughness=0.7, metallic=0.0, emission=None, strength=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission is not None:
        emission_input = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        if emission_input:
            emission_input.default_value = emission
        strength_input = bsdf.inputs.get("Emission Strength")
        if strength_input:
            strength_input.default_value = strength
    return mat


def materials():
    result = {}
    for key, (color, roughness, metallic) in PALETTE.items():
        result[key] = make_material(key.title(), color, roughness, metallic)
    result["glow_teal"] = make_material(
        "GlowTeal", (0.02, 0.31, 0.30, 1.0), 0.32, 0.08,
        emission=(0.03, 0.95, 0.84, 1.0), strength=5.0,
    )
    result["lamp"] = make_material(
        "LampAmber", (0.50, 0.20, 0.025, 1.0), 0.28, 0.16,
        emission=(1.0, 0.28, 0.025, 1.0), strength=4.5,
    )
    return result


def finish_object(obj, name, mat, scale=None, rotation=None, bevel=0.0):
    obj.name = name
    if scale is not None:
        obj.scale = scale
    if rotation is not None:
        obj.rotation_euler = rotation
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if mat:
        obj.data.materials.append(mat)
    if bevel > 0:
        modifier = obj.modifiers.new("Softened low-poly edges", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
    obj.select_set(False)
    return obj


def cube(name, location, scale, mat, rotation=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=location)
    return finish_object(bpy.context.object, name, mat, scale, rotation, bevel)


def sphere(name, location, scale, mat, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1.0, location=location)
    return finish_object(bpy.context.object, name, mat, scale)


def cylinder(name, location, radius, depth, mat, rotation=(0, 0, 0), vertices=12, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    return finish_object(bpy.context.object, name, mat, None, rotation, bevel)


def cone(name, location, radius1, radius2, depth, mat, rotation=(0, 0, 0), vertices=12, bevel=0.0):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius1, radius2=radius2, depth=depth, location=location
    )
    return finish_object(bpy.context.object, name, mat, None, rotation, bevel)


def torus(name, location, major_radius, minor_radius, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major_radius, minor_radius=minor_radius,
        major_segments=16, minor_segments=6, location=location, rotation=rotation,
    )
    return finish_object(bpy.context.object, name, mat)


def parent_keep_world(obj, parent):
    matrix = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = matrix


def set_origin(obj, point):
    previous = bpy.context.scene.cursor.location.copy()
    bpy.context.scene.cursor.location = point
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR", center="MEDIAN")
    obj.select_set(False)
    bpy.context.scene.cursor.location = previous


def add_stitch(name, location, length, angle, parent, mat):
    stitch = cube(name, location, (length, 0.012, 0.012), mat, rotation=(0, angle, 0), bevel=0.004)
    parent_keep_world(stitch, parent)
    return stitch


def build_doll(m):
    body = cone("Body", (0, 0, 0.59), 0.245, 0.185, 0.58, m["teal"], vertices=10, bevel=0.025)
    head = sphere("Head", (0, -0.008, 1.015), (0.315, 0.245, 0.235), m["teal_light"], 2)
    parent_keep_world(head, body)

    arm_l = cone("ArmL", (-0.235, 0, 0.59), 0.065, 0.045, 0.43, m["teal"],
                 rotation=(0, -0.18, -0.06), vertices=8, bevel=0.015)
    arm_r = cone("ArmR", (0.235, 0, 0.59), 0.065, 0.045, 0.43, m["teal"],
                 rotation=(0, 0.18, 0.06), vertices=8, bevel=0.015)
    set_origin(arm_l, (-0.19, 0, 0.79)); set_origin(arm_r, (0.19, 0, 0.79))
    parent_keep_world(arm_l, body); parent_keep_world(arm_r, body)
    for side, x in (("L", -0.27), ("R", 0.27)):
        hand = sphere(f"Hand{side}", (x, -0.005, 0.385), (0.066, 0.052, 0.06), m["ivory"], 1)
        parent_keep_world(hand, arm_l if side == "L" else arm_r)

    leg_l = cone("LegL", (-0.105, 0, 0.21), 0.075, 0.055, 0.34, m["cloth_dark"], vertices=8, bevel=0.012)
    leg_r = cone("LegR", (0.105, 0, 0.21), 0.075, 0.055, 0.34, m["cloth_dark"], vertices=8, bevel=0.012)
    set_origin(leg_l, (-0.105, 0, 0.36)); set_origin(leg_r, (0.105, 0, 0.36))
    parent_keep_world(leg_l, body); parent_keep_world(leg_r, body)
    for side, x in (("L", -0.105), ("R", 0.105)):
        foot = sphere(f"Foot{side}", (x + 0.018, -0.045, 0.07), (0.115, 0.15, 0.07), m["wood"], 1)
        parent_keep_world(foot, leg_l if side == "L" else leg_r)

    # Button eyes and crossed stitch smile sit on the Blender -Y face.
    for side, x in (("L", -0.105), ("R", 0.105)):
        eye = cylinder(f"ButtonEye{side}", (x, -0.238, 1.055), 0.058, 0.028, m["iron"],
                       rotation=(math.pi / 2, 0, 0), vertices=12, bevel=0.006)
        parent_keep_world(eye, head)
        for dx, dz in ((-0.017, -0.017), (0.017, 0.017)):
            hole = sphere(f"ButtonHole{side}", (x + dx, -0.257, 1.055 + dz), (0.007, 0.006, 0.007), m["ivory"], 1)
            parent_keep_world(hole, head)
    for index, (x, z, angle) in enumerate(((-0.075, 0.95, -0.35), (0, 0.935, 0.3), (0.075, 0.95, -0.35))):
        add_stitch(f"MouthStitch{index}", (x, -0.249, z), 0.052, angle, head, m["thread"])
    for index, z in enumerate((0.86, 0.82, 0.78)):
        add_stitch(f"FaceSeam{index}", (0.235, -0.13, z), 0.045, 0.9, head, m["thread"])

    scarf = torus("ScarfKnot", (0, 0, 0.815), 0.205, 0.035, m["wood_light"])
    parent_keep_world(scarf, body)
    tail = cube("ScarfTail", (0.20, 0.055, 0.66), (0.055, 0.025, 0.22), m["wood_light"],
                rotation=(0.15, 0.28, -0.18), bevel=0.018)
    parent_keep_world(tail, body)


def build_keeper(m):
    body = cone("Body", (0, 0, 2.03), 0.29, 0.20, 1.18, m["wood"], vertices=8, bevel=0.025)
    chest = cube("ChestCage", (0, 0, 2.35), (0.36, 0.18, 0.25), m["wood_light"], bevel=0.035)
    parent_keep_world(chest, body)
    apron = cube("DarkApron", (0, -0.21, 1.92), (0.32, 0.035, 0.60), m["cloth_dark"], bevel=0.02)
    parent_keep_world(apron, body)
    for i, z in enumerate((1.50, 1.72, 1.94, 2.16, 2.38)):
        slat = cube(f"ApronBar{i}", (0, -0.252, z), (0.30, 0.014, 0.022), m["iron"], bevel=0.005)
        parent_keep_world(slat, apron)

    head = sphere("Head", (0, -0.01, 3.11), (0.36, 0.25, 0.47), m["ivory"], 2)
    parent_keep_world(head, body)
    brow = cube("MaskBrow", (0, -0.248, 3.25), (0.29, 0.035, 0.07), m["wood"], bevel=0.025)
    parent_keep_world(brow, head)
    jaw = cone("MaskJaw", (0, -0.225, 2.88), 0.20, 0.29, 0.40, m["wood_light"], vertices=8, bevel=0.02)
    parent_keep_world(jaw, head)
    for side, x in (("L", -0.135), ("R", 0.135)):
        socket = torus(f"EyeSocket{side}", (x, -0.27, 3.20), 0.075, 0.018, m["iron"], rotation=(math.pi / 2, 0, 0))
        lamp = sphere(f"LampEye{side}", (x, -0.285, 3.20), (0.046, 0.025, 0.046), m["lamp"], 2)
        parent_keep_world(socket, head); parent_keep_world(lamp, head)
    nose = cone("MaskNose", (0, -0.37, 3.08), 0.06, 0.015, 0.30, m["brass"],
                rotation=(math.pi / 2, 0, 0), vertices=8)
    parent_keep_world(nose, head)
    top_gear = torus("CrownGear", (0, 0, 3.53), 0.18, 0.035, m["brass"])
    parent_keep_world(top_gear, head)

    for side, x, tilt in (("L", -0.39, -0.07), ("R", 0.39, 0.07)):
        arm = cone(f"Arm{side}", (x, 0, 1.67), 0.07, 0.105, 1.67, m["wood_light"],
                   rotation=(0, tilt, 0), vertices=8, bevel=0.018)
        set_origin(arm, (x * 0.72, 0, 2.51))
        parent_keep_world(arm, body)
        shoulder = sphere(f"Shoulder{side}", (x * 0.72, 0, 2.51), (0.14, 0.14, 0.14), m["brass"], 1)
        hand = sphere(f"Claw{side}", (x * 1.15, -0.02, 0.77), (0.13, 0.10, 0.19), m["iron"], 1)
        parent_keep_world(shoulder, body); parent_keep_world(hand, arm)
    for side, x in (("L", -0.14), ("R", 0.14)):
        leg = cone(f"Leg{side}", (x, 0, 0.78), 0.075, 0.105, 1.45, m["wood_light"], vertices=8, bevel=0.014)
        set_origin(leg, (x, 0, 1.50)); parent_keep_world(leg, body)
        knee = sphere(f"Knee{side}", (x, 0, 0.88), (0.13, 0.13, 0.13), m["brass"], 1)
        foot = cube(f"Foot{side}", (x + 0.07, -0.06, 0.09), (0.16, 0.25, 0.09), m["iron"], bevel=0.035)
        parent_keep_world(knee, leg); parent_keep_world(foot, leg)


def build_crate(m):
    body = cube("Body", (0, 0, 0.525), (0.425, 0.425, 0.465), m["wood"], bevel=0.025)
    for side_x in (-0.445, 0.445):
        for side_y in (-0.445, 0.445):
            post = cube(f"Corner_{side_x}_{side_y}", (side_x, side_y, 0.525), (0.055, 0.055, 0.525), m["wood_light"], bevel=0.012)
            parent_keep_world(post, body)
    for index, (z, axis) in enumerate(((0.08, "x"), (0.97, "x"), (0.08, "y"), (0.97, "y"))):
        if axis == "x":
            slat = cube(f"Frame{index}", (0, -0.455 if index < 2 else 0.455, z), (0.475, 0.035, 0.06), m["brass"], bevel=0.008)
        else:
            slat = cube(f"Frame{index}", (-0.455 if index < 3 else 0.455, 0, z), (0.035, 0.475, 0.06), m["brass"], bevel=0.008)
        parent_keep_world(slat, body)
    for face_y, suffix in ((-0.466, "Front"), (0.466, "Back")):
        for diagonal, angle in (("A", math.radians(41)), ("B", -math.radians(41))):
            slat = cube(f"Cross{suffix}{diagonal}", (0, face_y, 0.525), (0.60, 0.028, 0.055), m["wood_light"],
                        rotation=(0, angle, 0), bevel=0.012)
            parent_keep_world(slat, body)


def build_fuse(m):
    body = cylinder("Body", (0, 0, 0.035), 0.115, 0.07, m["iron"], vertices=12, bevel=0.012)
    core = cylinder("Core", (0, 0, 0.16), 0.047, 0.20, m["glow_teal"], vertices=12, bevel=0.012)
    cap = cylinder("BrassCap", (0, 0, 0.275), 0.09, 0.05, m["brass"], vertices=12, bevel=0.01)
    ring = torus("GripRing", (0, 0, 0.19), 0.075, 0.012, m["brass"])
    for obj in (core, cap, ring): parent_keep_world(obj, body)


def build_train(m):
    body = cube("Body", (0.10, 0, 0.36), (0.55, 0.32, 0.19), m["wood"], bevel=0.05)
    boiler = cylinder("Boiler", (0.28, 0, 0.59), 0.205, 0.68, m["teal"], rotation=(0, math.pi / 2, 0), vertices=12, bevel=0.018)
    cab = cube("Cab", (-0.36, 0, 0.56), (0.25, 0.30, 0.24), m["wood_light"], bevel=0.035)
    roof = cube("CabRoof", (-0.36, 0, 0.79), (0.31, 0.36, 0.04), m["iron"], bevel=0.025)
    chimney = cone("Chimney", (0.46, 0, 0.705), 0.11, 0.075, 0.25, m["iron"], vertices=12, bevel=0.012)
    nose = cylinder("Smokebox", (0.64, 0, 0.59), 0.215, 0.10, m["brass"], rotation=(0, math.pi / 2, 0), vertices=12)
    cowcatcher = cone("Cowcatcher", (0.81, 0, 0.24), 0.25, 0.10, 0.64, m["brass"], rotation=(0, math.pi / 2, 0), vertices=8)
    for obj in (boiler, cab, roof, chimney, nose, cowcatcher): parent_keep_world(obj, body)
    for i, x in enumerate((-0.35, 0.05, 0.43)):
        for side, y in (("L", -0.35), ("R", 0.35)):
            wheel = cylinder(f"Wheel{side}{i}", (x, y, 0.22), 0.19 if i < 2 else 0.15, 0.09, m["iron"],
                             rotation=(math.pi / 2, 0, 0), vertices=12, bevel=0.012)
            hub = cylinder(f"Hub{side}{i}", (x, y * 1.035, 0.22), 0.065, 0.105, m["brass"],
                           rotation=(math.pi / 2, 0, 0), vertices=12)
            parent_keep_world(wheel, body); parent_keep_world(hub, wheel)


def build_spool(m):
    body = cylinder("Body", (0, 0, 0.35), 0.205, 0.56, m["wood"], vertices=16, bevel=0.018)
    bottom = cylinder("BottomFlange", (0, 0, 0.055), 0.39, 0.11, m["wood_light"], vertices=16, bevel=0.025)
    top = cylinder("TopFlange", (0, 0, 0.645), 0.39, 0.11, m["wood_light"], vertices=16, bevel=0.025)
    for obj in (bottom, top): parent_keep_world(obj, body)
    for i, z in enumerate((0.16, 0.22, 0.28, 0.34, 0.40, 0.46, 0.52)):
        thread = torus(f"ThreadCoil{i}", (0, 0, z), 0.24 + 0.008 * (i % 2), 0.026, m["teal"])
        parent_keep_world(thread, body)
    peg = cylinder("BrassPeg", (0, 0, 0.69), 0.055, 0.025, m["brass"], vertices=12)
    parent_keep_world(peg, top)


BUILDERS = {
    "doll": build_doll,
    "keeper": build_keeper,
    "crate": build_crate,
    "fuse": build_fuse,
    "toy_train": build_train,
    "spool": build_spool,
}


def export_asset(name, builder):
    clear_scene()
    scene_mats = materials()
    builder(scene_mats)
    bpy.context.scene.world.color = (0.015, 0.015, 0.02)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_DIR / f"{name}.blend"), check_existing=False)
    bpy.ops.export_scene.gltf(
        filepath=str(MODEL_DIR / f"{name}.glb"),
        export_format="GLB",
        export_yup=True,
        export_materials="EXPORT",
        export_apply=True,
    )
    render_preview(name)


def render_preview(name):
    """Render a source-side preview without adding helpers to the GLB or saved source."""
    preview_dir = SOURCE_DIR / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    center = (minimum + maximum) * 0.5
    span = max(maximum.x - minimum.x, maximum.y - minimum.y, maximum.z - minimum.z)

    bpy.ops.object.camera_add(location=(center.x + span * 1.35, center.y - span * 2.8, center.z + span * 0.85))
    camera = bpy.context.object
    camera.name = "PreviewCamera"
    camera.data.lens = 62
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = camera

    ground_mat = make_material("PreviewGround", (0.018, 0.022, 0.025, 1.0), 0.82, 0.05)
    bpy.ops.mesh.primitive_plane_add(size=span * 6, location=(center.x, center.y, minimum.z - 0.006))
    bpy.context.object.data.materials.append(ground_mat)
    for location, energy, color, size in (
        ((center.x - span, center.y - span * 1.5, center.z + span * 2), 850, (0.32, 0.68, 0.72), span * 2),
        ((center.x + span * 1.4, center.y - span * .4, center.z + span), 600, (1.0, 0.44, 0.18), span),
        ((center.x, center.y + span * 1.2, center.z + span * 1.4), 1050, (0.15, 0.38, 0.42), span * 1.5),
    ):
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(preview_dir / f"{name}.png")
    scene.render.film_transparent = False
    scene.world.color = (0.008, 0.012, 0.015)
    bpy.ops.render.render(write_still=True)


def soft_clip(value):
    return math.tanh(value * 1.15) / math.tanh(1.15)


def write_wav(name, samples, peak=0.58):
    maximum = max(max(abs(sample) for sample in samples), 1e-9)
    gain = peak / maximum
    pcm = [int(max(-1.0, min(1.0, soft_clip(sample * gain))) * 32767) for sample in samples]
    path = AUDIO_DIR / name
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        wav.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))


def periodic_tone(duration, components):
    count = int(duration * SAMPLE_RATE)
    out = [0.0] * count
    for i in range(count):
        t = i / SAMPLE_RATE
        out[i] = sum(amp * math.sin(2 * math.pi * (cycles / duration) * t + phase)
                     for cycles, amp, phase in components)
    return out


def add_bell(samples, start, freq, amp, decay=2.7):
    start_i = int(start * SAMPLE_RATE)
    max_i = min(len(samples), start_i + int(1.8 * SAMPLE_RATE))
    for i in range(start_i, max_i):
        t = (i - start_i) / SAMPLE_RATE
        env = (1.0 - math.exp(-55 * t)) * math.exp(-decay * t)
        value = math.sin(2 * math.pi * freq * t) + 0.33 * math.sin(2 * math.pi * freq * 2.01 * t)
        samples[i] += amp * env * value


def add_click(samples, start, amp=0.25, length=0.045, seed=0):
    rng = random.Random(seed)
    start_i = int(start * SAMPLE_RATE)
    end_i = min(len(samples), start_i + int(length * SAMPLE_RATE))
    previous = 0.0
    for i in range(start_i, end_i):
        t = (i - start_i) / SAMPLE_RATE
        raw = rng.uniform(-1, 1)
        previous = previous * 0.62 + raw * 0.38
        samples[i] += amp * previous * math.exp(-70 * t)


def synth_audio():
    ambient = periodic_tone(12.0, ((324, .18, 0), (492, .09, .4), (756, .04, 1.1), (7, .035, .7)))
    for n, when in enumerate((1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5)):
        add_click(ambient, when, .13, .05, 100 + n)
    for when, note in ((2.0, 220), (5.0, 261.63), (8.0, 246.94)):
        add_bell(ambient, when, note, .055, 3.5)
    write_wav("ambient.wav", ambient, .43)

    chase = periodic_tone(8.0, ((520, .19, 0), (792, .11, .2), (1056, .07, 1.4), (16, .05, .6)))
    for n in range(16):
        add_click(chase, .25 + n * .5, .22 if n % 2 == 0 else .15, .035, 300 + n)
    for when, note in ((1.0, 293.66), (3.0, 329.63), (5.0, 349.23), (7.0, 329.63)):
        add_bell(chase, when, note, .08, 4.5)
    write_wav("chase.wav", chase, .52)

    def one_shot(duration, generator, peak):
        values = []
        for i in range(int(duration * SAMPLE_RATE)):
            t = i / SAMPLE_RATE
            attack = min(1.0, t * 400.0)
            values.append(generator(t, i) * attack)
        values[-1] = 0.0
        return values, peak

    rng_step = random.Random(31)
    step, p = one_shot(.34, lambda t, i: math.exp(-16*t) * (
        .60*math.sin(2*math.pi*(78-32*t)*t) + .30*rng_step.uniform(-1, 1)), .48)
    write_wav("step.wav", step, p)

    rng_push = random.Random(41)
    push, p = one_shot(.80, lambda t, i: math.exp(-4.5*t) * (
        .55*math.sin(2*math.pi*(48+9*math.sin(12*t))*t) + .20*rng_push.uniform(-1, 1)), .50)
    write_wav("push.wav", push, p)

    pickup, p = one_shot(.58, lambda t, i: math.exp(-5*t) * (1-math.exp(-40*t)) * (
        .45*math.sin(2*math.pi*(330+480*t)*t) + .20*math.sin(2*math.pi*660*t)), .47)
    write_wav("pickup.wav", pickup, p)

    rng_switch = random.Random(51)
    switch, p = one_shot(.42, lambda t, i: math.exp(-13*t) * (
        .36*math.sin(2*math.pi*118*t) + .31*rng_switch.uniform(-1, 1)), .50)
    write_wav("switch.wav", switch, p)

    caught, p = one_shot(1.55, lambda t, i: (1-math.exp(-25*t))*math.exp(-1.8*t) * (
        .46*math.sin(2*math.pi*(135-38*t)*t) + .24*math.sin(2*math.pi*(203-55*t)*t)), .54)
    write_wav("caught.wav", caught, p)

    win = [0.0] * int(2.5 * SAMPLE_RATE)
    for when, note in ((0.05, 261.63), (.42, 329.63), (.79, 392.0), (1.20, 523.25)):
        add_bell(win, when, note, .25, 2.3)
    fade_start = len(win) - int(0.35 * SAMPLE_RATE)
    fade_span = len(win) - 1 - fade_start
    for i in range(fade_start, len(win)):
        win[i] *= max(0.0, (len(win) - 1 - i) / fade_span)
    write_wav("win.wav", win, .50)


def inspect_glb(name):
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(MODEL_DIR / f"{name}.glb"))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    points = []
    for obj in meshes:
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    minimum = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    maximum = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    dimensions = maximum - minimum
    return {
        "objects": sorted(obj.name for obj in meshes),
        "min": [round(value, 4) for value in minimum],
        "max": [round(value, 4) for value in maximum],
        "dimensions": [round(value, 4) for value in dimensions],
    }


def audio_info(path):
    with wave.open(str(path), "rb") as wav:
        frames = wav.getnframes()
        return {"duration": frames / wav.getframerate(), "rate": wav.getframerate(), "channels": wav.getnchannels()}


def audio_metrics(path):
    with wave.open(str(path), "rb") as wav:
        raw = wav.readframes(wav.getnframes())
        count = wav.getnframes()
        values = struct.unpack(f"<{count}h", raw)
        return {
            "channels": wav.getnchannels(),
            "bits": wav.getsampwidth() * 8,
            "rate": wav.getframerate(),
            "duration": round(count / wav.getframerate(), 3),
            "peak": round(max(abs(value) for value in values) / 32767, 4),
            "rms": round(math.sqrt(sum(value * value for value in values) / count) / 32767, 4),
            "boundary_jump": round(abs(values[0] - values[-1]) / 32767, 6),
            "bytes": path.stat().st_size,
        }


def verify_existing():
    model_info = {name: inspect_glb(name) for name in BUILDERS}
    audio_names = ("ambient", "chase", "step", "push", "pickup", "switch", "caught", "win")
    result = {
        "models": {
            name: {
                "glb_bytes": (MODEL_DIR / f"{name}.glb").stat().st_size,
                "glb_magic": (MODEL_DIR / f"{name}.glb").read_bytes()[:4].decode("ascii"),
                "blend_bytes": (SOURCE_DIR / f"{name}.blend").stat().st_size,
                "preview_bytes": (SOURCE_DIR / "previews" / f"{name}.png").stat().st_size,
                **model_info[name],
            }
            for name in BUILDERS
        },
        "audio": {name: audio_metrics(AUDIO_DIR / f"{name}.wav") for name in audio_names},
        "report_bytes": REPORT_PATH.stat().st_size,
        "script_bytes": Path(__file__).stat().st_size,
    }
    assert all(info["glb_magic"] == "glTF" for info in result["models"].values())
    required = {"Body", "Head", "ArmL", "ArmR", "LegL", "LegR"}
    for character in ("doll", "keeper"):
        assert required.issubset(result["models"][character]["objects"])
    assert result["audio"]["ambient"]["duration"] == 12.0
    assert result["audio"]["chase"]["duration"] == 8.0
    assert all(
        info["channels"] == 1 and info["bits"] == 16 and info["rate"] == SAMPLE_RATE and info["peak"] < 0.8
        for info in result["audio"].values()
    )
    assert result["audio"]["ambient"]["boundary_jump"] < 0.01
    assert result["audio"]["chase"]["boundary_jump"] < 0.01
    assert not list(SOURCE_DIR.glob("*.blend1"))
    print(json.dumps(result, indent=2))


def write_report(model_info):
    lines = [
        "# Original asset generation report", "",
        "All assets in this set are original procedural constructions. The models use Blender primitives and custom materials; the WAV files are entirely synthesized by `tools/create_assets.py` with Python's standard library. No external or copyrighted asset data is used.", "",
        "## Models", "",
        "Blender 5.2.1 LTS generated the source `.blend` files and exported binary glTF with `export_yup=True`. Geometry is authored Z-up. Character facial details are placed on Blender −Y, and the gameplay locomotion axis is Godot +X. Origins are at ground level in the exported scenes; character limb object origins are moved to shoulder/hip pivots before parenting.", "",
        "| Asset | GLB size | Imported bounds (X × Y × Z) | Imported minimum | Mesh objects |", "|---|---:|---:|---:|---:|",
    ]
    for name, info in model_info.items():
        size = (MODEL_DIR / f"{name}.glb").stat().st_size
        dims = " × ".join(f"{v:.3f}" for v in info["dimensions"])
        mins = ", ".join(f"{v:.3f}" for v in info["min"])
        lines.append(f"| `{name}.glb` | {size:,} B | {dims} | {mins} | {len(info['objects'])} |")
    lines.extend(["", "Object names verified after importing each GLB:", ""])
    for name, info in model_info.items():
        lines.append(f"- **{name}:** " + ", ".join(f"`{obj}`" for obj in info["objects"]))
    lines.extend(["", "## Audio", "", "| Asset | Duration | Format | Size |", "|---|---:|---|---:|"])
    for filename in ("ambient.wav", "chase.wav", "step.wav", "push.wav", "pickup.wav", "switch.wav", "caught.wav", "win.wav"):
        path = AUDIO_DIR / filename
        info = audio_info(path)
        lines.append(f"| `{filename}` | {info['duration']:.2f} s | mono, 16-bit PCM, {info['rate']:,} Hz | {path.stat().st_size:,} B |")
    lines.extend([
        "", "The 12-second ambient and 8-second chase beds use periodic low machinery tones whose frequencies complete whole cycles at the loop boundary. Bell events and mechanical ticks decay before the boundary. One-shots begin and end under controlled envelopes. Every file is peak-normalized below full scale and soft-clipped to avoid harsh digital peaks.",
        "", "## Verification", "",
        "- Blender completed all six `.blend` saves and six GLB exports without errors.",
        "- Every GLB was cleared from the scene, re-imported, and inspected independently.",
        "- `doll.glb` and `keeper.glb` contain `Body`, `Head`, `ArmL`, `ArmR`, `LegL`, and `LegR` mesh nodes.",
        "- Imported bounds have their lowest point at or near Z=0; decorative bevels may extend a few millimetres below the nominal floor.",
        "- WAV headers, channel count, sample rate, durations, and non-empty sizes were read back with the standard `wave` module.",
        "", "## Concerns", "",
        "Godot may uniquify a node name only if an importer or inherited scene adds a collision; the raw GLBs import with the names listed above. Animation pivots are stored on character limb nodes, but no armature or baked animation is included because gameplay drives the limbs procedurally. Emission appearance depends on the Godot environment's glow settings.", "",
    ])
    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")


def main():
    ensure_dirs()
    if "--verify-only" in sys.argv:
        verify_existing()
        return
    for name, builder in BUILDERS.items():
        print(f"[Midnight Workshop] Building {name}")
        export_asset(name, builder)
    synth_audio()
    inspection = {name: inspect_glb(name) for name in BUILDERS}
    required = {"Body", "Head", "ArmL", "ArmR", "LegL", "LegR"}
    for character in ("doll", "keeper"):
        missing = required.difference(inspection[character]["objects"])
        if missing:
            raise RuntimeError(f"{character} is missing required nodes: {sorted(missing)}")
    write_report(inspection)
    print(json.dumps(inspection, indent=2))
    print(f"[Midnight Workshop] Wrote {REPORT_PATH}")


if __name__ == "__main__":
    main()
