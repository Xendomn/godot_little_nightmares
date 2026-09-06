# Crouch and keeper navigation repair

Approved plan: fix hero floor penetration and repeated crouch transitions; fix keeper stuck around workshop assembly tables and shared chapter furniture. Preserve saves, controls, collision sizes and finale routes. Baseline commit 45c81bd, existing feature branch is isolated and clean.

Diagnosis: crouch Hips offset -.70 and inconsistent cloak/patch weights yield posed minimum -.512m. Tests checked only maximum. Crouch starts in standing pose and is restarted after crouch_walk. Keeper heads directly to last_seen, then changes global Z after >1 slide collisions; return/distraction lack routing.

Task 1 complete: independent hero asset correction and frame-by-frame mesh bounds tests.
Task 2 complete: crouch state hysteresis, crouch landing priority; NavigationAgent3D and editor-authored ground-only NavigationRegion3D with furniture exclusions, common pursuit/return/investigate routing and stalled path recovery.
Task 3 complete: six-table regression, 15 suites, actual GPU skin checks and captures, independent review, Windows re-export/package and isolated executable startup (exit 0). Fix commit uses daniel <xendomn@gmail>. Evidence is recorded in crouch-navigation-verification.md.
