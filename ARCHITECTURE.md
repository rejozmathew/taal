# Taal Architecture Overview

**This is a living document.** It describes what the system looks like *right now*, not what it will look like eventually. Updated whenever a task adds a new component, changes a data flow, or introduces a dependency.

For product requirements, see [docs/prd.md](docs/prd.md). For specific contracts, see the [docs/specs/](docs/specs/) directory.

---

## Component Inventory

What currently exists in this repo (updated as code lands). Status is one of: **Implemented**, **Partial**, or **Planned**.

| Component | Location | Status |
|-----------|----------|--------|
| PRD + specs + plans | `docs/`, `plans/` | Implemented |
| Flutter app shell | `lib/`, `android/`, `windows/` | Implemented (empty Phase 0 app shell) |
| Rust core engine | `rust/` | Partial (Phase 0 bridge API + runtime skeleton; P1-01 content parsing/validation) |
| Rust content module | `rust/src/content/`, `rust/tests/content_validation.rs` | Implemented (P1-01 Lesson, InstrumentLayout, and ScoringProfile parsing/validation) |
| Flutter↔Rust bridge | `rust/`, `lib/src/rust/`, `rust_builder/` | Implemented (Phase 0 `greet` bridge) |
| Windows MIDI adapter | `windows/runner/windows_midi_adapter.*`, `lib/platform/midi/windows_midi_adapter.dart`, `native/windows/` | Implemented (Phase 0 NoteOn capture and latency benchmark validated) |
| Windows latency harness | `lib/platform/latency/`, `rust/src/api/simple.rs`, `artifacts/phase-0/` | Implemented (P0-05 release measurement captured) |
| Android MIDI adapter | `android/app/src/main/kotlin/dev/taal/taal/MainActivity.kt`, `lib/platform/midi/android_midi_adapter.dart`, `native/android/` | Implemented (Phase 0 NoteOn capture and latency benchmark validated) |
| Android latency artifact export | `android/app/src/main/kotlin/dev/taal/taal/MainActivity.kt`, `lib/platform/latency/` | Implemented (writes Phase 0 CSV/report to Android Downloads via MediaStore) |
| CI pipeline | `.github/workflows/ci.yml` | Implemented (Rust + Flutter checks/builds, locally validated) |
| Metronome audio output | `native/*/audio/` | Planned (Phase 1, P1-15) |
| SQLite persistence | `rust/src/storage/` | Planned (Phase 1, P1-08, P1-21) |
| MIDI mapping engine | `rust/src/midi/` | Planned (Phase 1, P1-06) |
| Practice views | `lib/features/player/` | Planned (Phase 1, P1-09/10/11) |
| Lesson Editor | `lib/features/studio/` | Planned (Phase 2) |
| Course Designer | `lib/features/studio/` | Planned (Phase 2) |
| Pack Builder | `lib/features/studio/` | Planned (Phase 2) |
| Analytics engine | `rust/src/analytics/` | Planned (Phase 3) |
| Backing track sync | `rust/` + native audio | Planned (Phase 3) |

**Status discipline:**
- **Implemented** — code exists and is passing tests
- **Partial** — code exists but is incomplete or behind feature flag
- **Planned** — referenced but not yet created

*Update this table after any task that creates, modifies, or removes a component, or shifts responsibility between layers.*

---

## System Layers

Taal has three layers with strict ownership boundaries.

```
┌──────────────────────────────────────┐
│           UI Layer (Flutter)          │
│                                      │
│  Screens, widgets, animations,       │
│  navigation, state management        │
│                                      │
│  Owns: all user-visible rendering    │
│  Does NOT own: timing, scoring,      │
│  content validation, persistence     │
└──────────────────▲───────────────────┘
                   │  flutter_rust_bridge (async FFI)
┌──────────────────┴───────────────────┐
│         Core Engine (Rust)            │
│                                      │
│  Content parsing, validation,        │
│  compilation. Session management,    │
│  hit grading, scoring, analytics.    │
│  SQLite persistence.                 │
│                                      │
│  Owns: all timing-critical logic,    │
│  all data models, all persistence    │
│  Does NOT own: rendering, MIDI I/O,  │
│  audio output                        │
└──────────────────▲───────────────────┘
                   │  Platform channels
┌──────────────────┴───────────────────┐
│      Native Platform Layer            │
│                                      │
│  MIDI device discovery/connection,   │
│  event capture with timestamps.      │
│  Low-latency audio output.           │
│                                      │
│  Owns: hardware I/O, OS-specific     │
│  APIs, monotonic timestamps          │
│  Does NOT own: mapping, scoring,     │
│  any business logic                  │
└──────────────────────────────────────┘
```

