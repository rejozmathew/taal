# STATUS.md

## Project
- Name: Taal
- Repository: taal
- PRD version: 1.9
- Current phase: Phase 1.5 — Complete
- Current task: Flutter analyzer cleanup - Complete
- Overall status: Flutter analyzer cleanup completed on 2026-04-18; `flutter analyze`, `flutter test test/library_screen_test.dart`, and full `flutter test` pass. Phase 1 functionally complete. Phase 1.5 complete. P1.5-18 global polish pass landed (26 tooltips, keyboard shortcuts, SnackBar feedback, dynamic window title, responsive verification). P1.5-17 tap pad visual and interaction polish landed. P1.5-15 review screen polish landed. P1.5-16 daily goal ring and streak visual landed. P1.5-14 combo/grade visual effects landed. P1.5-13 practice toolbar redesign with grouped layout and count-in support landed. P1.5-11 note highway visual overhaul landed. P1.5-12 drum kit visual overhaul landed. P1.5-10 animation framework landed. P1.5-03 through P1.5-09 complete. CI bridge fixture sync completed for the P1.5-03 kit-hit sound setting.

## Release Boundary
- **MVP (Phases 0-2):** Playable + creatable + course runtime. Not yet distributed.
- **v1.0 (Phases 0-3):** Analytics, polish, backing tracks, packaged builds. First public release.

## Phase Gates
- [x] Phase 0: Foundation + Latency Spike (9 tasks) — conditional go per CR-001
- [x] Phase 1: Core Practice Loop (27 tasks) — functionally complete, UX gaps identified
- [x] Phase 1.5: UX Remediation (18 tasks, 2 tranches) — complete
- [ ] Phase 2: Creator Studio + Content System + Course Runtime (18 tasks)
- [ ] Phase 3: Analytics + Polish + Distribution (23 tasks)

## Active Change Requests
- CR-001: Phase 0 conditional go (accepted)
- CR-002 through CR-008: Phase 1 implementation clarifications (applied)
- CR-009: Phase 1 UX Remediation — proposes Phase 1.5 (proposed, pending approval)

## Frozen Interfaces
*(unchanged from Phase 1 completion)*

## Phase 1.5 Task Summary (if CR-009 approved)

### Tranche A: Fix Broken
| ID | Title | Deps | Status |
|----|-------|------|--------|
| P1.5-01 | Design system foundation | — | Complete |
| P1.5-02 | Theme switching fix | P1.5-01 | Complete |
| P1.5-03 | Audio wiring | — | Complete |
| P1.5-04 | Onboarding re-entry + profile management | — | Complete |
| P1.5-05 | MIDI device lifecycle | — | Complete |
| P1.5-06 | Error states + empty states | P1.5-01 | Complete |
| P1.5-07 | Settings screen restructure | P1.5-01, P1.5-02, P1.5-03, P1.5-04, P1.5-05 | Complete |
| P1.5-08 | Library UX overhaul | P1.5-01 | Complete |
| P1.5-09 | Onboarding flow redesign | P1.5-01, P1.5-03, P1.5-05 | Complete |

### Tranche B: Make Premium
| ID | Title | Deps | Status |
|----|-------|------|--------|
| P1.5-10 | Animation framework | Tranche A complete | Complete |
| P1.5-11 | Note highway visual overhaul | Tranche A complete, P1.5-10 | Complete |
| P1.5-12 | Drum kit visual overhaul | Tranche A complete, P1.5-01 | Complete |
| P1.5-13 | Practice toolbar redesign + count-in | Tranche A complete, P1.5-10 | Complete |
| P1.5-14 | Combo + grade visual effects | Tranche A complete, P1.5-10 | Complete |
| P1.5-15 | Review screen polish | Tranche A complete, P1.5-10, P1.5-14 | Complete |
| P1.5-16 | Daily goal ring + streak visual | Tranche A complete, P1.5-01 | Complete |
| P1.5-17 | Tap pad visual + interaction polish | Tranche A complete, P1.5-03, P1.5-12 | Complete |
| P1.5-18 | Global polish pass | All P1.5 tasks | Complete |

## Blockers
- Phase 1.5 execution blocked pending CR-009 approval
