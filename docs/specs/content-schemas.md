# Content Schemas Specification

**Companion to:** docs/prd.md Section 5 & 9
**Status:** Contract — struct shapes and invariants are frozen. Field-level details may be refined during implementation. Rust structs are canonical; JSON examples are illustrative.

---

## Overview

This document defines the canonical data structures for Taal's content system. All schemas are defined as typed Rust structs in the core engine and exported as JSON Schema for validation.

**Important:** The Rust struct definitions are the source of truth. JSON examples in this document are illustrations, not canonical. If code and docs diverge, the code wins.

---

## 1. Lesson

A lesson is the atomic unit of practice content: a timeline of expected musical events with metadata, sections, and practice rules.

### Key Design Decisions
- Time is represented in musical positions (bar/beat/tick), not milliseconds
- Events are instrument-agnostic: drums use `hit` payloads, keyboard (future) uses `note` payloads
- Sections define named time ranges for A-B looping
- Marketplace fields are optional and ignored in local workflows

### Struct Outline

```rust
pub struct Lesson {
    pub id: Uuid,
    pub schema_version: String,  // "1.0"
    pub revision: String,        // "1.0.0" semver
    pub title: String,
    pub description: Option<String>,
    pub language: Option<String>, // "en"

    pub instrument: InstrumentRef,
    pub timing: TimingConfig,
    pub lanes: Vec<Lane>,
    pub sections: Vec<Section>,
    pub practice: PracticeDefaults,
    pub metadata: LessonMeta,
    pub optional_lanes: Vec<String>,  // Optional in JSON; default: empty (all lanes required)
    pub scoring_profile_id: Option<String>,

    pub assets: AssetRefs,            // Optional in JSON; default: no asset refs
    pub references: ContentRefs,      // Optional in JSON; default: empty refs object

    // Optional marketplace fields
    pub publisher: Option<PublisherRef>,
    pub extensions: Option<serde_json::Value>,
}

pub struct InstrumentRef {
    pub family: String,    // "drums"
    pub variant: String,   // "kit"
    pub layout_id: String, // "std-5pc-v1"
}

pub struct TimingConfig {
    pub time_signature: TimeSignature,  // { num: 4, den: 4 }
    pub ticks_per_beat: u16,            // 480 (MIDI PPQ)
    pub tempo_map: Vec<TempoEntry>,     // [{ pos, bpm }]
}

pub struct TimeSignature {
    pub num: u8,  // Beats per bar
    pub den: u8,  // Beat unit denominator
}

pub struct TempoEntry {
    pub pos: MusicalPos,
    pub bpm: f32,
}

pub struct MusicalPos {
    pub bar: u32,  // 1-based
    pub beat: u8,  // 1-based within the bar
    pub tick: u16, // 0-based within the beat
}

pub struct TimeRange {
    pub start: MusicalPos,
    pub end: MusicalPos,  // Exclusive
}

pub struct Lane {
    pub lane_id: String,  // "kick", "snare", "hihat"
    pub events: Vec<Event>,
}

pub struct Event {
    pub event_id: String,
    pub pos: MusicalPos,         // { bar, beat, tick }
    pub duration_ticks: u16,     // 0 for drum hits
    pub payload: EventPayload,   // Hit { velocity, articulation } or Note { pitch, velocity }
}

pub struct Section {
    pub section_id: String,
    pub label: String,
    pub range: TimeRange,  // { start: MusicalPos, end: MusicalPos }
    pub loopable: bool,
}

pub struct PracticeDefaults {
    pub modes_supported: Vec<PracticeMode>,
    pub count_in_bars: u8,
    pub metronome_enabled: bool,
    pub start_tempo_bpm: f32,
    pub tempo_floor_bpm: Option<f32>,
}

pub struct LessonMeta {
    pub difficulty: Option<String>,  // "beginner" | "intermediate" | "advanced"
    pub tags: Vec<String>,
    pub skills: Vec<String>,         // Learning outcome taxonomy IDs
    pub objectives: Vec<String>,     // Human-readable learning objectives
    pub prerequisites: Vec<String>,  // Skills assumed
    pub estimated_minutes: Option<u16>,
}

pub struct AssetRefs {
    pub backing: Option<String>,  // User-provided backing audio label or relink key; no audio bytes in v1 packs
    pub artwork: Option<String>,  // Relative artwork asset path when packaged or present in a workspace
}

pub struct ContentRefs {}

pub type PublisherRef = serde_json::Map<String, serde_json::Value>;
```

