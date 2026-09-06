# Mechanical prop assets

Original modeled assemblies in worn walnut, oxidized brass, teal enamel, dark iron and woven linen. No text labels. GLBs use shared external 2K PBR textures; keep assets/textures/props beside the models directory hierarchy. Blender sources preserve articulated empty parents.

Regenerate: `blender -b --python tools/create_mechanical_props.py`. Use `-- --heroes` for initial three hero previews or `-- --no-render` for export only. Verify: `python tests/check_mechanical_assets.py`.

Godot axes: Y up, +Z front. Normal origins at ground; last_bell origin is top suspension. Rotor, Lever, Bell, Hammer and Needle animate around local Godot Z; Deck translates local Y. Fuse can be hidden/removed. Exit Door assemblies are parked open.

| Asset | Triangles | Godot width x height x depth (m) | Pivots |
|---|---:|---|---|
| drain | 2588 | 0.732 x 1.370 x 0.500 | Rotor |
| bell | 3524 | 0.700 x 1.420 x 0.607 | Bell |
| exit_workshop | 7728 | 3.702 x 4.005 x 1.295 | - |
| fill | 4168 | 0.700 x 1.400 x 0.521 | Needle, Lever |
| winch_a | 7484 | 0.700 x 1.370 x 0.605 | Rotor |
| winch_b | 7916 | 0.700 x 1.426 x 0.605 | Rotor |
| brake | 4196 | 0.700 x 1.400 x 0.521 | Needle, Lever |
| wind | 3900 | 0.700 x 1.370 x 0.605 | Rotor |
| release | 2376 | 0.700 x 1.370 x 0.521 | Lever |
| fuse_box | 3180 | 0.782 x 1.370 x 0.477 | Fuse |
| power_switch | 2340 | 0.700 x 1.370 x 0.521 | Lever |
| laundry_cart | 5140 | 0.901 x 0.857 x 0.830 | - |
| spool_carrier | 9516 | 0.901 x 0.845 x 0.830 | - |
| pressure_plate | 1436 | 1.300 x 0.125 x 1.300 | Deck |
| steam_pipe | 2192 | 0.466 x 1.166 x 0.474 | Needle |
| last_bell | 3572 | 3.174 x 2.736 x 3.025 | Bell, Hammer |
| exit_laundry | 3516 | 3.650 x 4.010 x 1.350 | Door |
| exit_vault | 3980 | 3.700 x 3.980 x 1.225 | Door |
| exit_clocktower | 5800 | 3.650 x 3.950 x 1.000 | - |

The workshop chute sits above the existing continuous floor: shallow rollers run from local Godot Y approximately 0.065 at the left entry to 0.039 at the right exit, with raised side rails approximately 0.30 m tall. The deck slopes gently toward +X and does not change gameplay collisions. Other exits keep their central passage open.

Twelve source PBR maps are shared across the family. Three derived ORM maps pack roughness into G and metallic into B; base color factors preserve the brass/iron/enamel variants without duplicated albedo textures. Sources use relative texture paths. Preview contact sheet reads left-to-right in the generator asset list order.
