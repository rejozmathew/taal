use taal_core::content::PracticeMode;
use taal_core::content::{compile_lesson, load_layout, load_lesson, load_scoring_profile};
use taal_core::runtime::session::{
    drain_events, session_on_hit, session_pause, session_resume, session_start, session_stop,
    session_tick, AttemptSummary, EngineEvent, Grade, InputHit, Session, SessionError, SessionOpts,
    SessionState,
};

const START_NS: i128 = 10_000_000_000;

const RUNTIME_LESSON: &str = r#"
{
  "schema_version": "1.0",
  "id": "550e8400-e29b-41d4-a716-446655440021",
  "revision": "1.0.0",
  "title": "Runtime Fixture",
  "instrument": {
    "family": "drums",
    "variant": "kit",
    "layout_id": "std-compact-v1"
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
          "payload": { "type": "hit", "velocity": 90, "articulation": "normal" } },
        { "event_id": "kick-2", "pos": { "bar": 1, "beat": 3, "tick": 0 }, "duration_ticks": 0,
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
  "scoring_profile_id": "score-standard-v1"
}
"#;

const RUNTIME_LAYOUT: &str = r#"
{
  "schema_version": "1.0",
  "id": "std-compact-v1",
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

const RUNTIME_SCORING: &str = r#"
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
    "encouragement_milestones": [2]
  },
  "rules": {}
}
"#;

#[test]
fn hit_near_expected_event_emits_graded_event() {
    let mut session = runtime_session();

    session_on_hit(&mut session, hit("kick", 5)).unwrap();

    let events = drain_events(&mut session, 8);
    assert_eq!(events.len(), 1);
    match &events[0] {
        EngineEvent::HitGraded {
            expected_id,
            lane_id,
            grade,
            delta_ms,
            combo,
            score_running,
            ..
        } => {
            assert_eq!(expected_id, "kick-1");
            assert_eq!(lane_id, "kick");
            assert_eq!(*grade, Grade::Perfect);
            assert_eq!(*delta_ms, 5.0);
            assert_eq!(*combo, 1);
            assert_close(*score_running, 100.0 / 3.0);
        }
        other => panic!("expected HitGraded, got {other:?}"),
    }
}

#[test]
fn tick_after_window_emits_miss_and_resets_next_combo() {
    let mut session = runtime_session();

    session_on_hit(&mut session, hit("kick", 5)).unwrap();
    drain_events(&mut session, 8);
    session_tick(&mut session, timestamp_ms(621)).unwrap();

    assert_eq!(
        drain_events(&mut session, 8),
        vec![EngineEvent::Missed {
            expected_id: "snare-1".to_owned(),
            lane_id: "snare".to_owned(),
        }]
    );

    session_on_hit(&mut session, hit("kick", 1005)).unwrap();

    match &drain_events(&mut session, 8)[0] {
        EngineEvent::HitGraded {
            expected_id, combo, ..
        } => {
            assert_eq!(expected_id, "kick-2");
            assert_eq!(*combo, 1);
        }
        other => panic!("expected HitGraded, got {other:?}"),
    }
}

#[test]
fn stop_returns_attempt_summary_with_score_timing_and_lane_stats() {
    let mut session = runtime_session();

    session_on_hit(&mut session, hit("kick", 5)).unwrap();
    session_tick(&mut session, timestamp_ms(621)).unwrap();
    session_on_hit(&mut session, hit("kick", 1005)).unwrap();

    let summary = session_stop(&mut session).unwrap();

    assert_eq!(
        summary.lesson_id.to_string(),
        "550e8400-e29b-41d4-a716-446655440021"
    );
    assert_close(summary.score_total, 200.0 / 3.0);
    assert_close(summary.accuracy_pct, 200.0 / 3.0);
    assert_close(summary.hit_rate_pct, 200.0 / 3.0);
    assert_close(summary.miss_pct, 100.0 / 3.0);
    assert_eq!(summary.max_streak, 1);
    assert_close(summary.mean_delta_ms, 5.0);
    assert_close(summary.std_delta_ms, 0.0);
    assert_eq!(summary.median_delta_ms, Some(5.0));
    assert_eq!(summary.p90_abs_delta_ms, Some(5.0));

    let kick = summary.lane_stats.get("kick").unwrap();
    assert_close(kick.hit_rate_pct, 100.0);
    assert_close(kick.miss_pct, 0.0);

    let snare = summary.lane_stats.get("snare").unwrap();
    assert_close(snare.hit_rate_pct, 0.0);
    assert_close(snare.miss_pct, 100.0);
}

#[test]
fn state_transitions_are_enforced() {
    let compiled = compiled_fixture();
    let opts = SessionOpts::new(PracticeMode::Practice, 120.0, START_NS);
    let mut session = Session::new(&compiled, opts);

    assert_eq!(session.state(), SessionState::Ready);
    session.start().unwrap();
    assert_eq!(session.state(), SessionState::Running);
    session_pause(&mut session).unwrap();
    assert_eq!(session.state(), SessionState::Paused);
    assert_invalid_state(
        session_on_hit(&mut session, hit("kick", 5)).unwrap_err(),
        SessionState::Paused,
    );
    session_resume(&mut session).unwrap();
    assert_eq!(session.state(), SessionState::Running);

    let first_summary = session_stop(&mut session).unwrap();
    assert_eq!(session.state(), SessionState::Stopped);
    assert_invalid_state(
        session_on_hit(&mut session, hit("kick", 5)).unwrap_err(),
        SessionState::Stopped,
    );
    let second_summary = session_stop(&mut session).unwrap();
    assert_summary_eq(&first_summary, &second_summary);
}

