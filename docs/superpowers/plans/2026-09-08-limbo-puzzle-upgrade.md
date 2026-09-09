# LIMBO-inspired campaign implementation

Approved in conversation: keep four chapters / 24 rooms / nine stable checkpoint IDs, original art, observation-led puzzles, goal HUD and three voluntary hints. Implement in Godot 4.7.2 with reusable deterministic mechanisms; no combat, gravity inversion, extra chapters or collectibles.

## Task 1: Persistent content compatibility
Outer save format stays v2. Add content revision 2 to full chapter world snapshots. Archive older full-room snapshots before migrating to the same room entrance, retaining chapter/unlocks and resetting incompatible room state. Mid checkpoints map to room entrance. Read/write/backup failure cannot discard original bytes. Tests use isolated artifacts files. Root owns full_chapter capture/restore; delegate owns save_store and migration tests only.

## Task 2: Mechanical simulation and workshop
Create independently testable water circuit, counterweight, shaft phase and hazard components; integrate via room condition lookup and snapshot hooks. Workshop: visible wiring; lift/door power split; crate must be pushed onto belt and caught by physical latch; powered press rests on support car; two fuses are recovered/reused into final circuits; reversal slows a visibly announced chase.

## Task 3: Water rooms
Drain must actually lower water. Replace laundry room 2 cargo lift with floating crate, open hatch before raising it, reversible drain. Room 3 two equal-capacity tanks conserve total volume and transfer water to raise left then right float decks with a safe connecting ledge. Room 4 callable cargo basket. Room 5 vent air then hydraulic head drives gate. Room 6 three visibly cycling steam outlets with safe islands.

## Task 4: Weight rooms
Room 1 mass changes cargo landing height. Room 2 one weight swaps between two trays to make two steps via a safe island. Room 3 raise, pin bridge, recover weight. Room 4 send unaccompanied cargo then climb empty handed. Room 5 bell changes guard attention for 12 seconds, retriggerable, no arbitrary hoist prerequisite. Room 6 three independently raised and pinned bridge spans, one reusable weight.

## Task 5: Clock rooms
Room 1 direction drives a visible rack. Room 2 lock cargo stop then divert power. Room 3 freeze actual pendulum pose, unified physical danger and animation. Room 4 fast/slow shafts (2:1) temporarily brake fast shaft then couple when aligned. Room 5 target mark plus actual rotating phase (>=2 second window) and brake before releasing hammer. Room 6 final known-mechanism route. Brake duration 12 seconds; hazard prewarning >=1 second.

## Task 6: Guidance, visual causality, routes and delivery
HUD goal and achieved milestones only; hints progress from observation to relation to complete route. Add original pipes, ropes, pins and scales; reuse kit and CC0 wood/audio. Keep generated scenes reproducible. Update all 24 real-input walkthroughs, journey and targeted regressions; run Windows full verifier, disposable-copy builder, window captures and performance check. Human blind play duration is unverified, not an automated claim. Record actual limitations.

## Source references
- https://playdead.com/press/ (reference-only existing screenshots)
- https://www.gdcvault.com/play/1013665/Limbo-Balancing-Fun-and-Frustration (public description inspected)
- https://gamefaqs.gamespot.com/xbox360/991005-limbo/faqs/60492 (spider, floating box, water displacement, HOTEL)
- https://www.supercheats.com/guides/limbo/chapter-twenty-two (magnet/gravity combination)
- https://polyhaven.com/a/weathered_planks and https://polyhaven.com/license (existing CC0 wood)
- https://kenney.nl/assets/impact-sounds (existing CC0 mechanical audio)
- https://kenney.nl/assets/factory-kit (optional reference, not imported)
