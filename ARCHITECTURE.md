# Taal Architecture Overview

**This is a living document.** It describes what the system looks like *right now*, not what it will look like eventually. Updated whenever a task adds a new component, changes a data flow, or introduces a dependency.

For product requirements, see [docs/prd.md](docs/prd.md). For specific contracts, see the [docs/specs/](docs/specs/) directory.

---

## Component Inventory

What currently exists in this repo (updated as code lands). Status is one of: **Implemented**, **Partial**, or **Planned**.

| Component | Location | Status |
|-----------|----------|--------|
| PRD + specs + plans | `docs/`, `plans/` | Implemented |
| Flutter app shell | `lib/` | Planned (Phase 0, P0-01) |
| Rust core engine | `rust/` | Planned (Phase 0, P0-02, P0-04) |
| Flutter↔Rust bridge | `rust/` + generated Dart | Planned (Phase 0, P0-02) |
| Windows MIDI adapter | `native/windows/` | Planned (Phase 0, P0-03) |
| Android MIDI adapter | `native/android/` | Planned (Phase 0, P0-06) |
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
├── rust/                   # Rust core engine
│   └── src/
│       ├── content/        # Parse, validate, compile
│       ├── runtime/        # Session, grading, scoring
│       ├── time/           # Musical ↔ ms conversion
│       ├── analytics/      # Aggregation, themes
│       ├── midi/           # Mapping, device profiles
│       └── storage/        # SQLite persistence
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
