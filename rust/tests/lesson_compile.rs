use taal_core::content::{
    compile_lesson, load_layout, load_lesson, load_scoring_profile, CompileError,
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
        { "event_id": "kick-1", "pos": { "bar": 1, "beat": 3, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 90, "articulation": "normal" } },
        { "event_id": "kick-2", "pos": { "bar": 2, "beat": 1, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 90, "articulation": "normal" } }
      ]
    },
    {
      "lane_id": "snare",
      "events": [
        { "event_id": "snare-1", "pos": { "bar": 1, "beat": 2, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 95, "articulation": "normal" } }
      ]
    },
    {
      "lane_id": "hihat",
      "events": [
        { "event_id": "hihat-1", "pos": { "bar": 1, "beat": 1, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 80, "articulation": "closed" } },
        { "event_id": "hihat-2", "pos": { "bar": 1, "beat": 1, "tick": 240 }, "duration_ticks": 0,
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
  },
  "scoring_profile_id": "score-standard-v1"
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
      { "lane_id": "hihat", "slot_id": "hihat" }
    ]
  },
  "lanes": [
    { "lane_id": "kick", "label": "Kick", "midi_hints": [{ "hint_type": "note", "values": [36] }] },
    { "lane_id": "snare", "label": "Snare", "midi_hints": [{ "hint_type": "note", "values": [38, 40] }] },
    { "lane_id": "hihat", "label": "Hi-Hat", "midi_hints": [{ "hint_type": "note", "values": [42] }] }
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
fn compiled_lesson_events_are_sorted_by_absolute_time() {
    let compiled = compile_fixture();

    let ids = compiled
        .events
        .iter()
        .map(|event| (event.expected_id.as_str(), event.t_ms))
        .collect::<Vec<_>>();

    assert_eq!(
        ids,
        vec![
            ("hihat-1", 0),
            ("hihat-2", 250),
            ("snare-1", 500),
            ("kick-1", 1000),
            ("kick-2", 2000),
        ]
    );
    assert_eq!(
        compiled.lane_ids,
        vec!["kick".to_owned(), "snare".to_owned(), "hihat".to_owned()]
    );
}

#[test]
fn compiled_lesson_converts_section_ranges_to_milliseconds() {
    let compiled = compile_fixture();

    assert_eq!(compiled.sections.len(), 1);
    assert_eq!(compiled.sections[0].section_id, "main");
    assert_eq!(compiled.sections[0].start_ms, 0);
    assert_eq!(compiled.sections[0].end_ms, 2000);
    assert_eq!(compiled.total_duration_ms, 2000);
}

#[test]
fn compiling_same_inputs_is_deterministic() {
    let first = compile_fixture();
    let second = compile_fixture();

    assert_eq!(first, second);
}

#[test]
fn compile_rejects_mismatched_scoring_profile_reference() {
    let lesson = load_lesson(VALID_LESSON).unwrap();
    let layout = load_layout(VALID_LAYOUT).unwrap();
    let mut scoring = load_scoring_profile(VALID_SCORING_PROFILE).unwrap();
    scoring.id = "other-profile".to_owned();

    let error = compile_lesson(&lesson, &layout, &scoring).unwrap_err();

    assert!(matches!(
        error,
        CompileError::MissingScoringProfile { profile_id } if profile_id == "score-standard-v1"
    ));
}

fn compile_fixture() -> taal_core::content::CompiledLesson {
    let lesson = load_lesson(VALID_LESSON).unwrap();
    let layout = load_layout(VALID_LAYOUT).unwrap();
    let scoring = load_scoring_profile(VALID_SCORING_PROFILE).unwrap();

    compile_lesson(&lesson, &layout, &scoring).unwrap()
}
