use serde_json::Value;
use taal_core::api::practice_runtime::{
    practice_runtime_dispose, practice_runtime_stop, practice_runtime_submit_midi_note_on,
    practice_runtime_submit_touch_hit, start_practice_runtime_session, PracticeRuntimeModeDto,
    PracticeRuntimeStartRequest,
};

const START_NS: i64 = 10_000_000_000;

const LESSON_JSON: &str = r#"
{
  "schema_version": "1.0",
  "id": "550e8400-e29b-41d4-a716-446655440231",
  "revision": "1.0.0",
  "title": "Runtime Tap Fixture",
  "instrument": {
    "family": "drums",
    "variant": "kit",
    "layout_id": "std-runtime-v1"
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
        { "event_id": "kick-1", "pos": { "bar": 1, "beat": 1, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 90, "articulation": "normal" } }
      ]
    },
    {
      "lane_id": "snare",
      "events": [
        { "event_id": "snare-1", "pos": { "bar": 1, "beat": 2, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 95, "articulation": "normal" } }
      ]
    }
  ],
  "sections": [
    {
      "section_id": "main",
      "label": "Main",
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
    "tags": [],
    "skills": [],
    "objectives": [],
    "prerequisites": [],
    "estimated_minutes": 1
  },
  "scoring_profile_id": "score-runtime-v1"
}
"#;

const LAYOUT_JSON: &str = r#"
{
  "schema_version": "1.0",
  "id": "std-runtime-v1",
  "family": "drums",
  "variant": "kit",
  "visual": {
    "lane_slots": [
      { "lane_id": "kick", "slot_id": "kick" },
      { "lane_id": "snare", "slot_id": "snare" }
    ]
  },
  "lanes": [
    { "lane_id": "kick", "label": "Kick", "midi_hints": [{ "hint_type": "note", "values": [36] }] },
    { "lane_id": "snare", "label": "Snare", "midi_hints": [{ "hint_type": "note", "values": [38] }] }
  ]
}
"#;

const SCORING_JSON: &str = r#"
{
  "id": "score-runtime-v1",
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
    "encouragement_milestones": [2]
  },
  "rules": {}
}
"#;

const DEVICE_PROFILE_JSON: &str = r#"
{
  "id": "550e8400-e29b-41d4-a716-446655440232",
  "name": "Runtime Test Kit",
  "instrument_family": "drums",
  "layout_id": "std-runtime-v1",
  "device_fingerprint": {
    "vendor_name": "Test",
    "model_name": "Runtime",
    "platform_id": "test:runtime"
  },
  "transport": "usb",
  "midi_channel": 9,
  "note_map": [
    {
      "midi_note": 38,
      "lane_id": "snare",
      "articulation": "normal",
      "min_velocity": 1,
      "max_velocity": 127
    }
  ],
  "hihat_model": null,
  "input_offset_ms": 0.0,
  "dedupe_window_ms": 8.0,
  "velocity_curve": "linear",
  "preset_origin": "test",
  "created_at": "2026-04-17T10:00:00Z",
  "updated_at": "2026-04-17T10:00:00Z"
}
"#;

#[test]
fn touch_only_hits_score_through_the_rust_session() {
    let session_id = start(None);

    let kick =
        practice_runtime_submit_touch_hit(session_id, "kick".to_owned(), 96, timestamp_ms(5));
    let kick_events = events(&kick.events_json);
    assert_eq!(kick_events[0]["type"], "hit_graded");
    assert_eq!(kick_events[0]["lane_id"], "kick");
    assert_eq!(kick_events[0]["grade"], "perfect");
    assert_eq!(kick_events[0]["combo"], 1);

    let snare =
        practice_runtime_submit_touch_hit(session_id, "snare".to_owned(), 96, timestamp_ms(505));
    let snare_events = events(&snare.events_json);
    assert_eq!(snare_events[0]["type"], "hit_graded");
    assert_eq!(snare_events[0]["lane_id"], "snare");
    assert_eq!(snare_events[0]["combo"], 2);
    assert_eq!(snare_events[1]["type"], "combo_milestone");
    assert_eq!(snare_events[2]["type"], "encouragement");

    let stopped = practice_runtime_stop(session_id);
    assert!(stopped.error.is_none(), "{:?}", stopped.error);
    let summary: Value = serde_json::from_str(stopped.summary_json.as_ref().unwrap()).unwrap();
    assert_eq!(summary["mode"], "practice");
    assert_eq!(summary["score_total"], 100.0);
    assert_eq!(summary["hit_rate_pct"], 100.0);

    dispose(session_id);
}