#[test]
fn configured_combo_milestone_emits_engine_events() {
    let mut session = runtime_session();

    session_on_hit(&mut session, hit("kick", 5)).unwrap();
    drain_events(&mut session, 8);
    session_on_hit(&mut session, hit("snare", 505)).unwrap();

    let events = drain_events(&mut session, 8);
    assert_eq!(events.len(), 3);
    assert!(matches!(events[0], EngineEvent::HitGraded { .. }));
    assert_eq!(events[1], EngineEvent::ComboMilestone { combo: 2 });
    assert_eq!(
        events[2],
        EngineEvent::Encouragement {
            message_id: "combo-2".to_owned(),
            text: "Keep it steady".to_owned(),
        }
    );
}

#[test]
fn tick_emits_expected_pulse_for_lookahead_window() {
    let compiled = compiled_fixture();
    let mut opts = SessionOpts::new(PracticeMode::Practice, 120.0, START_NS);
    opts.lookahead_ms = 250;
    let mut session = session_start(&compiled, opts);

    session_tick(&mut session, START_NS).unwrap();

    assert_eq!(
        drain_events(&mut session, 8),
        vec![
            EngineEvent::ExpectedPulse {
                expected_id: "kick-1".to_owned(),
                lane_id: "kick".to_owned(),
                t_expected_ms: 0,
            },
            EngineEvent::MetronomeClick {
                t_ms: 0,
                accent: true,
            },
        ]
    );
}

#[test]
fn tick_emits_metronome_clicks_for_lookahead_window() {
    let compiled = compiled_fixture();
    let mut opts = SessionOpts::new(PracticeMode::Practice, 120.0, START_NS);
    opts.lookahead_ms = 1100;
    let mut session = session_start(&compiled, opts);

    session_tick(&mut session, START_NS).unwrap();

    let events = drain_events(&mut session, 16);
    let clicks = events
        .into_iter()
        .filter(|event| matches!(event, EngineEvent::MetronomeClick { .. }))
        .collect::<Vec<_>>();

    assert_eq!(
        clicks,
        vec![
            EngineEvent::MetronomeClick {
                t_ms: 0,
                accent: true,
            },
            EngineEvent::MetronomeClick {
                t_ms: 500,
                accent: false,
            },
            EngineEvent::MetronomeClick {
                t_ms: 1000,
                accent: false,
            },
        ]
    );
}

#[test]
fn metronome_clicks_are_emitted_once() {
    let compiled = compiled_fixture();
    let mut opts = SessionOpts::new(PracticeMode::Practice, 120.0, START_NS);
    opts.lookahead_ms = 600;
    let mut session = session_start(&compiled, opts);

    session_tick(&mut session, START_NS).unwrap();
    let first_batch = drain_events(&mut session, 16)
        .into_iter()
        .filter(|event| matches!(event, EngineEvent::MetronomeClick { .. }))
        .collect::<Vec<_>>();

    session_tick(&mut session, START_NS + 500_000_000).unwrap();
    let second_batch = drain_events(&mut session, 16)
        .into_iter()
        .filter(|event| matches!(event, EngineEvent::MetronomeClick { .. }))
        .collect::<Vec<_>>();

    assert_eq!(first_batch.len(), 2);
    assert_eq!(
        second_batch,
        vec![EngineEvent::MetronomeClick {
            t_ms: 1000,
            accent: false,
        }]
    );
}

fn runtime_session() -> Session {
    let compiled = compiled_fixture();
    let opts = SessionOpts::new(PracticeMode::Practice, 120.0, START_NS);
    session_start(&compiled, opts)
}

fn compiled_fixture() -> taal_core::content::CompiledLesson {
    let lesson = load_lesson(RUNTIME_LESSON).unwrap();
    let layout = load_layout(RUNTIME_LAYOUT).unwrap();
    let scoring = load_scoring_profile(RUNTIME_SCORING).unwrap();

    compile_lesson(&lesson, &layout, &scoring).unwrap()
}

fn hit(lane_id: &str, t_ms: i64) -> InputHit {
    InputHit::new(lane_id, 96, timestamp_ms(t_ms))
}

fn timestamp_ms(t_ms: i64) -> i128 {
    START_NS + i128::from(t_ms) * 1_000_000
}

fn assert_invalid_state(error: SessionError, expected: SessionState) {
    match error {
        SessionError::InvalidState { current, .. } => assert_eq!(current, expected),
    }
}

fn assert_summary_eq(left: &AttemptSummary, right: &AttemptSummary) {
    assert_eq!(left, right);
}

fn assert_close(actual: f32, expected: f32) {
    assert!(
        (actual - expected).abs() < 0.001,
        "expected {expected}, got {actual}"
    );
}
