# STATUS.md

## Project
- Name: Taal
- Repository: taal (fresh repo; legacy prototype archived as taal-legacy)
- PRD version: 1.9
- Current phase: Phase 1 in progress (P1-00 through P1-06 complete)
- Current task: Next dependency-ready Phase 1 task is P1-16 Local Profiles; P1-07 remains dependent on P1-15 and has not started.
- Overall status: Phase 0 completed with conditional go via CR-001, and P1-00 resolved the required Android Native-to-Rust jitter follow-up. Two Android release-mode runs now show p99 tail latency localized to the pre-Rust delivery segment (`Native T0 -> Rust T1`), with Rust processing and Rust-to-Flutter return below 0.11 ms even at max. Repeat-run total p99 was 28.873 ms and max was 31.348 ms, still below the 40 ms no-go line. The current Android platform-channel path is acceptable for continuing Phase 1 with a documented caveat; no architecture change or direct JNI hot-path task is required now. Frame-drop validation remains deferred to the first real animated Practice Mode path. CR-002 is applied: the content schema defines the missing nested layout/scoring types, `InstrumentLayout.visual` remains required and is example-consistent, and P1-01 acceptance is narrowed to P1-01-owned validation fixtures. CR-003 is applied: Lesson ancillary nested types are defined, `assets`/`references`/`optional_lanes` have explicit JSON absence defaults. P1-01 is complete: the Rust content module now strictly parses and validates Lesson, InstrumentLayout, and ScoringProfile JSON for the clarified Phase 1 contracts. P1-02 is complete: the Rust time module now provides MusicalPos tick arithmetic and TimingIndex musical-position <-> millisecond conversion over constant and multi-tempo maps. P1-03 is complete: the Rust compile module now resolves validated content into deterministic `CompiledLesson` timelines with absolute-ms events, section ms ranges, lane IDs, resolved scoring profile, and duplicate lane/time rejection. P1-04 is complete: the Rust runtime session now starts from compiled lessons, enforces Ready/Running/Paused/Stopped transitions, accepts mapped hits, emits `HitGraded` and `Missed`, tracks combo and attempt metrics, and returns `AttemptSummary`. P1-05 is complete: the Rust scoring module now applies scoring profiles for grade windows, score normalization, combo and encouragement milestones, timing aggregates, and per-lane statistics. CR-004 is applied: the MIDI mapping spec now reserves generic `cc_map` out of P1-06, defines `DateTime` as an RFC 3339 UTC timestamp string, and clarifies that `created_at`/`updated_at` are required metadata for Phase 1 preset and persisted profile loading. P1-06 is complete: the Rust MIDI mapping module now loads Phase 1 device profiles without generic `cc_map`, maps raw NoteOn events to `MappedHit` results, tracks hi-hat CC4 state for auto articulation, applies calibration offsets, suppresses duplicate NoteOn bursts, and returns unmapped-note warning results without crashing.

## Release Boundary
- **MVP (Phases 0-2):** Playable + creatable + course runtime. Not yet distributed.
- **v1.0 (Phases 0-3):** Analytics, polish, backing tracks, packaged builds. First public release.

## Phase Gates
- [x] Phase 0: Foundation + Latency Spike (9 tasks; conditional go via CR-001)
- [ ] Phase 1: Core Practice Loop (7/28 tasks complete)
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
- [x] Rust engine API surface (engine-api.md §4) — confirmed for the current Phase 1 runtime/scoring surface after P1-04/P1-05

