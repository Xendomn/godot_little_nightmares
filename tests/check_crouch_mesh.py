"""Evaluate exported skin vertices, not rest boxes. Run with Blender --python."""
import bpy
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def measure():
    arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH' and any(m.type == 'ARMATURE' for m in o.modifiers)]
    arm.animation_data_create()
    expected = {'idle', 'walk', 'run', 'jump', 'fall', 'land', 'crouch', 'crouch_walk', 'push', 'pickup', 'interact', 'caught'}
    assert set(a.name for a in bpy.data.actions) == expected
    assert all(abs(s-1) < 1e-6 for o in [arm, *meshes] for s in o.scale)
    for track in arm.animation_data.nla_tracks:
        track.mute = True
    result = {}
    for name in ('crouch', 'crouch_walk', 'pickup'):
        action = bpy.data.actions[name]
        arm.animation_data.action = action
        bounds = []
        for frame in range(math.floor(action.frame_range[0]), math.ceil(action.frame_range[1]) + 1):
            bpy.context.scene.frame_set(frame)
            deps = bpy.context.evaluated_depsgraph_get()
            assert arm.pose.bones['Root'].location.length < 1e-6
            assert all(abs(s-1) < 1e-4 for pb in arm.pose.bones for s in pb.scale)
            points = [(o.name, (o.evaluated_get(deps).matrix_world @ v.co).z) for o in meshes for v in o.evaluated_get(deps).data.vertices]
            low = min(points, key=lambda p: p[1])
            high = max(points, key=lambda p: p[1])
            boots = {side: min(z for obj, z in points if obj.startswith('Boot_' + side)) for side in ('L', 'R')}
            bounds.append({'frame': frame, 'min': low[1], 'max': high[1], 'lowest': low[0], 'highest': high[0], 'boot_min': boots})
        result[name] = bounds
    arm.animation_data.action = None
    return result


def verify(result):
    failures = []
    for name, frames in result.items():
        for b in frames:
            if b['min'] < -.002 or (name != 'pickup' and b['max'] > .66):
                failures.append(f'{name}: {b}')
            if any(abs(z-.004) > .002 for z in b['boot_min'].values()):
                failures.append(f'{name} boots not planted: {b}')
    assert not failures, '\n'.join(failures)


if __name__ == '__main__':
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.render.fps = 30
    bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/models/doll.glb'))
    result = measure()
    print(json.dumps(result, indent=2))
    verify(result)
    print('PASS: all exported frames grounded; crouch clips <= 0.66m; feet planted; 12 clips; Root zero; scale one.')
