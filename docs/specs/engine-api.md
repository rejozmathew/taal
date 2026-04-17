# Engine API Specification

**Companion to:** docs/prd.md Sections 3, 4.1, 11
**Status:** Minimum frozen contract — session lifecycle, grade model, and event types are stable. Implementation details TBD during Phase 1.

---

## Overview

The Rust core engine owns all timing-critical logic: content parsing, lesson compilation, real-time session management, grading, scoring, and analytics aggregation. The Flutter UI communicates with the engine via `flutter_rust_bridge` (async FFI). The engine is deterministic: given the same inputs, it produces identical outputs.

---

## 1. Canonical Grade Model

**This enum is authoritative across all documents. visual-language.md, analytics-model.md, and the PRD must match.**

```rust
#[repr(u8)]
pub enum Grade {
    Perfect = 0,  // Within tight window, delta ≈ 0
    Good    = 1,  // Within medium window
    Early   = 2,  // Before window, delta < 0
    Late    = 3,  // After window, delta > 0
    Miss    = 4,  // No hit registered within any window
}
```

Single enum, five states. `delta_ms` on `HitGraded` provides continuous offset for animation positioning.

---

## 2. Engine Ownership Boundaries

| Responsibility | Owner |
|---------------|-------|
| Content parsing and validation | Rust engine |
| Lesson compilation (authoring → runtime) | Rust engine |
| Session lifecycle | Rust engine |
| Hit grading | Rust engine |
| Combo/streak tracking | Rust engine |
| Score accumulation | Rust engine |
| MIDI note → lane mapping | Rust engine (using device profile) |
| Analytics aggregation | Rust engine |
| SQLite persistence | Rust engine |
| MIDI device I/O | Native platform layer |
| Audio output | Native platform layer |
| UI rendering | Flutter |

---

## 3. Session State Machine

```
  Ready ──session_start()──► Running ──session_stop()──► Stopped
                               │  ▲
                  session_pause()  session_resume()
                               │  │
                               ▼  │
                             Paused ──session_stop()──► Stopped
```

**Rules:**
- `session_on_hit()` and `session_tick()`: only valid in Running state
- `session_stop()`: valid from Running or Paused; returns `AttemptSummary`
- `session_stop()` is idempotent on Stopped session
- Stopped sessions cannot be restarted (create a new session)
- Invalid state operations return `SessionError::InvalidState`.

---

## 4. Core API Surface

```rust
// Content loading
fn load_lesson(json: &str) -> Result<Lesson, ContentError>
fn load_layout(json: &str) -> Result<InstrumentLayout, ContentError>
fn load_scoring_profile(json: &str) -> Result<ScoringProfile, ContentError>

// Compilation
fn compile_lesson(lesson: &Lesson, layout: &InstrumentLayout, scoring: &ScoringProfile)
    -> Result<CompiledLesson, CompileError>

// Session lifecycle
fn session_start(compiled: &CompiledLesson, opts: SessionOpts) -> Session
fn session_on_hit(session: &mut Session, hit: InputHit) -> Result<(), SessionError>
fn session_tick(session: &mut Session, now_ns: i128) -> Result<(), SessionError>
fn drain_events(session: &mut Session, max: usize) -> Vec<EngineEvent>
fn session_pause(session: &mut Session) -> Result<(), SessionError>
fn session_resume(session: &mut Session) -> Result<(), SessionError>
fn session_stop(session: &mut Session) -> Result<AttemptSummary, SessionError>
```

### Input: SessionOpts
```rust
pub struct SessionOpts {
    pub mode: PracticeMode,
    pub bpm: f32,
    pub start_time_ns: i128, // Monotonic session timeline origin
    pub lookahead_ms: i64,   // ExpectedPulse look-ahead window; 0 allowed
}
```

### Input: InputHit
```rust
pub struct InputHit {
    pub lane_id: String,        // Already mapped from MIDI note
    pub velocity: u8,
    pub timestamp_ns: i128,     // Monotonic, from native MIDI layer
    pub midi_note: Option<u8>,  // Debug/logging only
}
```

### Output: EngineEvent
```rust
pub enum EngineEvent {
    ExpectedPulse { expected_id: String, lane_id: String, t_expected_ms: i64 },
    HitGraded { expected_id: String, lane_id: String, grade: Grade, delta_ms: f32,
                combo: u32, streak: u32, score_running: f32 },
    Missed { expected_id: String, lane_id: String },
    ComboMilestone { combo: u32 },
    Encouragement { message_id: String, text: String },
    SectionBoundary { section_id: String, entering: bool },
    MetronomeClick { t_ms: i64, accent: bool },
    Warning { code: String, message: String },
}
```

### Output: AttemptSummary
```rust
pub struct AttemptSummary {
    pub lesson_id: Uuid,
    pub mode: PracticeMode,
    pub bpm: f32,
    pub duration_ms: u64,
    pub score_total: f32,
    pub accuracy_pct: f32,
    pub hit_rate_pct: f32,
    pub perfect_pct: f32, pub early_pct: f32, pub late_pct: f32, pub miss_pct: f32,
    pub max_streak: u32,
    pub mean_delta_ms: f32, pub std_delta_ms: f32,
    pub median_delta_ms: Option<f32>, pub p90_abs_delta_ms: Option<f32>,
    pub lane_stats: HashMap<String, LaneStats>,
}
```

