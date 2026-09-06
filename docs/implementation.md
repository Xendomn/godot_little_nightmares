> 首版历史记录。当前四章架构与跨次存档见 README.md 和 expansion-plan.md。

# 午夜工坊 implementation

Approved scope: Windows keyboard, Godot 4.7.2 Forward+, GDScript, original Blender assets. Three connected rooms: push crate to climb workbench and take fuse; patrol stealth to install fuse and operate remote lever; conveyor chase with three jumps and low passage to exit. Menus, Chinese prompts, audio, checkpoints and ending. Target first play 5–10 minutes.

## Work ledger
- Workspace: empty folder, not a Git repository. Work directly here, no existing branch or changes to isolate.
- Assets task: independent Blender GLBs and procedural original WAVs. Gameplay consumes names listed in assets-brief.md.
- Gameplay task: player, interactions, progression, enemy, camera, authored scene generator and UI.
- Validation task: headless progression and physics tests; rendered walkthrough, screenshots, export.
- Assets task: complete. Six GLBs, Blender sources, eight original WAVs verified.
- Gameplay task: complete. Authored scene, progression, camera, original models, shaders, sounds and Chinese interface integrated.
- Review: four findings resolved and scoped re-review approved (docs/review.md).
- Ruling: the keeper spends three seconds forcing its way past the final low tunnel; this gives a crouching player a fair escape margin.
- Ruling: OpenType variable font weight uses the numeric wght tag; string axis name was ignored by the font backend.
- Validation: four automated suites pass; rendered input gauntlet reaches ending; continuous stealth route passes after waiting under the first table. Windows embedded-PCK executable generated and isolated startup passes.
- Ruling: generate editable .tscn using an offline Godot scene builder; runtime does not generate the environment. This retains editor usability while making scene authoring reproducible.
- Ruling: omit C++; no native extension is needed for this scope.

## Shared contracts
World X advances right, Y up, Z depth; traversable depth -1.6 to 1.6. Player height 1.25 and radius .25. Regions X 0–24, 24–54, 54–88. Player visual faces +X by default.
Progress uses collect_fuse, install_fuse, activate_power, enter_checkpoint, restore_checkpoint. Checkpoint 1 restores carried fuse; checkpoint 2 restores power. No permanent saves.
Interactables expose get_prompt(), can_interact(player), interact(player). Environment uses collision layer 1, player layer 2, enemy layer 4.
