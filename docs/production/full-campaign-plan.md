# Full campaign implementation contract

Approved scope: four existing themes/order, six substantial puzzle sequences per chapter, first-play target 15–20 minutes each (not claimed without human playtests). Puzzle-led, local loops, original teal/wood/brass world, Blender models plus CC0 materials/audio. Add push/pull, carry/place, fixed ladders, voluntary three-step hints. Nine stable checkpoint IDs per chapter. Windows retained and Apple Silicon tested. No combat or gore.

## Shared runtime contracts

New active chapters will be generated at `scenes/chapters/full/{workshop,laundry,thread_vault,clocktower}.tscn`; resources/levels scene_path points there. Legacy scenes remain as regression fixtures. Chapter root exposes `managed`, `playing`, `respawning`, `player`, `keeper`, `camera`, `ui`, `world`, `checkpoint_id`; signals `checkpoint_reached(id)` and `level_completed`; methods start_game(), restore_checkpoint(id, snapshot={}), get_checkpoint_snapshot(), fail(), toggle_pause(), finish_game(). IDs: room_1, room_2, room_3, room_3_mid, room_4, room_5, room_5_mid, room_6, room_6_mid. Default room_1. Snapshot is a JSON-safe Dictionary containing completed rooms and object states; the campaign passes it back unchanged. Legacy integer checkpoints remain supported on legacy scene/script APIs.

Player enables new behavior via `@export var extended_interactions=false`. When true, child `Interactions` manages targets with group `puzzle_interactable`. Target contract: can_interact(actor), interact(actor), get_prompt(). Player owns single active target. Controller exposes `carried`, `prompt_text`, cancel_interaction(). Parent chapter reads prompt_text. All persistent puzzle nodes expose @export object_id:String, capture_state()->Dictionary, restore_state(Dictionary). Room/root owns registry; avoid global scene queries crossing chapters. Items only interact within reach and clear line of sight.

Carry item: object_id, item_kind, mass; type small carryable. Pushable: object_id, mass, min_x, max_x, lane_z; hold E/X and direction supports pull/push. Ladder: object_id, bottom/top based on local position and @export height. E/X attach/detach, W/S or stick climb, Space/A drop. While carrying no jump/run/climb. Preserve ordinary existing player behavior when extended_interactions=false.

Generic devices (parent agent): object_id, kind, requires:Array[String], state, active. Carry insertion via Interactions.carried and controller methods supplied by interaction agent. Sockets consume no objects permanently: attached item survives snapshots. Inputs driven by physically placed objects, choices, or timing; no completion solely from player x. Snapshot restores before player/AI enabling.

UI method set_puzzle_hints(puzzle_id:String, hints:Array) configures 3 voluntary hints in pause menu. No automatic solution in objective HUD. Keep existing menu APIs/focus and controller behavior.

Save v2: stable string checkpoint_id, level_id, unlocked, flags snapshot, version=2. Read v1 through explicit migration for campaign: archive original bytes, preserve unlocked/current chapter, return/record room_1 with fresh state and migration notice. Legacy test callers may retain int/v1 behavior through explicit compatibility. Never touch real user saves in tests.

## Ownership

- parent: puzzle room/device/chapter runtime, full scene/content builder, level resources, integration tests and final docs/builds.
- interactions worker: player.gd; scripts/puzzles/{interaction_controller,carry_item,pushable,ladder}.gd; dedicated interaction tests. Do not alter old push_crate or UI.
- persistence worker: campaign.gd, save_store.gd, interface.gd and dedicated tests. Communicate any contract changes.
- art worker: tools/create_expansion_kit.py, assets/models/expansion, assets/sources/expansion, assets/textures/expansion, new sound assets and source manifest. Existing character assets only for additional animation clips, preserve existing clips/rig.

## Puzzle sequence

Workshop: hidden fuse/latching hatch; lift/light power routing and ladder loop; reversible belt/crate/plate; power-off press limiter; second fuse via return loop and dual circuits; conveyor reverse/gate escape.
Laundry: inlet/drain/ladder; position float then fill; transfer between linked tanks; upstairs wheel return via basket; bypass/pressure gate and rising platform; waterwheel/steam timing.
Vault: two masses/basket height; upper/lower trays; pin bridge/reuse weight/shortcut; weight delivery via basket; bell and moving basket evasion; double winch/three-span crossing and far latch.
Clock: missing gear/direction; clutch routes lift/pendulums; two brakes and phase; upper/lower gear return; clock-face sync/brake/weight/hammer; machinery finale.

## Ledger

- Baseline: clean at 5b52c6f, prior 20 suites pass.
- Ruling: implement in current user workspace; no unrelated git changes, commits or pushes. Shared working directory with disjoint file ownership.
- Implemented: 24 authored room scenes, interaction controls/animations, full runtime and active chapter resources, v2 persistence/hints, original Blender kit + CC0 maps/audio.
- Verified: 25 suites pass; continuous 24/24 source and exported-PCK routes; native arm64 app startup; two-platform export; disposable-copy generation twice; four 1080p screenshots and measured frame-time samples.
- Review fixes: final ending focus, carried-object restore ordering, cross-room socket restriction, bridge/platform state snapshots, lift crush protection and initially locked return ladders.
- Remaining empirical acceptance: human first-time pacing target, Windows runtime and physical controller hardware. See full-campaign-verification.md for precise evidence and limits.
