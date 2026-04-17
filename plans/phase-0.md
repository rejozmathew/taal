# Phase 0: Foundation + Latency Spike

**Objective:** Prove the Flutter + Rust architecture works for MIDI-to-feedback at acceptable latency. Set up the monorepo. Establish frozen interfaces.

**Duration estimate:** 1-2 agentic coding sessions

---

## Execution Order

Task IDs remain stable references. Execute Phase 0 in the order below unless a blocker, approved CR, or newly discovered contradiction requires a narrower clarification pass.

1. **P0-01** Monorepo Scaffold
2. **P0-02** flutter_rust_bridge Integration
3. **P0-03** Windows MIDI Adapter
4. **P0-04** Rust Engine Skeleton
5. **P0-05** End-to-End Latency Measurement (Windows)
6. **P0-06** Android MIDI Adapter
7. **P0-07** Android Latency Measurement
8. **P0-08** CI Pipeline
9. **P0-09** ADR-001 Finalization

**Execution notes**
- `P0-08` is intentionally listed near the end even though it depends only on `P0-01`; this keeps the scaffold and latency spike path moving first while still making CI part of the Phase 0 completion tranche.
- If a task in this order is already complete, continue with the next dependency-ready task rather than renumbering anything.

---

## Tasks

### P0-01: Monorepo Scaffold

**Objective:** Create the repository structure with Flutter app, Rust workspace, and native platform directories.

**Outputs:**
- Flutter project initialized (`lib/`, `pubspec.yaml`)
- Rust workspace (`rust/Cargo.toml`, `rust/src/lib.rs`)
- Native platform directories (`native/android/`, `native/windows/`)
- `docs/`, `plans/`, `assets/` directories
- `.gitignore`, `README.md`, `STATUS.md`, `CHANGELOG.md`
- Basic CI workflow (`.github/workflows/ci.yml`)

**Acceptance criteria:**
- `flutter build` succeeds (empty app)
- `cargo check` succeeds (empty lib)
- CI workflow runs on push

---

### P0-02: flutter_rust_bridge Integration

**Deps:** P0-01

**Objective:** Establish the bridge between Flutter and Rust with a working async call.

**Outputs:**
- flutter_rust_bridge configured in `pubspec.yaml` and Cargo.toml
- A simple Rust function callable from Dart (`fn greet(name: String) -> String`)
- Code generation working (`flutter_rust_bridge_codegen`)
- Unit test in Dart that calls Rust and verifies return

**Acceptance criteria:**
- Dart calls Rust function, gets result, test passes
- Works on both Windows and Android builds

---

### P0-03: Windows MIDI Adapter

**Deps:** P0-01

**Objective:** Capture USB MIDI NoteOn events on Windows with monotonic timestamps.

**Outputs:**
- Windows platform channel that:
  - Enumerates connected MIDI devices
  - Opens a connection to a selected device
  - Captures NoteOn events with `QueryPerformanceCounter` timestamps
  - Passes events to Dart as structured messages
- Test: connect a MIDI device, hit a pad, see the event logged in Dart console

**Acceptance criteria:**
- NoteOn events received with note number, velocity, and nanosecond timestamp
- Timestamp source is monotonic (not wall clock)

---

### P0-04: Rust Engine Skeleton

**Deps:** P0-02

**Objective:** Minimal Rust engine that accepts a hit and emits a graded result.

**Important note:** Phase 0 uses a simplified hit contract for timing measurement only. `InputHit` contains a pre-resolved `lane_id`, bypassing the full MIDI mapping pipeline. The real app path (raw MIDI note → MidiMapper → lane_id → runtime) is implemented in Phase 1 (P1-06). The spike proves latency characteristics of the bridge and engine, not the complete input pipeline.

**Outputs:**
- `rust/src/runtime/session.rs`: start session, submit hit, drain events
- `InputHit` struct: `{ lane_id, velocity, timestamp_ns }`
- `EngineEvent` enum: `HitGraded { grade, delta_ms, combo }`
- Hardcoded single expected event for testing
- Unit tests for hit grading logic

