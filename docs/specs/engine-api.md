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

Practice attempt persistence is intentionally outside the session lifecycle API. `session_stop(session)` remains a summary-only operation and must not accept player/content/device persistence context or perform SQLite I/O. P1-21 writes `PracticeAttempt` records through the separate Rust storage API defined in `analytics-model.md`, using the returned `AttemptSummary` plus `PracticeAttemptContext`.

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
    pub lane_id: String,        // Semantic lane resolved from MIDI mapping or touch input
    pub velocity: u8,
    pub timestamp_ns: i128,     // Monotonic input timestamp aligned to SessionOpts.start_time_ns
    pub midi_note: Option<u8>,  // Some(raw MIDI note) for MIDI hits, None for touch input
}
```

`InputHit` is source-neutral after lane resolution. MIDI input reaches this shape after the Rust `MidiMapper` produces a `MappedHit`. Touch input reaches this shape when the P1-23 tap-pad surface selects a semantic `lane_id` from the active layout. Both sources must use monotonic timestamps in the same clock domain as `SessionOpts.start_time_ns` so `session_on_hit()` can apply identical Rust timing and scoring semantics.

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

---

## 10. Settings and Preferences Persistence (P1-20)

P1-20 settings persistence is Rust-owned SQLite storage exposed to Flutter through `flutter_rust_bridge`. Flutter owns rendering, interaction, and applying returned values to UI/native adapters. Settings reads and writes are not part of the timing-sensitive session hot path.

### Ownership Split

| Level | Owns | Default |
|-------|------|---------|
| App-level | `last_active_profile_id` | `None` until a profile is created |
| App-level | `audio_output_device_id` | `None` = platform default output device |
| Profile-level | `preferred_view` | `PracticeView::NoteHighway` |
| Profile-level | `theme` | `ThemePreference::System` |
| Profile-level | `reduce_motion` | `false` |
| Profile-level | `high_contrast` | `false` |
| Profile-level | `metronome_volume` | `0.8` |
| Profile-level | `metronome_click_sound` | `ClickSoundPreset::Classic` |
| Profile-level | `auto_pause_enabled` | `false` |
| Profile-level | `auto_pause_timeout_ms` | `3000` |
| Profile-level | `record_practice_mode_attempts` | `true` |
| Profile-level | `daily_goal_minutes` | `10` |
| Profile-level | `play_kit_hit_sounds` | `false` |
| Profile-level | `active_device_profile_id` | `None` until the player chooses or reconnects a device profile |
| Device-profile-level | `input_offset_ms` | See `midi-mapping.md` |
| Device-profile-level | `dedupe_window_ms` | See `midi-mapping.md` |
| Device-profile-level | `velocity_curve` | See `midi-mapping.md` |

Raw platform MIDI port handles are not authoritative persisted settings in Phase 1 because platform IDs can be unstable. The persisted MIDI selection is the player profile's `active_device_profile_id` plus the existing per-player last-used device-profile reconnect mapping.

Profile identity remains in `PlayerProfile`. P1-20 profile-name editing updates `PlayerProfile.name`; switching/managing profiles uses the existing local-profile APIs.

### Settings Types

```rust
pub struct AppSettings {
    pub last_active_profile_id: Option<Uuid>,
    pub audio_output_device_id: Option<String>,
}

pub struct ProfileSettings {
    pub player_id: Uuid,
    pub preferred_view: PracticeView,
    pub theme: ThemePreference,
    pub reduce_motion: bool,
    pub high_contrast: bool,
    pub metronome_volume: f32,               // 0.0..=1.0
    pub metronome_click_sound: ClickSoundPreset,
    pub auto_pause_enabled: bool,
    pub auto_pause_timeout_ms: u32,          // milliseconds
    pub record_practice_mode_attempts: bool,
    pub daily_goal_minutes: u32,             // positive whole minutes; default 10
    pub play_kit_hit_sounds: bool,           // app drum sounds on MIDI kit hits; default false
    pub active_device_profile_id: Option<Uuid>,
    pub updated_at: DateTime,
}

pub struct ProfileSettingsUpdate {
    pub preferred_view: PracticeView,
    pub theme: ThemePreference,
    pub reduce_motion: bool,
    pub high_contrast: bool,
    pub metronome_volume: f32,
    pub metronome_click_sound: ClickSoundPreset,
    pub auto_pause_enabled: bool,
    pub auto_pause_timeout_ms: u32,
    pub record_practice_mode_attempts: bool,
    pub daily_goal_minutes: u32,
    pub play_kit_hit_sounds: bool,
    pub active_device_profile_id: Option<Uuid>,
}

pub enum ThemePreference { System, Light, Dark }
pub enum ClickSoundPreset { Classic, Woodblock, HiHat }

pub struct SettingsSnapshot {
    pub app: AppSettings,
    pub profile: ProfileSettings,
}
```

`active_device_profile_id`, when present, must reference a `DeviceProfile` owned by the same player profile. If the referenced device profile is deleted, Rust storage must clear the profile setting or return `None` on the next settings read.

### Rust Storage API Shape

The storage layer must support:

```rust
fn load_settings_snapshot(player_id: Uuid) -> Result<SettingsSnapshot, StorageError>
fn update_app_settings(settings: AppSettings) -> Result<AppSettings, StorageError>
fn update_profile_settings(player_id: Uuid, update: ProfileSettingsUpdate) -> Result<ProfileSettings, StorageError>
fn update_player_profile_name(player_id: Uuid, name: String) -> Result<PlayerProfile, StorageError>
```

Device-profile-owned settings are updated through the existing device-profile persistence boundary. P1-20 may expose a narrower helper, but it must preserve the `DeviceProfile` contract from `midi-mapping.md`:

```rust
fn update_device_profile_settings(
    player_id: Uuid,
    device_profile_id: Uuid,
    input_offset_ms: f32,
    velocity_curve: VelocityCurve,
) -> Result<DeviceProfile, StorageError>
```

### Flutter Bridge Shape

The `flutter_rust_bridge` layer may use DTOs or JSON, matching the existing profile and device-profile APIs. It must expose equivalent operations that accept the database path used by the existing Rust-owned SQLite stores:

```rust
fn load_settings_snapshot(database_path: String, player_id: String) -> SettingsOperationResult
fn update_app_settings(database_path: String, settings_json: String) -> SettingsOperationResult
fn update_profile_settings(database_path: String, player_id: String, settings_update_json: String) -> SettingsOperationResult
fn update_player_profile_name(database_path: String, player_id: String, name: String) -> LocalProfileOperationResult
fn update_device_profile_settings(
    database_path: String,
    player_id: String,
    device_profile_id: String,
    input_offset_ms: f32,
    velocity_curve: VelocityCurveDto,
) -> DeviceProfileOperationResult
```

Successful updates return the updated settings or profile/device-profile snapshot so Flutter can apply changes immediately without an app restart. Validation errors must be returned through the same result/error pattern as the existing profile and device-profile bridge APIs.

P1-24 daily practice goal writes reuse `update_profile_settings(...)` with the `daily_goal_minutes` field. The settings boundary must not add a separate dedicated daily-goal write API.
