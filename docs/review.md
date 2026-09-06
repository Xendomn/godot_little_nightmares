# Implementation review

## Findings

### [P2] Completed interactions continue to advertise actions that cannot run

`scripts/interactable.gd:11-12` bases the panel and lever text on `has_fuse` / `fuse_installed`, but does not account for `power_on`. After the lever succeeds, the lever still says `E  拉下电闸` and the panel still says `电流正在等待开关`. `scripts/game.gd:97-111` displays the nearest visible interactable's prompt without requiring `can_interact()`, while `interact()` correctly rejects the action. The result is a persistent, actionable-looking prompt that does nothing after power is on, including after a checkpoint-2 respawn. Add explicit powered/completed prompt states, or suppress the prompt for non-interactable completed objects.

### [P2] The stealth detection and capture rules do not consistently respect cover

`scripts/keeper.gd:54-61` rejects only targets sufficiently behind the keeper on the X axis; it has no angular field-of-view test. A player anywhere to the keeper's side within six metres is treated as visible when the ray is clear. More seriously for the intended table-hiding play, `scripts/keeper.gd:41-43` catches solely by origin-to-origin distance and does not require line of sight, so the keeper can catch through a tabletop or around a thin obstacle once the two origins are within 0.85 m. The authored tables in `tools/build_scene.gd:178-184` are presented as stealth cover. Use a forward-vector dot threshold for sight and require an unobstructed capture ray, or make capture use a deliberate hit area that cannot overlap through cover.

### [P2] Turning left rotates the characters' faces away from the fixed camera

The asset contract and report place character facial detail toward Godot +Z so it remains visible to the camera (`docs/assets-brief.md`, orientation paragraph; `docs/assets-report.md`, Models section). `scripts/player.gd:76` and `scripts/keeper.gd:45` yaw the complete imported model by PI whenever the character faces -X, which maps that facial side to -Z. The doll's stitched face and the keeper's mask/lamp eyes therefore disappear from view during leftward movement and half of the patrol. Keep the models camera-facing and convey X direction with a smaller yaw/lean, or split locomotion orientation from the facial presentation.

### [P2] The documented Windows export deliverable is absent

`docs/implementation.md` assigns export to validation, but the project currently has no `export_presets.cfg` and no game executable/PCK; `build/export_templates/` contains engine templates only. The project runs in Godot, but it is not yet a reproducible Windows deliverable. Add a checked-in Windows export preset and produce or document the final export artifact if export remains part of the accepted scope.

## Softlock and lifecycle assessment

No additional progression softlock was found in the reviewed code. `scripts/game.gd:36-56` reconstructs progression and resets all actors for both restart entry points. `scripts/game.gd:170-179` plus `scripts/progress.gd:31-35` restore the carried fuse at checkpoint 1 and installed fuse/power at checkpoint 2, and `scripts/game.gd:130-152` reopens the corresponding gates. Pause UI processing is explicitly kept alive by `scripts/interface.gd:25-26`; resume and restart both unpause through `scripts/game.gd:39` / `scripts/game.gd:62-66`. The finale keeper crosses conveyor gaps intentionally and has a scripted delay at the low passage (`scripts/keeper.gd:24-38`), so its direct movement there does not create a route softlock.

The existing gameplay log demonstrates the crate climb, crouch duct, both checkpoint restores, three conveyor jumps, and ending. The stealth log demonstrates one timed crouch-and-wait route through room 2. Those are useful happy-path checks, but neither log exercises capture while separated by cover or a complete pause-menu restart lifecycle. I did not rerun tests, as requested; the known floor-contact assertion is excluded from this review because its fix was already in progress.

## Verdict

The implementation substantially satisfies the approved prototype scope: it contains the three connected rooms, keyboard movement, push/climb and crouch traversal, ordered fuse/panel/lever interactions, patrol and chase phases, two restorable checkpoints, Chinese menus/prompts, procedural character motion, original audio integration, and an ending. The core state machine is small and internally consistent.

Quality is at functional prototype level rather than release-ready. There is no identified blocker in the main progression path, but the stale interaction feedback, cover-insensitive capture, and camera-facing character animation are visible product issues. The missing export preset/artifact is also a direct scope gap if the Windows build is part of delivery. Address those points and complete the coordinator's render/input verification before acceptance.

## Resolution review

All four findings above are resolved in the current implementation.

- **Completed interaction feedback — resolved.** `scripts/interactable.gd:11-12` now checks `state.power_on` first and reports completed panel and lever states. The prompt remains informative, and it no longer advertises an action that `can_interact()` will reject.
- **Stealth sight and capture — resolved.** `scripts/keeper.gd:54-65` now uses a horizontal forward-vector dot threshold of 0.35 and factors the obstacle ray into `has_clear_sight()`. `scripts/keeper.gd:41` also requires that ray before emitting capture, so the proximity rule no longer catches through authored cover.
- **Camera-facing character presentation — resolved.** `scripts/player.gd:76` limits doll yaw to ±0.45 radians and `scripts/keeper.gd:45` limits keeper yaw to ±0.65 radians. Both characters indicate travel direction while keeping their +Z facial detail visible from the fixed camera.
- **Windows export — resolved.** `export_presets.cfg:1-27` defines a runnable Windows Desktop x86-64 release with an embedded PCK at `build/MidnightWorkshop.exe`. The artifact exists and is 123,799,632 bytes. This review confirms the preset and output are present; it does not rerun the executable.

The requested `interface.gd` checks found no new issue. `scripts/interface.gd:35` uses integer tag `2003265652`, which is the correct big-endian OpenType tag value for `wght`, and supplies a numeric axis value (`450.0`). The pause split is also coherent: `scripts/interface.gd:26` keeps the UI processing while paused; on an initial Escape, reverse depth-first unhandled-input propagation visits the child interface before the root game, so the interface sees an unpaused tree and the root pauses it. While paused, the root's inherited processing is disabled and `scripts/interface.gd:173-176` alone consumes Escape and emits resume. No same-event pause/resume toggle is introduced by these handlers.

Revised verdict: the earlier review has no remaining open finding. The reviewed implementation now meets the stated gameplay and Windows-delivery scope at prototype acceptance quality, subject to the coordinator's separate runtime, rendering, and input test results. No tests were rerun for this resolution review.
