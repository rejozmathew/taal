# STATUS.md

## Project
- Name: Taal
- Repository: taal (fresh repo; legacy prototype archived as taal-legacy)
- PRD version: 1.9
- Current phase: Phase 0 (Foundation + Latency Spike)
- Current task: P0-01 Monorepo scaffold
- Overall status: Bootstrap commit. Documentation complete. Ready for Phase 0 execution.

## Release Boundary
- **MVP (Phases 0-2):** Playable + creatable + course runtime. Not yet distributed.
- **v1.0 (Phases 0-3):** Analytics, polish, backing tracks, packaged builds. First public release.

## Phase Gates
- [ ] Phase 0: Foundation + Latency Spike (9 tasks)
- [ ] Phase 1: Core Practice Loop (27 tasks)
- [ ] Phase 2: Creator Studio + Content System + Course Runtime (18 tasks)
- [ ] Phase 3: Analytics + Polish + Distribution (23 tasks)
- [ ] Phase 4: AI Coach + Marketplace Prep + Multi-Platform
- [ ] Phase 5+: Marketplace + Keyboard + ML + Teacher/Classroom + Community

## Architecture Decision
- ADR-001 (Flutter + Rust): Proposed, pending Phase 0 spike results
- Go criterion: end-to-end MIDI latency < 25ms on Windows + Android (release build)
- No-go criterion: > 40ms or consistent frame drops

## Task Ordering
Task IDs are identifiers, not execution order. Dependencies define sequencing. See AGENTS.md.

## Frozen Interfaces
- [x] Canonical Grade enum (engine-api.md §1)
- [x] Session state machine (engine-api.md §3)
- [x] EngineEvent types (engine-api.md §4)
- [x] PracticeMode enum (engine-api.md §8)
- [x] CompiledLesson contract (engine-api.md §8)
- [x] Content schema invariants (content-schemas.md §7)
- [x] Layout compatibility rules (content-schemas.md §7)
- [x] RawMidiEvent contract (midi-mapping.md §2)
- [x] MappedHit contract (midi-mapping.md §3)
- [x] PracticeAttempt schema (analytics-model.md §1)
- [x] Combo behavior (analytics-model.md §8)
- [ ] Rust engine API surface (engine-api.md §4) — to be confirmed after Phase 0

## Document Versions
| Document | Version | Update Trigger |
|----------|---------|----------------|
| AGENTS.md | v1 | When execution rules change |
| CLAUDE.md | v1 | Thin shim — rarely changes |
| ARCHITECTURE.md | v1 | When components/flows/boundaries change |
| README.md | v2 | When user-visible capabilities land |
| docs/prd.md | v1.9 | When scope or product rules change |
| docs/adr/001-platform-architecture.md | v1 | Immutable (status line only) |
| docs/specs/content-schemas.md | v1.1 | When content contracts change |
| docs/specs/engine-api.md | v1 | When engine contracts change |
| docs/specs/midi-mapping.md | v1 | When MIDI contracts change |
| docs/specs/analytics-model.md | v1 | When analytics contracts change |
| docs/specs/visual-language.md | v1 | When visual contracts change |
| docs/coding-model.md | v1 | When task execution rules change |
| plans/phase-0.md | v1.1 | Via CR when tasks need revision |
| plans/phase-1.md | v1.7 | Via CR when tasks need revision |
| plans/phase-2.md | v1.5 | Via CR when tasks need revision |
| plans/phase-3.md | v1.3 | Via CR when tasks need revision |

## Completed Work
*(none yet — bootstrap commit, ready to begin Phase 0)*

## Blockers
*(none)*

## Open Questions
1. Flutter MIDI plugin maturity on Windows — needs spike validation (P0-03)
2. Android USB MIDI latency on mid-range tablets — needs spike measurement (P0-06/P0-07)
3. Metronome audio output latency — deferred to Phase 1 (P1-15)
4. Theme detection thresholds — TBD values in analytics-model.md, tuned during Phase 3
5. Velocity/dynamics scoring formula — deferred post-v1
