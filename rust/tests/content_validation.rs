use serde_json::{json, Value};
use taal_core::content::{
    load_layout, load_lesson, load_scoring_profile, AssetRefs, ContentError, ContentRefs,
};

const VALID_LESSON: &str = r#"
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
"#;

const VALID_LAYOUT: &str = r#"
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
"#;

const VALID_SCORING_PROFILE: &str = r#"
{
  "id": "score-standard-v1",
  "schema_version": "1.0",
  "timing_windows_ms": {
    "perfect_ms": 20.0,
    "good_ms": 45.0,
    "outer_ms": 120.0
  },
  "grading": {
    "perfect": 1.0,
    "good": 0.75,
    "early": 0.5,
    "late": 0.5,
    "miss": 0.0
  },
  "combo": {
    "encouragement_milestones": [8, 16, 32]
  },
  "rules": {}
}
"#;

#[test]
fn valid_minimal_lesson_loads_and_materializes_defaults() {
    let lesson = load_lesson(VALID_LESSON).expect("valid lesson should load");

    assert_eq!(lesson.title, "Basic Rock Beat");
    assert!(lesson.optional_lanes.is_empty());
    assert_eq!(lesson.assets, AssetRefs::default());
    assert_eq!(lesson.references, ContentRefs::default());
}

#[test]
fn invalid_lesson_missing_required_field_returns_schema_error() {
    let mut value = lesson_value();
    value.as_object_mut().unwrap().remove("title");

    assert_schema_error(load_lesson(&value.to_string()).unwrap_err());
}

#[test]
fn invalid_lesson_duplicate_lane_ids_returns_clear_error() {
    let mut value = lesson_value();
    value["lanes"][1]["lane_id"] = json!("kick");

    assert_invariant_error(
        load_lesson(&value.to_string()).unwrap_err(),
        "lesson.lane_id_unique",
    );
}

#[test]
fn invalid_lesson_overlapping_sections_returns_clear_error() {
    let mut value = lesson_value();
    let section = json!({
      "section_id": "overlap",
      "label": "Overlap",
      "range": {
        "start": { "bar": 1, "beat": 3, "tick": 0 },
        "end": { "bar": 2, "beat": 1, "tick": 0 }
      },
      "loopable": true
    });
    value["sections"].as_array_mut().unwrap().push(section);

    assert_invariant_error(
        load_lesson(&value.to_string()).unwrap_err(),
        "lesson.sections_non_overlapping",
    );
}

#[test]
fn invalid_lesson_unsorted_events_returns_clear_error() {
    let mut value = lesson_value();
    value["lanes"][2]["events"][0]["pos"]["tick"] = json!(300);

    assert_invariant_error(
        load_lesson(&value.to_string()).unwrap_err(),
        "lesson.events_sorted_by_position",
    );
}

#[test]
fn valid_layout_loads() {
    let layout = load_layout(VALID_LAYOUT).expect("valid layout should load");

    assert_eq!(layout.id, "std-5pc-v1");
    assert_eq!(layout.visual.lane_slots.len(), layout.lanes.len());
}

#[test]
fn invalid_layout_missing_visual_returns_schema_error() {
    let mut value = layout_value();
    value.as_object_mut().unwrap().remove("visual");

    assert_schema_error(load_layout(&value.to_string()).unwrap_err());
}

#[test]
fn invalid_layout_duplicate_lane_ids_returns_clear_error() {
    let mut value = layout_value();
    value["lanes"][1]["lane_id"] = json!("kick");

    assert_invariant_error(
        load_layout(&value.to_string()).unwrap_err(),
        "layout.lane_id_unique",
    );
}

#[test]
fn valid_scoring_profile_loads() {
    let scoring =
        load_scoring_profile(VALID_SCORING_PROFILE).expect("valid scoring profile should load");

    assert_eq!(scoring.id, "score-standard-v1");
    assert_eq!(scoring.combo.encouragement_milestones, vec![8, 16, 32]);
}

#[test]
fn invalid_scoring_windows_return_clear_error() {
    let mut value = scoring_value();
    value["timing_windows_ms"]["good_ms"] = json!(10.0);

    assert_invariant_error(
        load_scoring_profile(&value.to_string()).unwrap_err(),
        "scoring.timing_windows_order",
    );
}

#[test]
fn invalid_scoring_milestones_return_clear_error() {
    let mut value = scoring_value();
    value["combo"]["encouragement_milestones"] = json!([8, 8]);

    assert_invariant_error(
        load_scoring_profile(&value.to_string()).unwrap_err(),
        "scoring.combo_milestones_strictly_increasing",
    );
}

fn lesson_value() -> Value {
    serde_json::from_str(VALID_LESSON).unwrap()
}

fn layout_value() -> Value {
    serde_json::from_str(VALID_LAYOUT).unwrap()
}

fn scoring_value() -> Value {
    serde_json::from_str(VALID_SCORING_PROFILE).unwrap()
}

fn assert_schema_error(error: ContentError) {
    assert!(
        matches!(error, ContentError::SchemaViolation { .. }),
        "expected schema error, got {error:?}"
    );
}

fn assert_invariant_error(error: ContentError, expected_rule: &str) {
    match error {
        ContentError::InvariantViolation { rule, .. } => assert_eq!(rule, expected_rule),
        other => panic!("expected invariant error '{expected_rule}', got {other:?}"),
    }
}
