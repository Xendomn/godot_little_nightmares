# Grounded hero crouch deformation

The previous exported crouch ended with repair/stitch vertices at approximately -0.512 m, despite its maximum being only 0.642 m. Its first frame was standing at 1.400 m. The old maximum-only check therefore accepted a model buried below the floor. Pickup inherited the same defect.

The corrected pose lowers the pelvis by 0.26 m, folds the spine forward by 95 degrees, and counter-rotates the head by 85 degrees to retain the forward-facing hood. Analytic two-link leg posing bends the knees while retaining both ankle positions and boot orientations. Root remains at zero and neither objects nor bones receive authored scale keys. Standing mesh vertices and all twelve clip names are preserved.

The cloak now uses a continuous height-based Root/Hips/Spine/Chest weight field, also applied to its sewn repairs and stitches. The independent rear cloth chain is rooted at Root so its existing pointed panels do not inherit the pelvis drop. Crouch is a stable, already-low idle; crouch_walk uses the same pose with a small alternating 1 cm ankle shuffle. Pickup bakes the grounded leg solve at every frame instead of interpolating two distant poses through the floor.

## Reproduce

```powershell
blender --background --python-exit-code 1 --python tools/create_characters_v2.py -- --hero-only
blender --background --python-exit-code 1 --python tests/check_crouch_mesh.py
```

`--hero-only` preserves keeper outputs and the original two-character report. `--skip-previews` skips rendering during iteration. The generator's imported-GLB inspection now calls the same per-frame regression checks. Tests set the import rate to 30 fps to evaluate every exported sample, including the last frame.

## Measured exported mesh bounds

Blender 5.2.1 independently imported `assets/models/doll.glb` and evaluated every skinned visible vertex in every frame:

| Clip | Frames | Minimum Z (m) | Maximum Z (m) |
|---|---:|---:|---:|
| crouch | 24 | 0.0040000 | 0.6514944 |
| crouch_walk | 24 | 0.00399999 | 0.6514944 |
| pickup | 26 | 0.00399991 | 1.3999404 |

The regression passed with a 2 mm floor tolerance and a strict 0.66 m ceiling for both crouch clips. It also checks planted boot minima, the twelve exported clips, stationary Root, and unit object/bone scale (allowing 0.0001 floating-point decomposition error for imported bone scale).

Front and side visual inspection: `assets/sources/previews/doll_v2_crouch_front.png` and `doll_v2_crouch_side.png`; a three-quarter view is retained as well. The face remains forward, boots contact the ground, and the cloak has a continuous folded silhouette. Existing pointed tail panels remain part of the original design. This is weighted cloth, not simulated cloth; minor layering intersections can remain in the very compressed pose. Runtime collider transitions and Godot import are validated separately from this mesh regression.