### Lesson Ancillary Types and Defaults

`MusicalPos` uses 1-based `bar` and `beat` values and a 0-based `tick` value. When validating a position against a lesson's timing config, `bar >= 1`, `1 <= beat <= time_signature.num`, and `tick < ticks_per_beat`. Position ordering is lexicographic by `(bar, beat, tick)`.

`TimeRange.end` is exclusive. A valid range has `end > start`, as also required by the lesson invariants.

`assets`, `references`, and `optional_lanes` are optional in Lesson JSON for schema version `1.0`, but the canonical Rust load result materializes defaults:

- Missing `assets` defaults to `AssetRefs { backing: None, artwork: None }`.
- Missing `references` defaults to `ContentRefs {}`. `ContentRefs` intentionally has no fields in schema version `1.0`; future reference metadata requires an explicit schema update.
- Missing `optional_lanes` defaults to an empty list, which means all lanes used by the lesson are required.

`publisher` is optional marketplace metadata. If present, it must be a JSON object. Local Phase 1 loading parses it as `PublisherRef` and ignores it for validation, playback, scoring, and layout compatibility.

### Event Payloads (instrument-specific)

```rust
pub enum EventPayload {
    Hit {
        velocity: u8,           // 1-127
        articulation: String,   // "normal", "accent", "ghost", "rim", "open", "closed"
    },
    // Future: keyboard support
    Note {
        pitch: u8,              // MIDI note number
        velocity: u8,
        // duration is in the parent Event.duration_ticks
    },
}
```

---

## 2. Course

A course is an ordered sequence of lessons with progression rules.

### Struct Outline

```rust
pub struct Course {
    pub id: Uuid,
    pub schema_version: String,
    pub revision: String,
    pub title: String,
    pub description: Option<String>,
    pub instrument_family: String,

    pub nodes: Vec<CourseNode>,
    pub edges: Vec<CourseEdge>,
    pub progression: ProgressionConfig,
    pub metadata: CourseMeta,

    pub publisher: Option<PublisherRef>,
    pub extensions: Option<serde_json::Value>,
}

pub struct CourseNode {
    pub node_id: String,
    pub node_type: String,   // "lesson"
    pub lesson_id: Uuid,
    pub label: String,
}

pub struct CourseEdge {
    pub from: String,        // node_id
    pub to: String,          // node_id
    pub condition: EdgeCondition,
}

pub enum EdgeCondition {
    Always,
    MinScore { min_score: f32 },
    // Future: MinStreak, BranchChoice, etc.
}

pub struct ProgressionConfig {
    pub mode: String,  // "gated" | "open"
    pub default_gate: GateConfig,
    pub overrides: HashMap<String, GateConfig>,  // node_id → custom gate
}

pub struct GateConfig {
    pub min_score: Option<f32>,
    pub max_retries: Option<u32>,
    pub allow_practice_before_retry: bool,
}
```

---

## 3. Instrument Layout

Defines the semantic lanes and visual mapping for an instrument family.
`visual` is required. It provides the stable slot mapping used by the visual drum kit in mapping, calibration, settings, and practice flows.

```rust
pub struct InstrumentLayout {
    pub id: String,
    pub schema_version: String,
    pub family: String,
    pub variant: String,
    pub lanes: Vec<LaneDefinition>,
    pub visual: VisualConfig,
}

pub struct LaneDefinition {
    pub lane_id: String,
    pub label: String,
    pub midi_hints: Vec<MidiHint>,
    pub articulations: Option<Vec<ArticulationDef>>,
}

pub struct MidiHint {
    pub hint_type: String,  // "note" | "cc"
    pub values: Vec<u8>,
}

pub struct ArticulationDef {
    pub id: String,       // "closed", "open", "pedal"
    pub label: String,
    pub midi_note: u8,    // Representative note hint for this articulation
}

pub struct VisualConfig {
    pub lane_slots: Vec<VisualSlot>,
}

pub struct VisualSlot {
    pub lane_id: String,  // Must reference a lane in `lanes`
    pub slot_id: String,  // Stable widget slot token, e.g. "kick", "snare", "hihat"
}
```

