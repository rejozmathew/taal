use taal_core::content::{
    compile_lesson, compiled_lesson_for_scoring, evaluate_layout_compatibility, load_layout,
    load_lesson, load_scoring_profile, LayoutCompatibilityStatus,
};

#[test]
fn optional_missing_lane_is_yellow_and_excluded_from_scoring() {
    let (lesson, compiled) = compile_fixture(LESSON_WITH_OPTIONAL_COWBELL);

    let compatibility = evaluate_layout_compatibility(
        &compiled,
        &lesson.optional_lanes,
        &["kick".to_owned(), "snare".to_owned()],
    );

    assert_eq!(
        compatibility.status,
        LayoutCompatibilityStatus::OptionalMissing
    );
    assert_eq!(compatibility.missing_required_lanes, Vec::<String>::new());
    assert_eq!(compatibility.missing_optional_lanes, vec!["cowbell"]);
    assert_eq!(compatibility.excluded_lanes, vec!["cowbell"]);

    let scoring_compiled = compiled_lesson_for_scoring(&compiled, &compatibility);
    assert_eq!(compiled.events.len(), 3);
    assert_eq!(scoring_compiled.events.len(), 2);
    assert!(compiled
        .events
        .iter()
        .any(|event| event.lane_id == "cowbell"));
    assert!(!scoring_compiled
        .events
        .iter()
        .any(|event| event.lane_id == "cowbell"));
}

#[test]
fn required_missing_lane_is_red_and_partial_play_eligible() {
    let (lesson, compiled) = compile_fixture(LESSON_ALL_REQUIRED);

    let compatibility =
        evaluate_layout_compatibility(&compiled, &lesson.optional_lanes, &["kick".to_owned()]);

    assert_eq!(
        compatibility.status,
        LayoutCompatibilityStatus::RequiredMissing
    );
    assert_eq!(compatibility.missing_required_lanes, vec!["snare"]);
    assert_eq!(compatibility.missing_optional_lanes, Vec::<String>::new());
    assert_eq!(compatibility.excluded_lanes, vec!["snare"]);
}

#[test]
fn all_lanes_present_is_green_and_leaves_scoring_unchanged() {
    let (lesson, compiled) = compile_fixture(LESSON_WITH_OPTIONAL_COWBELL);

    let compatibility = evaluate_layout_compatibility(
        &compiled,
        &lesson.optional_lanes,
        &["kick".to_owned(), "snare".to_owned(), "cowbell".to_owned()],
    );

    assert_eq!(compatibility.status, LayoutCompatibilityStatus::Full);
    assert!(compatibility.excluded_lanes.is_empty());
    assert_eq!(
        compiled_lesson_for_scoring(&compiled, &compatibility).events,
        compiled.events
    );
}

fn compile_fixture(
    lesson_json: &str,
) -> (
    taal_core::content::Lesson,
    taal_core::content::CompiledLesson,
) {
    let lesson = load_lesson(lesson_json).unwrap();
    let layout = load_layout(LAYOUT_JSON).unwrap();
    let scoring = load_scoring_profile(SCORING_JSON).unwrap();
    let compiled = compile_lesson(&lesson, &layout, &scoring).unwrap();
    (lesson, compiled)
}