---

## 5. Event Ordering and Delivery

- Events ordered by production time (not musical time)
- `HitGraded`: produced immediately on `session_on_hit`
- `Missed`: produced on `session_tick` after miss window expires
- `ExpectedPulse`: produced by `session_tick` as events enter look-ahead window
- Buffer max: 256 events. If exceeded, oldest `ExpectedPulse` dropped first. `HitGraded` and `Missed` never dropped.
- UI calls `drain_events` at frame rate (~60fps). Tick is the engine's clock — no internal timer.

---

## 6. Performance Guarantees

| Operation | Target |
|-----------|--------|
| `session_on_hit` | < 1ms typical, < 3ms worst |
| `session_tick` | < 1ms typical |
| `drain_events` | < 0.5ms |
| `compile_lesson` | < 50ms for 500-event lesson |

Hot-path rules: no heap allocations, no locking, no I/O.

**Determinism:** Same inputs + same timestamps → identical outputs. Enables replay and testing.

---

## 7. Error Model

```rust
pub enum ContentError { InvalidJson(String), SchemaViolation { field, message },
    InvariantViolation { rule, message }, UnsupportedSchemaVersion { found, supported } }
pub enum CompileError { MissingLayout { layout_id }, MissingScoringProfile { profile_id },
    EmptyLesson, InvalidTempoMap(String), InvariantViolation { rule, message } }
pub enum SessionError { InvalidState { current: SessionState, attempted: String } }
```

Errors returned as `Result`. Flutter bridge converts to Dart exceptions with human-readable messages.

`CompileError::InvariantViolation` is used when compilation detects a strict compiled-runtime invariant violation
that is not a content JSON parse error, such as duplicate expected events for the same `lane_id` at the same compiled
millisecond timestamp.

---

## 8. Shared Definitions

These types are referenced across multiple specs and must be consistent everywhere.

### PracticeMode

```rust
pub enum PracticeMode {
    Practice,    // Tempo adjustable, A-B loop, full feedback, infinite retries
    Play,        // Fixed tempo, scored run, no pauses, review at end
    CourseGate,  // Like Play but with pass/fail gating per course rules
}
```

Referenced in: prd.md (Section 4.1.3), content-schemas.md (PracticeDefaults), analytics-model.md (PracticeAttempt).

### CompiledLesson

The runtime representation of a lesson, produced by `compile_lesson()`. Immutable during a session.

```rust
pub struct CompiledLesson {
    pub lesson_id: Uuid,
    pub timing_index: TimingIndex,              // Bidirectional pos ↔ ms lookup
    pub events: Vec<CompiledEvent>,             // Sorted by t_ms (ascending)
    pub sections: Vec<CompiledSection>,         // Ranges in ms
    pub lane_ids: Vec<String>,                  // All lanes in this lesson
    pub scoring_profile: ScoringProfile,        // Resolved (not a reference)
    pub total_duration_ms: i64,
}

pub struct CompiledEvent {
    pub expected_id: String,
    pub lane_id: String,
    pub t_ms: i64,                              // Absolute time in milliseconds
    pub pos: MusicalPos,                        // Original musical position (preserved for display)
    pub payload: EventPayload,                  // Hit or Note
}

pub struct CompiledSection {
    pub section_id: String,
    pub label: String,
    pub start_ms: i64,
    pub end_ms: i64,                            // Exclusive
    pub loopable: bool,
}
```

**Guarantees:**
- `events` is sorted by `t_ms` (ascending). No duplicates at the same t_ms + lane_id.
- All `lane_id` values exist in `lane_ids`.
- All section ranges are non-overlapping with exclusive end boundaries.
- Immutable after creation. The session reads from it but never writes to it.
- Differs from authoring form: events may be unsorted in workspace; compiled form is always sorted and fully resolved.

### PlayerProfile

```rust
pub struct PlayerProfile {
    pub id: Uuid,
    pub name: String,
    pub avatar: Option<String>,                 // Predefined avatar ID or custom
    pub experience_level: ExperienceLevel,
    pub preferred_view: PracticeView,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}

pub enum ExperienceLevel { Beginner, Intermediate, Teacher }
pub enum PracticeView { NoteHighway, Notation }
```

**Ownership:** A player profile owns: practice attempts, device profiles, preferences. Deleting a profile deletes all owned data.

Referenced in: prd.md (Section 10.4), analytics-model.md (PracticeAttempt.player_id).

---

## 9. MetronomeClick Clarification

`MetronomeClick` in the `EngineEvent` enum is a **timing schedule event**, not audio output. The engine emits it to tell the platform audio layer when to trigger a click sample.

Flow:
1. Engine emits `MetronomeClick { t_ms, accent }` via `drain_events`
2. Flutter receives it and forwards to the native audio layer
3. Native audio layer schedules the click sample at the specified time using the platform's low-latency audio API (WASAPI/AAudio)

The engine is the timing authority. The native audio layer is the sound output. The engine never produces audio directly.