---

## 4. Scoring Profile

Scoring profiles parameterize timing windows, relative grade weights, and encouragement thresholds.
Combo accumulation/reset behavior is frozen by `docs/specs/analytics-model.md` §8 and `docs/specs/visual-language.md` C.4; the profile configures milestone thresholds, not which grades increment or reset combo.

```rust
pub struct ScoringProfile {
    pub id: String,
    pub schema_version: String,
    pub timing_windows_ms: TimingWindows,
    pub grading: GradeWeights,
    pub combo: ComboConfig,
    pub rules: ScoringRules,
}

pub struct TimingWindows {
    pub perfect_ms: f32,    // Hits within this window → Grade::Perfect
    pub good_ms: f32,       // Hits within this window → Grade::Good
    pub outer_ms: f32,      // Hits within this window → Grade::Early or Grade::Late (by delta sign)
                            // Hits beyond outer_ms → Grade::Miss
}

pub struct GradeWeights {
    pub perfect: f32,       // Relative weight before score normalization to 0-100
    pub good: f32,
    pub early: f32,
    pub late: f32,
    pub miss: f32,
}

pub struct ComboConfig {
    pub encouragement_milestones: Vec<u32>,  // Starter default: [8, 16, 32]
}

pub struct ScoringRules {}
```

`ScoringRules` is intentionally an empty object in schema version `1.0`. It keeps the rules boundary explicit for future additive fields without forcing P1-01 to guess behavior that is not yet specified elsewhere.

---

## 5. Pack

```rust
pub struct Pack {
    pub id: String,
    pub schema_version: String,
    pub revision: String,
    pub title: String,
    pub description: Option<String>,
    pub instrument_families: Vec<String>,

    pub contents: PackContents,
    pub integrity: Option<IntegrityInfo>,

    // Optional marketplace fields
    pub publisher: Option<PublisherRef>,
    pub license: Option<LicenseInfo>,
    pub rights_declaration: Option<RightsDeclaration>,
}

pub struct PackContents {
    pub lessons: Vec<String>,           // relative paths
    pub courses: Vec<String>,
    pub layouts: Vec<String>,
    pub scoring_profiles: Vec<String>,
    pub assets: Vec<String>,
}
```

---

## 6. Schema Versioning and Compatibility

- `schema_version` field on every top-level entity
- Major version changes = breaking changes (require migration)
- Minor version changes = additive (new optional fields)
- Rust deserialization handles version-specific logic
- Pack validation enforces consistent schema versions across contents

**Compatibility policy:**
- **Backward compatibility:** Taal will load content from any minor version within the same major version. New optional fields default to sensible values when missing.
- **Forward compatibility:** Not supported. Content created with a newer schema version than the app supports will be rejected with a clear "please update Taal" message.
- **Migration ownership:** The Rust content module owns migration logic. On load, it detects schema version and applies transformations as needed.
- **Mixed versions in packs:** All content within a single pack must share the same major schema version. Minor version differences are allowed. Pack validation enforces this.

---

## 7. Content Invariants

These rules are enforced by validation. They apply to both workspace content and exported content, with different strictness levels.

### Lesson Invariants

| Rule | Workspace (Studio) | Export (Pack Builder) |
|------|--------------------|-----------------------|
| `id` is a valid UUID | Required | Required |
| `lane_id` unique within layout reference | Required | Required |
| `event_id` unique within lesson | Warning if violated | Required |
| `section_id` unique within lesson | Required | Required |
| Section ranges do not overlap | Warning | Required |
| Section end > section start | Required | Required |
| Section boundaries are exclusive end (start ≤ t < end) | Required | Required |
| Events within a lane are sorted by musical position | Not required (editor may have unsorted state) | **Required** — export normalizes |
| All lane_ids in events exist in referenced layout | Warning | Required |
| `ticks_per_beat` is fixed per lesson (not per-section) | Required | Required |
| Tempo map positions are monotonically increasing | Required | Required |
| At least one lane with at least one event | Not required (draft may be empty) | Required |
| `scoring_profile_id` references an available profile | Warning | Required |
| `instrument.layout_id` references an available layout | Warning | Required |

