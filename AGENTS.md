# Repository Guidelines

## Project Structure & Module Organization

Midnight Workshop is a Godot 4.7.2 GDScript game with four connected chapters. `scenes/main.tscn` hosts the campaign manager, which loads one chapter at a time.

- `scripts/`: gameplay, input, UI, and audio; `campaign/` handles saves and transitions, `chapters/` handles level mechanics, and `props/` handles mechanical visuals.
- `scenes/`: editable chapters, shared actors, and props. `resources/levels/` defines chapter metadata and checkpoints.
- `assets/`: models, textures, fonts, audio, shaders, and Blender sources.
- `tests/`: scripted checks, captures, and benchmarks. `tools/`: generators, verification runners, and packaging. `docs/`: design and verification records.

## Build, Test, and Development Commands

Run from the repository root with Godot on `PATH`:

- `godot --headless --path . --editor --import --quit`: import resources before testing or exporting.
- `godot --path .`: launch the game; alternatively open `project.godot` and press F5.
- `bash tools/verify.sh`: run all 20 suites on macOS. Set `GODOT` to the executable path if needed.
- `powershell -ExecutionPolicy Bypass -File tools/verify.ps1`: run the Windows verification suites.
- `godot --headless --path . --fixed-fps 60 --script tests/test_save_store.gd`: run one suite.
- `mkdir -p build && godot --headless --path . --export-release macOS build/MidnightWorkshop.app`: export locally with matching official templates. See README for Windows export requirements.

## Coding Style & Naming Conventions

Follow neighboring code: tabs for GDScript, four spaces for Python, `snake_case` filenames/functions/variables, and `UPPER_SNAKE_CASE` constants. Use explicit GDScript types where useful and `res://` resource paths. Preserve existing node names referenced by scripts. No repository formatter or linter is configured; avoid unrelated formatting changes.

## Testing Guidelines

Tests use standalone Godot `SceneTree` scripts and Python assertions. Name gameplay checks `tests/test_<behavior>.gd`; report failures and exit nonzero. Use isolated save files, never real campaign progress. Add regression coverage for gameplay fixes and run the full verifier before delivery. Visual changes also require windowed checks and screenshots; headless success does not establish rendering correctness. No numeric coverage threshold is configured.

## Commit & Pull Request Guidelines

History uses imperative `feat:` and `fix:` subjects. Keep commits focused. Pull requests should explain the problem, resulting behavior, relevant issues, commands tested, and platform limitations. Include screenshots for visual changes.

## Generated Assets & Platform Configuration

Generators overwrite scenes and assets; follow README ordering and run `python3 tests/test_builder.py` in a disposable copy. Keep `build/`, `artifacts/`, and `.godot/` untracked. Preserve ETC2/ASTC import for macOS and Windows export settings. Document new asset licenses in the existing attribution files.