## Document Versions
| Document | Version | Update Trigger |
|----------|---------|----------------|
| AGENTS.md | v1 | When execution rules change |
| CLAUDE.md | v1 | Thin shim — rarely changes |
| ARCHITECTURE.md | v4 | When components/flows/boundaries change |
| README.md | v2 | When user-visible capabilities land |
| docs/prd.md | v1.9 | When scope or product rules change |
| docs/adr/001-platform-architecture.md | v1 | Immutable (status line only) |
| docs/specs/content-schemas.md | v1.3 | When content contracts change |
| docs/specs/engine-api.md | v1 | When engine contracts change |
| docs/specs/midi-mapping.md | v1.1 | When MIDI contracts change |
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
- P1-02 Rust Time Module - Musical <-> Millisecond Conversion: `rust/src/time/` now reuses the canonical content timing structs and provides `MusicalPos` tick arithmetic plus `TimingIndex` conversion between musical positions and absolute milliseconds. Focused Rust tests cover constant 120 BPM conversion, 480-tick subdivision precision, beat/bar-boundary arithmetic, grid-aligned round trips, multi-tempo conversion at and between tempo changes, and invalid tempo-map origin handling.
- P1-03 Rust Compile Module - Lesson to Execution Timeline: `rust/src/content/compile.rs` now implements `compile_lesson()` from validated `Lesson`, `InstrumentLayout`, and `ScoringProfile` inputs into the frozen `CompiledLesson` representation. Compilation validates layout/scoring references, builds a `TimingIndex`, emits events sorted by absolute `t_ms`, converts section boundaries to millisecond ranges, preserves musical positions and payloads, materializes lane IDs and resolved scoring profile, computes total duration, and rejects duplicate lane/time compiled events. Focused Rust tests cover event sorting, section ms conversion, determinism, and mismatched scoring profile handling.
- P1-04 Rust Runtime - Session Lifecycle: `rust/src/runtime/session.rs` now runs sessions against `CompiledLesson` timelines with `SessionOpts`, Ready/Running/Paused/Stopped state enforcement, expected-pulse lookahead on tick, nearest pending event matching by lane within the scoring window, miss detection on tick, event draining, idempotent stop, and `AttemptSummary` metrics including score, accuracy, timing bias, and per-lane stats. The Phase 0 latency helper remains available through compatibility wrappers. Focused Rust tests cover hit grading, expected pulse emission, miss emission, combo reset after miss, summary metrics, and invalid state transitions.
- P1-05 Rust Scoring - Timing Windows, Grades, Combos: `rust/src/scoring/` now owns profile-driven grade computation, score accumulation normalized to 0-100, combo and encouragement-tier tracking, configured milestone message generation, timing aggregate statistics, and per-lane stats. Runtime sessions now delegate scoring updates to this module and emit `ComboMilestone` plus `Encouragement` events when configured thresholds are reached. Focused Rust tests cover grade boundaries, score normalization/clamping, configured milestones, profile-dependent grading, and runtime milestone event emission.
- P1-06 MIDI Mapping Engine - Note to Lane, Hi-Hat CC4: `rust/src/midi/` now defines the Phase 1 `DeviceProfile`, `RawMidiEvent`, `MappedHit`, and `MappingResult` contracts in Rust and provides `MidiMapper` for raw NoteOn/CC input. The mapper resolves note-to-lane mappings in ordered profile order, tracks hi-hat `hihat_model.source_cc` state for auto articulation, applies `input_offset_ms`, suppresses duplicate NoteOn bursts inside `dedupe_window_ms`, returns unmapped-note warning results, and rejects reserved `cc_map` fields during Phase 1 profile loading. Focused Rust tests cover note-to-lane mapping, unmapped notes, CC4 hi-hat articulation, dedupe, calibration offset application, and CR-004 `cc_map` rejection.