**Acceptance criteria:**
- Submit a hit near the expected time → get `Perfect` grade
- Submit a hit far from expected time → get `Late` or `Early`
- Submit no hit after window passes → get `Miss` on tick
- All unit tests pass

---

### P0-05: End-to-End Latency Measurement (Windows)

**Deps:** P0-03, P0-04

**Objective:** Measure actual latency from MIDI NoteOn to Flutter callback on Windows.

**Outputs:**
- Test harness that:
  - Captures MIDI NoteOn with native timestamp (T0)
  - Passes through Rust engine (timestamp T1 entry, T2 exit)
  - Returns to Flutter (timestamp T3)
  - Logs all timestamps
- Report: p50, p95, p99 latency for each segment and total
- Minimum 100 hits measured (after 10-hit warm-up)
- **Must be measured in release build, not debug**

**Required artifacts (committed to repo or attached to ADR-001):**
- CSV/JSON raw timing log
- Summary report with p50/p95/p99
- Hardware/software matrix (PC specs, OS version, MIDI device model)

**Acceptance criteria:**
- Latency data collected and documented
- Written into ADR-001 as measured evidence

---

### P0-06: Android MIDI Adapter

**Deps:** P0-01

**Objective:** Capture USB MIDI NoteOn events on Android with monotonic timestamps.

**Outputs:**
- Android platform channel using `android.media.midi.MidiManager`
- USB MIDI device enumeration and connection
- NoteOn capture with `System.nanoTime()` timestamps
- Events passed to Dart

**Acceptance criteria:**
- NoteOn events received on Android tablet via USB MIDI
- Timestamps are monotonic

---

### P0-07: Android Latency Measurement

**Deps:** P0-06, P0-04

**Objective:** Same latency measurement as P0-05 but on Android.

**Outputs:**
- Same test harness adapted for Android
- Latency report for Android tablet (specify device model)

**Acceptance criteria:**
- Latency data collected and documented
- Written into ADR-001

---

### P0-08: CI Pipeline

**Deps:** P0-01

**Objective:** Automated build and test on every push.

**Outputs:**
- GitHub Actions workflow:
  - Rust: `cargo check`, `cargo test`, `cargo clippy`
  - Flutter: `flutter analyze`, `flutter test`
  - Build: Windows and Android (at least check compilation)

**Acceptance criteria:**
- CI runs on push to main and on PRs
- Failures block merge

---

### P0-09: ADR-001 Finalization

**Deps:** P0-05, P0-07

**Objective:** Finalize the architecture decision based on measured latency data.

**Outputs:**
- Updated ADR-001 with:
  - Measured latency numbers (Windows + Android)
  - Go/no-go decision
  - Any adjustments to the architecture

**Acceptance criteria:**
- ADR-001 status changed from "Proposed" to "Accepted" or "Rejected"
- If rejected, alternative architecture documented

---

## Audio Output Latency (Deferred to Phase 1)

Phase 0 focuses on MIDI input latency (the critical path for scoring correctness). Metronome audio output latency is also important for user experience but is:
- Less architecturally risky (platform audio APIs are well-understood)
- Independently solvable (audio latency does not affect scoring accuracy)
- Best measured with a real metronome implementation, not a spike

Audio output timing validation is included in Phase 1 task P1-15 (Metronome Audio Output). If metronome sync is poor, the fix is isolated to the audio scheduling layer — it does not affect the core architecture decision.

---

## Exit Criteria for Phase 0

- [ ] Measured end-to-end MIDI input latency on Windows (USB MIDI): documented in ADR-001
- [ ] Measured end-to-end MIDI input latency on Android (USB MIDI): documented in ADR-001
- [ ] Benchmark artifacts committed (CSV logs, summary reports, hardware matrix)
- [ ] Go/no-go decision made and recorded in ADR-001
- [ ] If go: Rust engine skeleton accepts hits and emits grades
- [ ] CI builds and tests pass
- [ ] STATUS.md updated with Phase 0 completion
