# STATUS.md

## Project
- Name: Taal
- Repository: taal (fresh repo; legacy prototype archived as taal-legacy)
- PRD version: 1.9
- Current phase: Phase 1 in progress (P1-00 and P1-01 complete; P1-02 ready to proceed)
- Current task: P1-02 Rust Time Module - Musical <-> Millisecond Conversion (ready to proceed)
- Overall status: Phase 0 completed with conditional go via CR-001, and P1-00 resolved the required Android Native-to-Rust jitter follow-up. Two Android release-mode runs now show p99 tail latency localized to the pre-Rust delivery segment (`Native T0 -> Rust T1`), with Rust processing and Rust-to-Flutter return below 0.11 ms even at max. Repeat-run total p99 was 28.873 ms and max was 31.348 ms, still below the 40 ms no-go line. The current Android platform-channel path is acceptable for continuing Phase 1 with a documented caveat; no architecture change or direct JNI hot-path task is required now. Frame-drop validation remains deferred to the first real animated Practice Mode path. CR-002 is applied: the content schema defines the missing nested layout/scoring types, `InstrumentLayout.visual` remains required and is example-consistent, and P1-01 acceptance is narrowed to P1-01-owned validation fixtures. CR-003 is applied: Lesson ancillary nested types are defined, `assets`/`references`/`optional_lanes` have explicit JSON absence defaults. P1-01 is complete: the Rust content module now strictly parses and validates Lesson, InstrumentLayout, and ScoringProfile JSON for the clarified Phase 1 contracts.

## Release Boundary
- **MVP (Phases 0-2):** Playable + creatable + course runtime. Not yet distributed.
- **v1.0 (Phases 0-3):** Analytics, polish, backing tracks, packaged builds. First public release.

## Phase Gates
- [x] Phase 0: Foundation + Latency Spike (9 tasks; conditional go via CR-001)
- [ ] Phase 1: Core Practice Loop (2/28 tasks complete)
- [ ] Phase 2: Creator Studio + Content System + Course Runtime (18 tasks)
- [ ] Phase 3: Analytics + Polish + Distribution (23 tasks)
- [ ] Phase 4: AI Coach + Marketplace Prep + Multi-Platform
- [ ] Phase 5+: Marketplace + Keyboard + ML + Teacher/Classroom + Community

## Architecture Decision
- ADR-001 (Flutter + Rust): Accepted with conditional caveat via CR-001
- Conditional go criterion: Windows clean pass; Android p99 accepted as marginal with caveat after P1-00 confirmed the tail is pre-Rust delivery, not Rust processing
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
| ARCHITECTURE.md | v2 | When components/flows/boundaries change |
| README.md | v2 | When user-visible capabilities land |
| docs/prd.md | v1.9 | When scope or product rules change |
| docs/adr/001-platform-architecture.md | v1 | Immutable (status line only) |
| docs/specs/content-schemas.md | v1.3 | When content contracts change |
| docs/specs/engine-api.md | v1 | When engine contracts change |
| docs/specs/midi-mapping.md | v1 | When MIDI contracts change |
| docs/specs/analytics-model.md | v1 | When analytics contracts change |
| docs/specs/visual-language.md | v1 | When visual contracts change |
| docs/coding-model.md | v1 | When task execution rules change |
| plans/phase-0.md | v1.1 | Via CR when tasks need revision |
| plans/phase-1.md | v1.9 | Via CR when tasks need revision |
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
- P1-00 Android Native-to-Rust Jitter Investigation: Analysis of two Android release-mode latency runs confirmed the p99 tail is dominated by `Native T0 -> Rust T1` delivery. Original run: total p99 25.161 ms, max 30.982 ms. Repeat run: total p99 28.873 ms, max 31.348 ms. Combined 200-hit view: total p99 28.873 ms, max 31.348 ms, 7/200 hits exceeded 25 ms, 0/200 exceeded 40 ms. Rust processing remained <= 0.088 ms and Rust-to-Flutter return <= 0.107 ms. The current Android path is acceptable for Phase 1 with a stronger caveat; no ADR-001 update or architecture change required. Analysis artifact: `artifacts/phase-1/p1-00-android-native-to-rust-jitter-20260416-analysis.md`.
- P1-01 Rust Content Module - Parse Lesson, Layout, Scoring Profile: `rust/src/content/` now defines typed Rust structs and strict JSON load/validation entry points for `Lesson`, `InstrumentLayout`, and `ScoringProfile`. Validation covers required serde shapes, schema version `1.0`, Lesson lane/event/section/timing invariants, CR-003 defaults for `assets`/`references`/`optional_lanes`, required `InstrumentLayout.visual`, layout slot/articulation invariants, and scoring window/combo invariants. Focused Rust tests validate the present canonical lesson/layout examples and P1-01 scoring fixture plus invalid content cases.

## Maintenance
- 2026-04-16: `.gitignore` coverage updated for Flutter, Dart, Rust, Android, Gradle, Windows, and native build outputs; app/tool lockfiles and Gradle wrapper files remain visible to Git while generated build artifacts stay ignored.
- 2026-04-16: Root `flutter analyze` excludes `rust_builder/cargokit/build_tool/**` because that vendored Cargokit package has its own pubspec/dependencies and is not resolved by app-level `flutter pub get` in CI.
- 2026-04-16: CR-002 applied. `docs/specs/content-schemas.md` now defines the missing nested layout/scoring types needed for typed Rust deserialization, keeps `InstrumentLayout.visual` required with a synchronized example, and `plans/phase-1.md` narrows P1-01 acceptance to P1-01-owned validation fixtures. P1-01 is unblocked.
- 2026-04-16: P1-01 implementation paused before code changes. CR-003 records the remaining Lesson content-contract gap for ancillary nested type definitions and required-field/default behavior.
- 2026-04-16: CR-003 applied. `docs/specs/content-schemas.md` now defines the missing Lesson ancillary types (`TimeSignature`, `TempoEntry`, `MusicalPos`, `TimeRange`, `AssetRefs`, `ContentRefs`, `PublisherRef`), documents JSON absence defaults for `assets`, `references`, and `optional_lanes`, and keeps P1-01 scoped to later strict Rust parsing without starting implementation.
- 2026-04-16: P1-01 implemented. Added Rust serde/JSON/UUID dependencies, the Rust content module, and focused content validation tests. `ARCHITECTURE.md` now records the concrete Rust content component.

## Blockers
- None currently blocking P1-02. P1-01 is complete and the repo is ready for the next dependency-ordered Phase 1 task.

## Operational Caveats
- P0-08 merge blocking: CI workflow is present and locally validated, but GitHub branch protection / required status checks could not be verified from this environment (`gh` CLI unavailable; connector does not expose branch-protection settings). If not already enabled, require the CI checks in GitHub repository settings.
- P1-00 Android caveat: Android tail latency is localized before Rust entry, most likely within Android main-thread/EventChannel/Dart dispatch before the immediate Rust bridge call. Continue Phase 1 on the platform-channel path. The next Android latency measurement should split native-to-Dart delivery from Dart-to-Rust entry. Reconsider only if later full-path Android measurements show sustained p99 above 30 ms, total latency above 40 ms, or consistent frame drops on the real animated Practice Mode path.

## Open Questions
1. Frame-drop / animation validation is deferred to the first real animated Practice Mode path.
2. Metronome audio output latency — deferred to Phase 1 (P1-15)
3. Theme detection thresholds — TBD values in analytics-model.md, tuned during Phase 3
4. Velocity/dynamics scoring formula — deferred post-v1
