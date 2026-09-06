# Character and chapter expansion

Approved order: upgrade hero and keeper first and validate original chapter, then implement persistent checkpoint campaign and three new chapters (Laundry, Thread Vault, Clocktower). Windows/Godot 4.7.2, Blender 5.2.1, GDScript. No gore. Original chapter becomes chapter 0, followed by 1/2/3, final ending only after clocktower. Autosave checkpoint and unlocked chapters, continue and chapter select UI. Preserve collision dimensions and original traversal. Existing git commit f9604de; development branch feat/character-chapter-expansion.

## Ledger
- Complete: character sculpt, rig, textures, 19 animation clips and source verification.
- Complete: animator integration and original regressions; persistent campaign and save tests.
- Complete: independent chapter scenes, Laundry, Thread Vault and Clocktower; 13 passing suites, window routes, performance and independent review. Windows export and documentation delivered.

## Contracts
Characters: assets/models/doll.glb and keeper.glb. Godot Y up, feet at zero. Skeleton3D with animations named idle, walk, run, jump, fall, land, crouch, crouch_walk, push, pickup, interact, caught for hero; idle, walk, alert, listen, chase, grab, stumble for keeper. AnimationRoot references found by type, not specific imported hierarchy. Character motion is in-place; physics controller owns translation. Hero standing collision height 1.2 and crouch .64. Visual never scaled to crouch.
Campaign LevelDefinition resource: id, title, scene_path, next_id, camera_min/max, checkpoint_positions array. Generic Chapter root supplies checkpoint_reached(id), level_completed(), get_checkpoint_snapshot(), restore_checkpoint(id). Save stores version=1, level_id, checkpoint_id, unlocked array and flags dictionary; validates known IDs and valid checkpoint bounds. Each chapter has 3 safe checkpoints. Save uses user://campaign.json by default, injectable path for tests.

## New chapter progression
Laundry: drain valve lowers water blocking floor channel; push cart onto lift pressure plate; fill lever raises cart/actor lift to upper walkway; curtains and machinery conceal from keeper; steam timing corridor to lift exit.
Thread Vault: push spool crate onto counterweight plate to lower first platform; operate winch A then B to build second and third bridge spans; bell decoy at fixed points diverts keeper; bridges lead into escape path.
Clocktower: brake holds pendulum hazard for a visible countdown; wind lever activates lift; ride to upper walkway and release bell hammer; final keeper chase through jumps and low tunnel to dawn ending.

## Verification
Old traversal test plus new character animation import/transition checks first. Save tests with isolated artifact paths, corruption/backup and schema checks. Each new chapter input traversal, each checkpoint death, platform pause/retry, scene unload and full campaign progression. Actual rendered captures, performance and independent code review. Re-export EXE/ZIP and document limits.