### Why This Split

- **Flutter** gives a single UI codebase for Windows, Android, iOS, macOS. Strong animation support for the note-highway and timing feedback.
- **Rust** ensures deterministic scoring with no GC pauses. The same compiled logic runs identically on every platform. All timing-sensitive decisions happen here.
- **Native layer** is intentionally thin: it captures MIDI events with the best available timestamp and passes audio scheduling commands to the OS audio API. No business logic.

**Key invariant:** Scoring correctness does not depend on UI frame rate. If Flutter drops to 30fps, visual feedback lags but grades are still computed correctly from native timestamps.

---

## Data Flow: Hit → Feedback

This is the critical path — the one that must complete in < 20ms perceived.

```
1. Drummer hits pad
       ↓
2. E-kit sends MIDI NoteOn via USB
       ↓
3. Native adapter captures event
   - Attaches monotonic timestamp (QueryPerformanceCounter / System.nanoTime)
   - Sends RawMidiEvent to Dart via platform channel
       ↓
4. Dart forwards to Rust via flutter_rust_bridge
       ↓
5. Rust MidiMapper resolves note → lane_id using DeviceProfile
   - Applies hi-hat CC4 state for articulation
   - Applies calibration offset
   - Deduplicates if needed
       ↓
6. Rust Session grades hit against nearest expected event
   - Computes delta_ms
   - Assigns Grade (Perfect/Good/Early/Late/Miss)
   - Updates combo, score, lane stats
   - Emits HitGraded event to event buffer
       ↓
7. Flutter drains event buffer on next frame (~16ms at 60fps)
   - Triggers animation on note-highway / notation / drum kit widget
   - Updates combo counter, score display
       ↓
8. User sees and feels the feedback
```

**Latency budget:**

| Segment | Target |
|---------|--------|
| Pad → OS MIDI callback | ~1-3ms (hardware) |
| MIDI callback → Rust | < 1ms |
| Rust grading | < 1ms |
| Rust → Flutter event | < 2ms |
| Flutter next frame | < 8ms (at 120fps) |
| **Total perceived** | **< 20ms** |

See [ADR-001](docs/adr/001-platform-architecture.md) for the latency spike that validates this.

### Current Phase 0 Bridge Flow

The implemented bridge scaffold proves the Flutter-to-Rust call path before the MIDI spike:

```
Flutter test / app
       ↓
lib/src/rust/frb_generated.dart
       ↓
rust_builder Cargokit plugin
       ↓
rust/src/api/simple.rs::greet(name)
       ↓
Dart receives "Hello, {name}!"
```

Flutter tests load the Rust release library from `rust/target/release/`, so CI builds that library before running `flutter test`.

### Current Phase 0 Runtime Skeleton

The implemented Rust runtime skeleton lives in `rust/src/runtime/session.rs`. It is intentionally narrow:

| Function | Purpose |
|----------|---------|
| `start_session()` | Creates a session with one hardcoded expected `kick` event at 1s |
| `submit_hit(session, InputHit)` | Grades a pre-resolved lane hit and queues `EngineEvent::HitGraded` |
| `session_tick(session, now_ns)` | Emits `EngineEvent::Missed` after the miss window if no hit was graded |
| `drain_events(session, max)` | Drains queued engine events for the UI/bridge harness |

The Phase 0 `InputHit` path bypasses MIDI note mapping and uses a pre-resolved `lane_id`, matching the spike constraint. The Rust enum definitions follow the frozen `engine-api.md` Grade and EngineEvent shapes even though only `HitGraded`, `Missed`, and `Warning` are used by the skeleton.

### Current Phase 0 Latency Harness

The latency harness records the P0-05/P0-07 measurement path in release builds:

```
Native MIDI callback
       ↓  T0: platform monotonic timestamp
Dart EventChannel listener
       ↓
flutter_rust_bridge synchronous call
       ↓  T1: Rust platform monotonic timestamp
Phase 0 Rust runtime skeleton submit_hit + drain_events
       ↓  T2: Rust platform monotonic timestamp
Flutter callback resumes
       ↓  T3: Dart Stopwatch timestamp calibrated to platform monotonic clock
CSV + summary report written under artifacts/phase-0/
```

On Windows, T0/T1/T2 use `QueryPerformanceCounter`. On Android, T0 is `System.nanoTime()` and Rust T1/T2 use `clock_gettime(CLOCK_MONOTONIC)`, matching the Android monotonic clock domain. T3 is calibrated from Dart `Stopwatch` to the platform monotonic clock for both platforms.

