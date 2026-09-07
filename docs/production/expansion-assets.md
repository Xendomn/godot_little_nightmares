# Expansion asset ledger

23 original Blender assemblies authored for the full campaign. Source geometry uses Blender Z up and -Y front, exported as Godot Y up and +Z front. All models have their feet at local Y=0. Runtime collision shapes are supplied by gameplay scenes.

Generator: `blender -b --python tools/create_expansion_kit.py`. Every model was rendered and independently reimported in Blender 5.2.1; all meshes have UVs and all documented pivot nodes survived. Contact sheet: `assets/sources/expansion/previews/contactsheet.png`.

| Asset | Godot width × height × depth (m) | Triangles | Moving nodes |
|---|---|---:|---|
| arch | 4.16 × 5.0043 × 0.685 | 3192 | — |
| wall_panel | 4.0 × 5.0 × 0.295 | 1672 | — |
| floor_panel | 3.98 × 0.207 × 3.0 | 1232 | — |
| ladder | 0.88 × 3.0 × 0.355 | 3488 | — |
| cargo_basket | 2.1133 × 1.3 × 1.725 | 3672 | — |
| gate | 2.8 × 3.0 × 0.323 | 1780 | Gate |
| conveyor | 4.0 × 0.62 × 1.71 | 6328 | Rollers |
| press | 2.4 × 3.4 × 1.5 | 2132 | Ram |
| generator | 1.8 × 1.495 × 1.2577 | 6400 | Rotor |
| selector | 0.8 × 1.3 × 0.61 | 844 | Lever |
| tank | 3.2443 × 2.6 × 2.075 | 1212 | — |
| valve | 0.8 × 1.28 × 0.6 | 1064 | Rotor |
| floating_crate | 1.03 × 0.95 × 1.075 | 3672 | — |
| rack | 2.6 × 3.4 × 0.85 | 1036 | — |
| winch | 0.8 × 1.28 × 0.725 | 4904 | Rotor |
| gear | 0.69 × 0.69 × 0.25 | 2468 | Rotor |
| clutch | 0.8 × 1.28 × 0.7 | 1632 | Rotor |
| pendulum | 0.76 × 3.0 × 0.2 | 580 | Pendulum |
| weight | 0.67 × 0.8603 × 0.6225 | 708 | — |
| fuse | 0.2 × 0.5 × 0.2 | 864 | — |
| wheel | 1.2664 × 1.2666 × 0.25 | 740 | Rotor |
| control_pedestal | 0.8 × 1.3 × 0.61 | 844 | Lever |
| lamp | 0.44 × 0.8073 × 0.44 | 1096 | — |

All GLBs live in `assets/models/expansion/`; editable `.blend` files are in `assets/sources/expansion/`. Their shared external textures are in `assets/textures/expansion/`. Source files and reference screenshots are excluded by `.gdignore`.

Gate and Ram move on Y; Lever, Rotor (except generator) and Pendulum rotate around Godot Z. Generator Rotor rotates X. Rollers is a common grouping; animate individual roller mesh children around Godot Z for belt motion, not the common pivot. Pendulum pivot is at suspension. Basket moves as a complete assembly.

## Materials and licensing

Wood: [Poly Haven weathered_planks](https://polyhaven.com/a/weathered_planks), CC0, diffuse/roughness/OpenGL normal at 2048². Teal/brass/iron: original project procedural metal maps at 2048², authored by `tools/create_mechanical_props.py`, reused here. Wood material keeps the real photographed texture. The kit uses material factors for metal colors.

Audio: [Kenney Impact Sounds](https://kenney.nl/assets/impact-sounds), CC0. Exact selected source samples and SHA-256 hashes are recorded in `assets/sources/expansion/download-manifest.json`; original license is in `assets/audio/expansion/LICENSE.txt`. Seven named runtime OGG files: wood_step, metal_latch, press_impact, crate_place, basket_stop, bell, fuse_insert.

Reference only: [Playdead official press area](https://playdead.com/press/), INSIDE screenshot pack and LIMBO July 2010 screenshots. Copyright remains with Playdead; these are visual research and never runtime textures or shipped artwork. Archives and extracted images reside below the ignored sources directory. No Playdead assets were incorporated into original kit meshes or materials.

## Character interaction variant

`assets/models/expansion/doll_interactions.glb` derives from the existing exact `assets/sources/doll.blend`, preserves its main meshes, skeleton, and original clips; repairs three sewn cloth patches and their stitches, and adds carry_idle, carry_walk, pull, climb. Rebuild with `blender -b --python assets/sources/expansion/create_interaction_animations.py`. These clips are in-place cycles; runtime owns motion. Integration must register loop modes for all four. Original doll files remain unchanged.



Reference observations: INSIDE_03 uses a distant light source, repeated tall structural bays, and a strong foreground silhouette; LIMBO Pipe makes the grab path readable with a dark continuous pipe against soft background value. The original kit responds with repeated arch bays, readable ladder rungs, distinct brass moving parts, and quiet wood panels; it does not reproduce either scene.

Variant repair: apparent extra hands were original sewn patches sharing the hand material and floating ahead of the cloak. The variant uses conforming fabric grids, cloak-interpolated weights, a small surface offset, and a distinct muted patch material. Real hands remain unchanged. Carry poses now hold the hands at chest level. All 12 original animation track inputs/outputs are byte-identical to the original GLB; all 16 clips survive independent Blender reimport. Original doll files are unchanged. Carry, climb and pull pose previews were reviewed after repair.

Source portability: both expansion generators use four-space Python indentation and save image paths relative to each source blend. All 24 existing expansion blends were resaved with relative paths in Blender 5.2.1. A cargo basket source and the interaction character source were copied with their referenced textures into an unrelated temporary asset tree; every texture reloaded successfully from the relocated tree. Runtime GLB/texture SHA-256 values were unchanged. Detailed counts: `assets/sources/expansion/source-portability-verification.json`.
