# STATUS.md

## Project
- Name: Taal
- Repository: taal (fresh repo; legacy prototype archived as taal-legacy)
- PRD version: 1.9
- Current phase: Phase 1 ready (implementation not started)
- Current task: P1-00 Android Native-to-Rust Jitter Investigation (next)
- Overall status: Phase 0 completed with conditional go via CR-001. Windows passed cleanly. Android p99 measured 25.161 ms, a marginal 0.161 ms miss against the strict `< 25ms` line but well below the `> 40ms` no-go line. ADR-001 is accepted with a Phase 1 Android jitter follow-up; frame-drop validation is deferred to the first real animated Practice Mode path.

## Release Boundary
- **MVP (Phases 0-2):** Playable + creatable + course runtime. Not yet distributed.
- **v1.0 (Phases 0-3):** Analytics, polish, backing tracks, packaged builds. First public release.

## Phase Gates
- [x] Phase 0: Foundation + Latency Spike (9 tasks; conditional go via CR-001)
- [ ] Phase 1: Core Practice Loop (28 tasks)
- [ ] Phase 2: Creator Studio + Content System + Course Runtime (18 tasks)
- [ ] Phase 3: Analytics + Polish + Distribution (23 tasks)
- [ ] Phase 4: AI Coach + Marketplace Prep + Multi-Platform
- [ ] Phase 5+: Marketplace + Keyboard + ML + Teacher/Classroom + Community

## Architecture Decision
- ADR-001 (Flutter + Rust): Accepted with conditional caveat via CR-001
- Conditional go criterion: Windows clean pass; Android p99 25.161 ms accepted as marginal with required P1-00 jitter investigation
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
| plans/phase-1.md | v1.8 | Via CR when tasks need revision |
| plans/phase-2.md | v1.5 | Via CR when tasks need revision |
| plans/phase-3.md | v1.3 | Via CR when tasks need revision |

## Completed Work
- P0-01 Monorepo scaffold: Flutter Windows/Android app scaffold, Rust library workspace, native adapter directories, assets placeholder, and baseline CI workflow created.
- P0-02 flutter_rust_bridge Integration: Rust `greet(name: String) -> String` is callable from Dart through generated bridge code; focused Flutter test passes after building the Rust release library; Windows and Android builds compile with the bridge.
- P0-03 Windows MIDI Adapter: WinMM enumerates Roland TD-27 as input device `0`; Flutter Windows app opens the device and receives NoteOn events with channel, note, velocity, and monotonic `QueryPerformanceCounter` nanosecond timestamps.
- P0-04 Rust Engine Skeleton: Phase 0 runtime session accepts pre-resolved hits, emits `HitGraded` events, drains events, and emits `Missed` on tick after the miss window. Focused Rust unit tests cover Perfect, Early, Late, Miss, and drain behavior.
- P0-05 Windows latency measurement: Release build captured 10 warm-up hits plus 100 measured hits with Roland TD-27. Total MIDI callback to Flutter return latency measured p50 0.154 ms, p95 1.006 ms, p99 2.064 ms. Raw CSV and summary report are under `artifacts/phase-0/`, and ADR-001 records the Windows evidence.
- P0-06 Android MIDI Adapter: Samsung Fold 4 (`SM-F936U1`, Android 16/API 36) running the release APK enumerated `Roland TD-27` as Android MIDI device `2`; the app received NoteOn events with channel, note, velocity, and `System.nanoTime()` nanosecond timestamps.
- P0-07 Android latency measurement: Release build captured 10 warm-up hits plus 100 measured hits with Samsung Fold 4 and Roland TD-27 after aligning Rust Android timing to `CLOCK_MONOTONIC`. Total MIDI callback to Flutter return latency measured p50 2.218 ms, p95 14.180 ms, p99 25.161 ms. Raw CSV and summary report are under `artifacts/phase-0/`, and ADR-001 records the Android evidence.
- P0-08 CI Pipeline: GitHub Actions workflow runs on push to `main` and pull requests with Rust `cargo check`, `cargo test`, `cargo clippy`, Flutter `analyze`, Flutter `test`, Windows build, and Android APK build. Local equivalents passed.
- P0-09 ADR-001 finalization: CR-001 records Phase 0 conditional go. ADR-001 status changed to accepted with conditional caveat. Phase 1 now starts with P1-00 Android Native-to-Rust jitter investigation.

## Maintenance
- 2026-04-16: `.gitignore` coverage updated for Flutter, Dart, Rust, Android, Gradle, Windows, and native build outputs; app/tool lockfiles and Gradle wrapper files remain visible to Git while generated build artifacts stay ignored.

## Blockers
*(none blocking Phase 1 start after CR-001)*

## Operational Caveats
- P0-08 merge blocking: CI workflow is present and locally validated, but GitHub branch protection / required status checks could not be verified from this environment (`gh` CLI unavailable; connector does not expose branch-protection settings). If not already enabled, require the CI checks in GitHub repository settings.
- CR-001 conditional go: P1-00 must characterize Android Native-to-Rust jitter before Android Practice Mode depends on the current MIDI hot path.

## Open Questions
1. Android p99 jitter follow-up is required in P1-00 per CR-001.
2. Frame-drop / animation validation is deferred to the first real animated Practice Mode path.
3. Metronome audio output latency — deferred to Phase 1 (P1-15)
4. Theme detection thresholds — TBD values in analytics-model.md, tuned during Phase 3
5. Velocity/dynamics scoring formula — deferred post-v1