The harness uses a pre-resolved `kick` lane for every hit. It measures bridge and engine-path latency only; full MIDI note-to-lane mapping remains owned by the Rust MIDI mapping engine planned for Phase 1. Android release builds export CSV and summary artifacts to `Downloads/Taal/phase-0` via MediaStore so ADB can retrieve the measured data.

---

## Native MIDI Adapters

### Windows

The Phase 0 Windows MIDI adapter uses WinMM in the Flutter Windows runner. It exposes:

| Channel | Direction | Purpose |
|---------|-----------|---------|
| `taal/windows_midi` | Dart method channel | `listDevices`, `openDevice`, `closeDevice` |
| `taal/windows_midi/events` | Native event channel | Streams structured `note_on` maps |

The native callback filters MIDI NoteOn messages (`0x90` with velocity > 0), captures a monotonic `QueryPerformanceCounter` timestamp converted to nanoseconds, and posts the event to the runner window so Dart receives events on the Flutter platform thread.

Current validation status: the adapter compiles in the Windows release build. Runtime NoteOn validation passed with a Roland TD-27 exposed by WinMM as input device `0`; the Flutter Windows app received NoteOn events with channel, note, velocity, and monotonic nanosecond timestamps. P0-05 release measurement with 100 measured hits reported total native-to-Flutter latency p50 0.154 ms, p95 1.006 ms, p99 2.064 ms.

### Android

The Phase 0 Android MIDI adapter uses `android.media.midi.MidiManager` in the Flutter Android host activity. It exposes:

| Channel | Direction | Purpose |
|---------|-----------|---------|
| `taal/android_midi` | Dart method channel | `listDevices`, `openDevice`, `closeDevice` |
| `taal/android_midi/events` | Native event channel | Streams structured `note_on` maps |

The adapter enumerates MIDI devices with readable output ports, opens output port 0, connects it to a `MidiReceiver`, filters MIDI NoteOn messages (`0x90` with velocity > 0), and timestamps events with `System.nanoTime()` inside the receiver before posting structured events to Dart.

Current validation status: the adapter compiles in the Android release APK. Runtime NoteOn validation passed on a Samsung Fold 4 (`SM-F936U1`, Android 16/API 36) with a Roland TD-27 connected through USB-C OTG; the Flutter Android app received NoteOn events with device id, channel, note, velocity, and `System.nanoTime()` nanosecond timestamps. P0-07 release measurement with 100 measured hits reported total native-to-Flutter latency p50 2.218 ms, p95 14.180 ms, p99 25.161 ms.

---

## Content Model

All content (lessons, courses, packs) is defined by typed Rust structs and serialized as JSON.

### Key Entities

| Entity | What It Is | Defined In |
|--------|-----------|------------|
| Lesson | Timeline of expected musical events + metadata | [content-schemas.md](docs/specs/content-schemas.md) |
| Course | Ordered sequence of lessons with progression gates | [content-schemas.md](docs/specs/content-schemas.md) |
| Pack | Distribution bundle (.taalpack ZIP) | [content-schemas.md](docs/specs/content-schemas.md) |
| Instrument Layout | Lane definitions + visual mapping + MIDI hints | [content-schemas.md](docs/specs/content-schemas.md) |
| Scoring Profile | Timing windows, grade weights, combo rules | [content-schemas.md](docs/specs/content-schemas.md) |
| Device Profile | MIDI note→lane mapping, calibration, velocity curve | [midi-mapping.md](docs/specs/midi-mapping.md) |

The implemented Rust content module currently loads and validates `Lesson`, `InstrumentLayout`, and `ScoringProfile` JSON. It materializes the documented Lesson defaults for `assets`, `references`, and `optional_lanes`, validates the P1-01-owned schema invariants, and leaves lesson compilation/runtime use to later Phase 1 tasks.

### Content Representations

Content exists in three forms:

| Form | Context | Validation | Events Sorted? |
|------|---------|-----------|----------------|
| **Authoring** | Studio workspace | Lenient (drafts OK) | No |
| **Compiled** | Player runtime | Strict (all resolved) | Yes (by ms) |
| **Exported** | .taalpack file | Strict (schema-compliant) | Yes (by position) |

The `compile_lesson()` function transforms authoring → compiled form. This is a one-way, deterministic transformation.

### Time Model

- **Canonical:** Musical time — `{ bar, beat, tick }` with 480 ticks per beat
- **Derived:** Absolute milliseconds, computed from tempo map at load time
- **Authoring** uses musical time (intuitive for editing)
- **Playback** uses compiled ms times (required for scoring)

