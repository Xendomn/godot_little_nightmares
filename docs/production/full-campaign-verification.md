# Full campaign verification

Expanded campaign, Godot 4.7.2 / Blender 5.2.1, macOS 15.7.9, Apple M4; checked 2026-09-07.

## Delivered content

Four chapters now load 24 authored room scenes from `scenes/chapters/full/`. Each chapter has six ordered puzzle sequences and nine checkpoint IDs. Push/pull, reusable carry sockets, cargo lifts, fixed ladders, pressure plates, reversible transport, linked controls, brakes, moving bridges and two pursuit encounters are connected to progression. Three voluntary hints are available for each sequence through pause.

Original Blender assets include 23 mechanical assemblies and a repaired character variant with four additional interaction animations. Sources, measurements, previews, licensing and reproducible commands are in [the asset ledger](expansion-assets.md). All 24 Blender sources use relative texture paths; relocated basket and character files successfully reloaded all 10 referenced images. Runtime GLB/texture hashes remained unchanged after this portability fix. Playdead screenshots remain reference-only under the excluded source directory.

## Automated checks

`bash tools/verify.sh` passed all 25 suites. The runner counted 496 explicitly reported checks; the interaction suite also performs assertions but reports its result collectively. Coverage includes:

- `test_full_routes.gd`: all 24 puzzles through continuous movement and interaction input. No teleporting or direct state changes solve these routes. Exercises pulling, belt delivery, cargo return, ladders, reusable weights, three real bridge spans and timed hazards.
- `test_puzzle_interactions.gd`: reach/visibility, safe placement, push/pull obstruction, ladder controls, interaction animation selection and legacy fallback.
- `test_campaign.gd`, `test_save_v2.gd`: stable IDs, nested snapshots, held and socketed items, retry/reload, migration backups, corrupt files and final ending navigation. Tests use isolated save paths.
- `test_puzzle_rooms.gd`: unsolved goal guards, JSON snapshots, moving-span restoration, lift crush prevention and room-local socket membership.

`tests/test_builder.py` was run in a disposable project copy. Both prototype generation and 24-room generation succeeded twice; the missing-input fixture failed explicitly without overwriting the main scene.

Screenshots: `artifacts/expanded-campaign/{workshop,laundry,thread_vault,clocktower}.png`. The capture script repositions the camera subject only for visual inspection; it is separate from the continuous route tests.

## Performance

Windowed 1920×1080, Metal / Forward+, 90 warm-up and 240 measured frames per chapter, at room 5. Results from `tests/benchmark_full_campaign.gd`:

| Chapter | Average FPS | P95 frame time |
|---|---:|---:|
| Workshop | 117.1 | 10.69 ms |
| Laundry | 117.1 | 10.45 ms |
| Vault | 120.0 | 9.54 ms |
| Clocktower | 119.0 | 9.66 ms |

These fixed-location samples meet the 60 FPS / P95 ≤20 ms target on this machine. They do not characterize every encounter, lower-end hardware or long-session performance.

## Builds and limits

Exports: `build/MidnightWorkshop.app` (Universal, arm64 native) and `build/MidnightWorkshop.exe` (Windows x64). The official release template forbids scene/path overrides. Native launch passed with exit 0 using the regular entry point, `arch -arm64`, a temporary working directory and an isolated `MIDNIGHT_SAVE_PATH`. The exported PCK passed all 24 continuous-input routes using the Godot executable with `--main-pack`, independent of source resource paths. Ad-hoc signature verification passed. Windows was exported, not executed on Windows.

`MIDNIGHT_SAVE_PATH` optionally supplies a full save-file path for portable or QA sessions. Explicit scene `save_path` overrides take precedence. Create the parent directory first. Normal play without this variable retains `user://campaign.json`.

First-time duration remains a **15–20 minute per chapter design target**, not a measured result. Automated walkthroughs already know every solution. Their simulated chapter times were 222.4 / 265.4 / 258.5 / 223.5 seconds (workshop / laundry / vault / clocktower), excluding exploration and hint reading; these are reproducibility data, not first-play estimates. Human blind playtests, Windows runtime testing, physical controller testing and additional Mac models remain unverified.