### Course Invariants

| Rule | Workspace | Export |
|------|-----------|-------|
| All `lesson_id` references exist | Warning | Required |
| `node_id` unique within course | Required | Required |
| Edge `from`/`to` reference existing node_ids | Required | Required |
| No orphan nodes (every node reachable from entry) | Warning | Required |
| No cycles in edge graph | Required | Required |
| Gate `min_score` in range 0-100 | Required | Required |
| At least one node | Not required | Required |

### Instrument Layout Invariants

| Rule | Enforcement |
|------|-------------|
| `lane_id` unique within layout | Required |
| Every lane appears exactly once in `visual.lane_slots` | Required |
| Every `visual.lane_slots[*].lane_id` references a defined lane | Required |
| `slot_id` unique within layout | Required |
| `ArticulationDef.id` unique within a lane | Required |

### Scoring Profile Invariants

| Rule | Enforcement |
|------|-------------|
| `0 < perfect_ms <= good_ms <= outer_ms` | Required |
| `encouragement_milestones` contains strictly increasing positive integers | Required |
| `rules` serializes as an object (empty `{}` in schema version `1.0`) | Required |

### Pack Invariants

| Rule | Enforcement |
|------|-------------|
| All file paths in `contents` exist in the archive | Required |
| No duplicate file paths | Required |
| All lesson layout references resolvable within pack | Required |
| All lesson scoring profile references resolvable within pack | Required |
| All course lesson references resolvable within pack | Required |
| Instrument family consistent across all content | Required |
| All content same major schema version | Required |
| Integrity hash matches computed hash | Required (on import verification) |

---

### Layout Compatibility Rules

When a lesson is loaded for playback, the runtime checks which lanes the lesson uses against the player's active device profile. This is a **runtime computation**, not a stored field in the lesson schema.

**Terminology:**
- `lesson_lanes`: set of lane_ids that have at least one event in the compiled lesson (derived from events, not stored separately)
- `optional_lanes`: set of lane_ids the creator marked as optional in lesson metadata (default: empty — all lanes required)
- `required_lanes`: `lesson_lanes - optional_lanes`
- `mapped_lanes`: set of lane_ids the player's device profile can produce hits for
- `missing_required`: `required_lanes - mapped_lanes`
- `missing_optional`: `optional_lanes - mapped_lanes`

**Lesson field used by layout compatibility:**
```rust
pub struct Lesson {
    // ... existing fields ...
    pub optional_lanes: Vec<String>,  // Lane IDs that are nice-to-have, not essential
                                       // Default: empty (all lanes required)
}
```

Creators set this in the Lesson Editor (e.g., marking cowbell or splash as optional for a primarily kick/snare/hi-hat groove).

**Runtime behavior by mode:**

| Condition | Practice Mode | Play Mode | Course Gate Mode |
|-----------|--------------|-----------|-----------------|
| No missing lanes | Normal | Normal | Normal |
| Only optional lanes missing | Allowed — missing events shown but not scored | Allowed — missing events excluded, result marked "full compatibility" | Allowed — missing events excluded |
| Any required lanes missing | Allowed with warning | Allowed — result marked "partial compatibility: N lanes unavailable" | **Blocked** — required lanes missing |

**UI indicators:**
- Green: all lanes present
- Yellow: optional lanes missing (fully playable, some color/texture lanes excluded)
- Red: required lanes missing (Practice allowed with warning; Play marked partial; Gate blocked)

**Scoring rule:** Events on missing lanes are excluded entirely — they do not count as hits or misses. The score denominator is reduced accordingly. The review screen explicitly states: "Scoring adjusted: 2 lanes unavailable on current kit" and lists which lanes were excluded.

**Why required/optional rather than coverage percentage:** A raw percentage can be misleading. A lesson with 90% kick/snare/hi-hat and 10% china might pass a coverage threshold, but the china part could be musically central in one section. Creator-intentional tagging is more reliable than algorithmic thresholds.