---

## Engine API

The Rust engine exposes a minimal, well-defined API surface. See [engine-api.md](docs/specs/engine-api.md) for the full contract.

### Session Lifecycle

```
Ready → Running → Paused → Running → Stopped
              ↘              ↗
               → Stopped (also valid from Running)
```

### Key Functions

```
compile_lesson(lesson, layout, scoring) → CompiledLesson
session_start(compiled, opts) → Session
session_on_hit(session, hit)           // Submit a MIDI hit
session_tick(session, now_ns)          // Advance time, detect misses
drain_events(session, max) → Vec<EngineEvent>  // Pull events for UI
session_stop(session) → AttemptSummary // End session, get results
```

### Canonical Grade Model

```rust
pub enum Grade {
    Perfect = 0,  // Within tight window
    Good    = 1,  // Within medium window
    Early   = 2,  // Before window
    Late    = 3,  // After window
    Miss    = 4,  // No hit registered
}
```

This enum is the same everywhere: engine, UI, analytics, visual language.

---

## Storage

All data is stored locally in SQLite, managed by the Rust engine. No cloud infrastructure.

| Data | Owner | Lifetime |
|------|-------|----------|
| Lessons, courses, layouts | Content system | Until user deletes |
| Device profiles | Per player profile | Until profile deleted |
| Practice attempts | Per player profile | Until user deletes |
| Performance themes | Derived from attempts | Recomputed periodically |
| Player profiles | Local | Until user deletes |

---

## Repository Structure

```
taal/
├── lib/                    # Flutter UI (Dart)
│   ├── features/           # Player, Studio, Library, Insights, Settings, Onboarding
│   ├── widgets/            # Shared: timeline, drum kit, transport, note highway
│   └── design/             # Design system tokens
├── android/                # Flutter Android host app
├── windows/                # Flutter Windows host app
├── rust/                   # Rust core engine crate
│   ├── Cargo.toml
│   └── src/
│       ├── api/            # Phase 0 bridge API surface
│       ├── content/        # P1-01 content schemas and validation
│       ├── runtime/        # Phase 0 session/grading skeleton
│       ├── frb_generated.rs
│       └── lib.rs
├── rust_builder/           # Cargokit Flutter plugin glue for Rust builds
├── native/                 # Platform-specific MIDI/audio
│   ├── android/
│   ├── windows/
│   └── ios/                # Future
├── docs/                   # Documentation
│   ├── prd.md              # Product requirements
│   ├── architecture.md     # This document
│   ├── adr/                # Architecture decisions
│   ├── specs/              # Technical specifications
│   └── coding-model.md     # Agent execution model
├── plans/                  # Phase execution plans
├── assets/                 # Bundled content + sounds
├── STATUS.md               # Project state
├── CHANGELOG.md            # Change log
└── README.md               # Public-facing description
```

---

## Key Design Decisions

All major decisions are documented as ADRs in [docs/adr/](docs/adr/).

| Decision | Choice | ADR |
|----------|--------|-----|
| Platform architecture | Flutter + Rust (pending spike) | [001](adr/001-platform-architecture.md) |
| Time representation | Musical time canonical, ms derived | 002 (planned) |
| Content format | Proprietary JSON, MusicXML for import/export | 003 (planned) |
| Storage | Local-first SQLite | 004 (planned) |
| Marketplace fields | Optional in schema, no system in v1 | 005 (planned) |

---

## Development Workflow

See [coding-model.md](docs/coding-model.md) for task templates, contract rules, and execution discipline.

**Key rules:**
- Task IDs are identifiers, not execution order. Respect the dependency graph.
- If you change a contract surface (engine API, schema, device profile), update the relevant spec in the same changeset.
- Frozen interfaces in STATUS.md cannot be changed without an explicit Change Request.
- Rust structs are canonical. JSON examples in docs are illustrative.

---

## Platform-Specific Notes

### Windows
- MIDI: WinRT MIDI API (or WinMM fallback)
- Audio: WASAPI exclusive mode for low-latency metronome
- Distribution: `.exe` installer via Inno Setup

### Android
- MIDI: `android.media.midi.MidiManager` (USB host mode)
- Audio: AAudio via Oboe library
- Distribution: Play Store AAB + sideload APK
- USB permission prompt required on first device connection
- Highest latency risk platform — validated by Phase 0 spike

### macOS / iOS (Future)
- MIDI: CoreMIDI
- Audio: CoreAudio
- Expected to have the best latency characteristics