## Maintenance
- 2026-04-16: `.gitignore` coverage updated for Flutter, Dart, Rust, Android, Gradle, Windows, and native build outputs; app/tool lockfiles and Gradle wrapper files remain visible to Git while generated build artifacts stay ignored.
- 2026-04-16: Root `flutter analyze` excludes `rust_builder/cargokit/build_tool/**` because that vendored Cargokit package has its own pubspec/dependencies and is not resolved by app-level `flutter pub get` in CI.
- 2026-04-16: CR-002 applied. `docs/specs/content-schemas.md` now defines the missing nested layout/scoring types needed for typed Rust deserialization, keeps `InstrumentLayout.visual` required with a synchronized example, and `plans/phase-1.md` narrows P1-01 acceptance to P1-01-owned validation fixtures. P1-01 is unblocked.
- 2026-04-16: P1-01 implementation paused before code changes. CR-003 records the remaining Lesson content-contract gap for ancillary nested type definitions and required-field/default behavior.
- 2026-04-16: CR-003 applied. `docs/specs/content-schemas.md` now defines the missing Lesson ancillary types (`TimeSignature`, `TempoEntry`, `MusicalPos`, `TimeRange`, `AssetRefs`, `ContentRefs`, `PublisherRef`), documents JSON absence defaults for `assets`, `references`, and `optional_lanes`, and keeps P1-01 scoped to later strict Rust parsing without starting implementation.
- 2026-04-16: P1-01 implemented. Added Rust serde/JSON/UUID dependencies, the Rust content module, and focused content validation tests. `ARCHITECTURE.md` now records the concrete Rust content component.
- 2026-04-16: P1-02 implemented. Added Rust time indexing/conversion, focused time conversion tests, and `ARCHITECTURE.md` now records the concrete Rust time component.
- 2026-04-16: P1-03 implemented. Added Rust lesson compilation and focused compile tests. `docs/specs/engine-api.md` now clarifies `CompileError::InvariantViolation` for strict compiled-runtime invariant failures.
- 2026-04-16: P1-04 implemented. Replaced the Phase 0 runtime internals with a compiled-lesson session lifecycle while preserving Phase 0 latency bridge wrappers. `docs/specs/engine-api.md` now defines `SessionOpts` and Result-returning lifecycle operations for invalid-state enforcement.
- 2026-04-16: P1-05 implemented. Added the Rust scoring module and focused scoring behavior tests; runtime sessions now emit configured combo milestone and encouragement events through the engine event stream.
- 2026-04-16: CR-004 applied. `docs/specs/midi-mapping.md` now reserves generic `cc_map` for a future spec revision, keeps P1-06 scoped to `note_map` plus `hihat_model.source_cc` for hi-hat CC4, defines `DateTime` as an RFC 3339 UTC timestamp string, and requires `created_at`/`updated_at` for Phase 1 preset and persisted profile loading.
- 2026-04-16: P1-06 implemented. Added the Rust MIDI mapping module and focused mapper tests; `ARCHITECTURE.md` now records the concrete Rust MIDI mapping component.

## Blockers
- None currently blocking the next dependency-ready Phase 1 task. CR-004 clarified the MIDI mapping contract blocker, P1-06 is complete, and the repo is ready for P1-16 Local Profiles. P1-07 remains dependent on P1-15.

## Operational Caveats
- P0-08 merge blocking: CI workflow is present and locally validated, but GitHub branch protection / required status checks could not be verified from this environment (`gh` CLI unavailable; connector does not expose branch-protection settings). If not already enabled, require the CI checks in GitHub repository settings.
- P1-00 Android caveat: Android tail latency is localized before Rust entry, most likely within Android main-thread/EventChannel/Dart dispatch before the immediate Rust bridge call. Continue Phase 1 on the platform-channel path. The next Android latency measurement should split native-to-Dart delivery from Dart-to-Rust entry. Reconsider only if later full-path Android measurements show sustained p99 above 30 ms, total latency above 40 ms, or consistent frame drops on the real animated Practice Mode path.

## Open Questions
1. Frame-drop / animation validation is deferred to the first real animated Practice Mode path.
2. Metronome audio output latency — deferred to Phase 1 (P1-15)
3. Theme detection thresholds — TBD values in analytics-model.md, tuned during Phase 3
4. Velocity/dynamics scoring formula — deferred post-v1