---

## 8. Authoring vs Compiled/Runtime Representation

Content exists in two forms. This distinction is critical for both Studio and Player.

### Authoring Form (Studio Workspace)

- Editable, forgiving, UI-oriented
- Events may be unsorted
- References may be temporarily dangling (lesson references a layout being created)
- Sections may be incomplete
- Metadata may be partial
- Saved continuously (autosave)
- Stored in SQLite workspace tables

### Compiled Form (Player Runtime)

- Normalized, execution-ready, strict
- Events sorted by absolute time (ms)
- All references resolved
- All sections have valid ms ranges
- TimingIndex built (pos ↔ ms bidirectional lookup)
- Lane index built (fast lookup by lane_id)
- Immutable during session

**Compilation:** The Rust `compile_lesson()` function transforms authoring form → compiled form. This happens:
- When a lesson is loaded for practice (Player)
- When preview is triggered (Studio)
- Compilation validates all invariants and fails with clear errors if any are violated

### Exported Form (Pack)

- Serialized JSON, strict
- Events normalized (sorted by position)
- All references valid
- Schema-compliant
- This is what gets imported by other users

---

## 9. Pack Directory Structure

A `.taalpack` file is a ZIP archive with a deterministic internal structure:

```
my-pack.taalpack (ZIP)
├── pack.json                    # Pack manifest (PackContents + metadata)
├── lessons/
│   ├── basic-rock-beat-1.json   # Each lesson as standalone JSON
│   └── basic-rock-beat-2.json
├── courses/
│   └── beginner-rock.json       # Course referencing lesson filenames
├── layouts/
│   └── std-5pc-v1.json          # Instrument layout
├── scoring/
│   └── score-standard-v1.json   # Scoring profile
└── assets/
    └── artwork/
        └── cover.png            # Optional pack artwork
```

**Rules:**
- All paths in `pack.json` are relative to the archive root
- Filenames are lowercase, hyphenated, no spaces
- Lessons/courses reference each other by `id` (UUID), not by filename
- `pack.json` is always at the root
- Directory structure is deterministic: files sorted alphabetically within each directory
- Content hash (SHA-256) computed over sorted file list with their individual hashes
- No audio files in v1 packs (beatmaps reference user-provided audio by display name only)

---

## 10. Examples

### Minimal Drum Lesson

This example omits JSON-optional/defaulted ancillary fields such as `optional_lanes`, `assets`, `references`, `publisher`, and `extensions`.

```json
{
  "schema_version": "1.0",
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "revision": "1.0.0",
  "title": "Basic Rock Beat",
  "instrument": {
    "family": "drums",
    "variant": "kit",
    "layout_id": "std-5pc-v1"
  },
  "timing": {
    "time_signature": { "num": 4, "den": 4 },
    "ticks_per_beat": 480,
    "tempo_map": [
      { "pos": { "bar": 1, "beat": 1, "tick": 0 }, "bpm": 120.0 }
    ]
  },
  "lanes": [
    {
      "lane_id": "kick",
      "events": [
        { "event_id": "e1", "pos": { "bar": 1, "beat": 1, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 90, "articulation": "normal" } },
        { "event_id": "e2", "pos": { "bar": 1, "beat": 3, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 90, "articulation": "normal" } }
      ]
    },
    {
      "lane_id": "snare",
      "events": [
        { "event_id": "e3", "pos": { "bar": 1, "beat": 2, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 95, "articulation": "normal" } },
        { "event_id": "e4", "pos": { "bar": 1, "beat": 4, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 95, "articulation": "normal" } }
      ]
    },
    {
      "lane_id": "hihat",
      "events": [
        { "event_id": "e5", "pos": { "bar": 1, "beat": 1, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 80, "articulation": "closed" } },
        { "event_id": "e6", "pos": { "bar": 1, "beat": 1, "tick": 240 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 70, "articulation": "closed" } },
        { "event_id": "e7", "pos": { "bar": 1, "beat": 2, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 80, "articulation": "closed" } },
        { "event_id": "e8", "pos": { "bar": 1, "beat": 2, "tick": 240 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 70, "articulation": "closed" } }
      ]
    }
  ],
  "sections": [
    {
      "section_id": "main",
      "label": "Main Groove",
      "range": {
        "start": { "bar": 1, "beat": 1, "tick": 0 },
        "end": { "bar": 2, "beat": 1, "tick": 0 }
      },
      "loopable": true
    }
  ],
  "practice": {
    "modes_supported": ["practice", "play"],
    "count_in_bars": 1,
    "metronome_enabled": true,
    "start_tempo_bpm": 120.0,
    "tempo_floor_bpm": 60.0
  },
  "metadata": {
    "difficulty": "beginner",
    "tags": ["rock", "backbeat"],
    "skills": ["timing.backbeat", "subdivision.8ths"],
    "objectives": ["Play kick on 1&3, snare on 2&4, 8th-note hi-hats"],
    "prerequisites": [],
    "estimated_minutes": 3
  }
}
```