#[test]
fn midi_and_touch_hits_converge_on_the_same_session_event_stream() {
    let session_id = start(Some(DEVICE_PROFILE_JSON));

    let touch =
        practice_runtime_submit_touch_hit(session_id, "kick".to_owned(), 96, timestamp_ms(5));
    assert_eq!(events(&touch.events_json)[0]["lane_id"], "kick");

    let midi = practice_runtime_submit_midi_note_on(session_id, 9, 38, 100, timestamp_ms(505));
    let midi_events = events(&midi.events_json);
    assert_eq!(midi_events[0]["type"], "hit_graded");
    assert_eq!(midi_events[0]["lane_id"], "snare");
    assert_eq!(midi_events[0]["grade"], "perfect");
    assert_eq!(midi_events[0]["combo"], 2);
    assert_eq!(midi_events[1]["type"], "combo_milestone");

    let stopped = practice_runtime_stop(session_id);
    assert!(stopped.error.is_none(), "{:?}", stopped.error);
    let summary: Value = serde_json::from_str(stopped.summary_json.as_ref().unwrap()).unwrap();
    assert_eq!(summary["score_total"], 100.0);
    assert_eq!(summary["lane_stats"]["kick"]["hit_rate_pct"], 100.0);
    assert_eq!(summary["lane_stats"]["snare"]["hit_rate_pct"], 100.0);

    dispose(session_id);
}

#[test]
fn start_returns_timeline_data_for_practice_mode_renderers() {
    let result = start_practice_runtime_session(PracticeRuntimeStartRequest {
        lesson_json: LESSON_JSON.to_owned(),
        layout_json: LAYOUT_JSON.to_owned(),
        scoring_profile_json: SCORING_JSON.to_owned(),
        device_profile_json: None,
        mode: PracticeRuntimeModeDto::Practice,
        bpm: 120.0,
        start_time_ns: START_NS,
        lookahead_ms: 250,
    });
    assert!(result.error.is_none(), "{:?}", result.error);
    let timeline: Value = serde_json::from_str(result.timeline_json.as_ref().unwrap()).unwrap();

    assert_eq!(
        timeline["lesson_id"],
        "550e8400-e29b-41d4-a716-446655440231"
    );
    assert_eq!(timeline["total_duration_ms"], 2000);
    assert_eq!(timeline["lanes"][0]["lane_id"], "kick");
    assert_eq!(timeline["notes"][1]["expected_id"], "snare-1");
    assert_eq!(timeline["sections"][0]["label"], "Main");

    dispose(result.session_id.unwrap());
}

fn start(device_profile_json: Option<&str>) -> u32 {
    let result = start_practice_runtime_session(PracticeRuntimeStartRequest {
        lesson_json: LESSON_JSON.to_owned(),
        layout_json: LAYOUT_JSON.to_owned(),
        scoring_profile_json: SCORING_JSON.to_owned(),
        device_profile_json: device_profile_json.map(str::to_owned),
        mode: PracticeRuntimeModeDto::Practice,
        bpm: 120.0,
        start_time_ns: START_NS,
        lookahead_ms: 250,
    });
    assert!(result.error.is_none(), "{:?}", result.error);
    result.session_id.unwrap()
}

fn events(events_json: &Option<String>) -> Vec<Value> {
    serde_json::from_str(events_json.as_ref().unwrap()).unwrap()
}

fn timestamp_ms(ms: i64) -> i64 {
    START_NS + ms * 1_000_000
}

fn dispose(session_id: u32) {
    let result = practice_runtime_dispose(session_id);
    assert!(result.error.is_none(), "{:?}", result.error);
}