const LESSON_WITH_OPTIONAL_COWBELL: &str = r#"
{
  "schema_version": "1.0",
  "id": "550e8400-e29b-41d4-a716-44665544c001",
  "revision": "1.0.0",
  "title": "Cowbell Option",
  "instrument": { "family": "drums", "variant": "kit", "layout_id": "compat-kit-v1" },
  "timing": {
    "time_signature": { "num": 4, "den": 4 },
    "ticks_per_beat": 480,
    "tempo_map": [{ "pos": { "bar": 1, "beat": 1, "tick": 0 }, "bpm": 120.0 }]
  },
  "lanes": [
    { "lane_id": "kick", "events": [
      { "event_id": "kick-1", "pos": { "bar": 1, "beat": 1, "tick": 0 }, "duration_ticks": 0,
        "payload": { "type": "hit", "velocity": 96, "articulation": "normal" } }
    ] },
    { "lane_id": "snare", "events": [
      { "event_id": "snare-1", "pos": { "bar": 1, "beat": 2, "tick": 0 }, "duration_ticks": 0,
        "payload": { "type": "hit", "velocity": 96, "articulation": "normal" } }
    ] },
    { "lane_id": "cowbell", "events": [
      { "event_id": "cowbell-1", "pos": { "bar": 1, "beat": 3, "tick": 0 }, "duration_ticks": 0,
        "payload": { "type": "hit", "velocity": 80, "articulation": "normal" } }
    ] }
  ],
  "sections": [{
    "section_id": "main",
    "label": "Main",
    "range": {
      "start": { "bar": 1, "beat": 1, "tick": 0 },
      "end": { "bar": 2, "beat": 1, "tick": 0 }
    },
    "loopable": true
  }],
  "practice": { "modes_supported": ["practice", "play"], "count_in_bars": 1, "metronome_enabled": true, "start_tempo_bpm": 120.0, "tempo_floor_bpm": 60.0 },
  "metadata": { "difficulty": "beginner", "tags": [], "skills": [], "objectives": [], "prerequisites": [], "estimated_minutes": 1 },
  "optional_lanes": ["cowbell"],
  "scoring_profile_id": "compat-score-v1"
}
"#;

const LESSON_ALL_REQUIRED: &str = r#"
{
  "schema_version": "1.0",
  "id": "550e8400-e29b-41d4-a716-44665544c002",
  "revision": "1.0.0",
  "title": "Required Snare",
  "instrument": { "family": "drums", "variant": "kit", "layout_id": "compat-kit-v1" },
  "timing": {
    "time_signature": { "num": 4, "den": 4 },
    "ticks_per_beat": 480,
    "tempo_map": [{ "pos": { "bar": 1, "beat": 1, "tick": 0 }, "bpm": 120.0 }]
  },
  "lanes": [
    { "lane_id": "kick", "events": [
      { "event_id": "kick-1", "pos": { "bar": 1, "beat": 1, "tick": 0 }, "duration_ticks": 0,
        "payload": { "type": "hit", "velocity": 96, "articulation": "normal" } }
    ] },
    { "lane_id": "snare", "events": [
      { "event_id": "snare-1", "pos": { "bar": 1, "beat": 2, "tick": 0 }, "duration_ticks": 0,
        "payload": { "type": "hit", "velocity": 96, "articulation": "normal" } }
    ] }
  ],
  "sections": [{
    "section_id": "main",
    "label": "Main",
    "range": {
      "start": { "bar": 1, "beat": 1, "tick": 0 },
      "end": { "bar": 2, "beat": 1, "tick": 0 }
    },
    "loopable": true
  }],
  "practice": { "modes_supported": ["practice", "play"], "count_in_bars": 1, "metronome_enabled": true, "start_tempo_bpm": 120.0, "tempo_floor_bpm": 60.0 },
  "metadata": { "difficulty": "beginner", "tags": [], "skills": [], "objectives": [], "prerequisites": [], "estimated_minutes": 1 },
  "scoring_profile_id": "compat-score-v1"
}
"#;

const LAYOUT_JSON: &str = r#"
{
  "schema_version": "1.0",
  "id": "compat-kit-v1",
  "family": "drums",
  "variant": "kit",
  "visual": {
    "lane_slots": [
      { "lane_id": "kick", "slot_id": "kick" },
      { "lane_id": "snare", "slot_id": "snare" },
      { "lane_id": "cowbell", "slot_id": "cowbell" }
    ]
  },
  "lanes": [
    { "lane_id": "kick", "label": "Kick", "midi_hints": [{ "hint_type": "note", "values": [36] }] },
    { "lane_id": "snare", "label": "Snare", "midi_hints": [{ "hint_type": "note", "values": [38] }] },
    { "lane_id": "cowbell", "label": "Cowbell", "midi_hints": [{ "hint_type": "note", "values": [56] }] }
  ]
}
"#;

const SCORING_JSON: &str = r#"
{
  "id": "compat-score-v1",
  "schema_version": "1.0",
  "timing_windows_ms": { "perfect_ms": 20.0, "good_ms": 45.0, "outer_ms": 120.0 },
  "grading": { "perfect": 1.0, "good": 0.75, "early": 0.5, "late": 0.5, "miss": 0.0 },
  "combo": { "encouragement_milestones": [8] },
  "rules": {}
}
"#;