### Minimal Course

```json
{
  "schema_version": "1.0",
  "id": "550e8400-e29b-41d4-a716-446655440010",
  "revision": "1.0.0",
  "title": "Beginner Rock Drumming",
  "instrument_family": "drums",
  "nodes": [
    { "node_id": "n1", "node_type": "lesson", "lesson_id": "550e8400-e29b-41d4-a716-446655440001", "label": "Basic Rock Beat" },
    { "node_id": "n2", "node_type": "lesson", "lesson_id": "550e8400-e29b-41d4-a716-446655440002", "label": "Rock Beat with Fills" }
  ],
  "edges": [
    { "from": "n1", "to": "n2", "condition": { "type": "min_score", "min_score": 80 } }
  ],
  "progression": {
    "mode": "gated",
    "default_gate": { "min_score": 80, "max_retries": null, "allow_practice_before_retry": true }
  },
  "metadata": {
    "difficulty": "beginner",
    "tags": ["rock", "foundations"],
    "skills": ["timing.backbeat", "fills.basic"]
  }
}
```

### Standard 5-Piece Layout

```json
{
  "schema_version": "1.0",
  "id": "std-5pc-v1",
  "family": "drums",
  "variant": "kit",
  "visual": {
    "lane_slots": [
      { "lane_id": "kick", "slot_id": "kick" },
      { "lane_id": "snare", "slot_id": "snare" },
      { "lane_id": "hihat", "slot_id": "hihat" },
      { "lane_id": "ride", "slot_id": "ride" },
      { "lane_id": "crash", "slot_id": "crash" },
      { "lane_id": "tom_high", "slot_id": "tom_high" },
      { "lane_id": "tom_low", "slot_id": "tom_low" },
      { "lane_id": "tom_floor", "slot_id": "tom_floor" }
    ]
  },
  "lanes": [
    { "lane_id": "kick", "label": "Kick", "midi_hints": [{ "hint_type": "note", "values": [36] }] },
    { "lane_id": "snare", "label": "Snare", "midi_hints": [{ "hint_type": "note", "values": [38, 40] }] },
    { "lane_id": "hihat", "label": "Hi-Hat",
      "midi_hints": [{ "hint_type": "note", "values": [42, 44, 46] }, { "hint_type": "cc", "values": [4] }],
      "articulations": [
        { "id": "closed", "label": "Closed", "midi_note": 42 },
        { "id": "open", "label": "Open", "midi_note": 46 },
        { "id": "pedal", "label": "Pedal", "midi_note": 44 }
      ]
    },
    { "lane_id": "ride", "label": "Ride", "midi_hints": [{ "hint_type": "note", "values": [51, 59] }] },
    { "lane_id": "crash", "label": "Crash", "midi_hints": [{ "hint_type": "note", "values": [49, 57] }] },
    { "lane_id": "tom_high", "label": "High Tom", "midi_hints": [{ "hint_type": "note", "values": [48, 50] }] },
    { "lane_id": "tom_low", "label": "Low Tom", "midi_hints": [{ "hint_type": "note", "values": [45, 47] }] },
    { "lane_id": "tom_floor", "label": "Floor Tom", "midi_hints": [{ "hint_type": "note", "values": [43, 41] }] }
  ]
}
```
