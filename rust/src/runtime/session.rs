use std::collections::VecDeque;

const EXPECTED_ID: &str = "p0-expected-1";
const EXPECTED_LANE_ID: &str = "kick";
const EXPECTED_TIMESTAMP_NS: i128 = 1_000_000_000;
const PERFECT_WINDOW_NS: i128 = 20_000_000;
const GOOD_WINDOW_NS: i128 = 45_000_000;
const OUTER_WINDOW_NS: i128 = 120_000_000;

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Grade {
    Perfect = 0,
    Good = 1,
    Early = 2,
    Late = 3,
    Miss = 4,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct InputHit {
    pub lane_id: String,
    pub velocity: u8,
    pub timestamp_ns: i128,
    pub midi_note: Option<u8>,
}

impl InputHit {
    pub fn new(lane_id: impl Into<String>, velocity: u8, timestamp_ns: i128) -> Self {
        Self {
            lane_id: lane_id.into(),
            velocity,
            timestamp_ns,
            midi_note: None,
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub enum EngineEvent {
    ExpectedPulse {
        expected_id: String,
        lane_id: String,
        t_expected_ms: i64,
    },
    HitGraded {
        expected_id: String,
        lane_id: String,
        grade: Grade,
        delta_ms: f32,
        combo: u32,
        streak: u32,
        score_running: f32,
    },
    Missed {
        expected_id: String,
        lane_id: String,
    },
    ComboMilestone {
        combo: u32,
    },
    Encouragement {
        message_id: String,
        text: String,
    },
    SectionBoundary {
        section_id: String,
        entering: bool,
    },
    MetronomeClick {
        t_ms: i64,
        accent: bool,
    },
    Warning {
        code: String,
        message: String,
    },
}

#[derive(Debug)]
pub struct Session {
    expected: ExpectedEvent,
    events: VecDeque<EngineEvent>,
    hit_graded: bool,
    miss_emitted: bool,
    combo: u32,
    streak: u32,
    score_running: f32,
}

#[derive(Debug)]
struct ExpectedEvent {
    expected_id: String,
    lane_id: String,
    timestamp_ns: i128,
}

pub fn start_session() -> Session {
    Session {
        expected: ExpectedEvent {
            expected_id: EXPECTED_ID.to_owned(),
            lane_id: EXPECTED_LANE_ID.to_owned(),
            timestamp_ns: EXPECTED_TIMESTAMP_NS,
        },
        events: VecDeque::new(),
        hit_graded: false,
        miss_emitted: false,
        combo: 0,
        streak: 0,
        score_running: 0.0,
    }
}

pub fn submit_hit(session: &mut Session, hit: InputHit) {
    if session.hit_graded || session.miss_emitted {
        return;
    }

    if hit.lane_id != session.expected.lane_id {
        session.events.push_back(EngineEvent::Warning {
            code: "lane_mismatch".to_owned(),
            message: format!(
                "Ignoring hit for lane '{}' while expecting '{}'.",
                hit.lane_id, session.expected.lane_id
            ),
        });
        return;
    }

    let delta_ns = hit.timestamp_ns - session.expected.timestamp_ns;
    let grade = grade_delta(delta_ns);
    let delta_ms = delta_ns as f32 / 1_000_000.0;

    session.hit_graded = true;
    session.combo = match grade {
        Grade::Miss => 0,
        Grade::Perfect | Grade::Good | Grade::Early | Grade::Late => session.combo + 1,
    };
    if matches!(grade, Grade::Perfect | Grade::Good) {
        session.streak += 1;
    }
    session.score_running = match grade {
        Grade::Perfect => 100.0,
        Grade::Good => 75.0,
        Grade::Early | Grade::Late => 50.0,
        Grade::Miss => 0.0,
    };

    session.events.push_back(EngineEvent::HitGraded {
        expected_id: session.expected.expected_id.clone(),
        lane_id: session.expected.lane_id.clone(),
        grade,
        delta_ms,
        combo: session.combo,
        streak: session.streak,
        score_running: session.score_running,
    });
}

pub fn session_tick(session: &mut Session, now_ns: i128) {
    if session.hit_graded || session.miss_emitted {
        return;
    }

    if now_ns > session.expected.timestamp_ns + OUTER_WINDOW_NS {
        session.combo = 0;
        session.streak = 0;
        session.miss_emitted = true;
        session.events.push_back(EngineEvent::Missed {
            expected_id: session.expected.expected_id.clone(),
            lane_id: session.expected.lane_id.clone(),
        });
    }
}

pub fn drain_events(session: &mut Session, max: usize) -> Vec<EngineEvent> {
    let count = max.min(session.events.len());
    session.events.drain(..count).collect()
}

fn grade_delta(delta_ns: i128) -> Grade {
    let abs_delta = delta_ns.abs();
    if abs_delta <= PERFECT_WINDOW_NS {
        Grade::Perfect
    } else if abs_delta <= GOOD_WINDOW_NS {
        Grade::Good
    } else if delta_ns < 0 {
        Grade::Early
    } else {
        Grade::Late
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn submit_near_hit_gets_perfect_grade() {
        let mut session = start_session();

        submit_hit(
            &mut session,
            InputHit::new("kick", 96, EXPECTED_TIMESTAMP_NS + 5_000_000),
        );

        assert_hit_grade(&mut session, Grade::Perfect, 5.0, 1);
    }

    #[test]
    fn submit_early_hit_gets_early_grade() {
        let mut session = start_session();

        submit_hit(
            &mut session,
            InputHit::new("kick", 96, EXPECTED_TIMESTAMP_NS - 70_000_000),
        );

        assert_hit_grade(&mut session, Grade::Early, -70.0, 1);
    }

    #[test]
    fn submit_late_hit_gets_late_grade() {
        let mut session = start_session();

        submit_hit(
            &mut session,
            InputHit::new("kick", 96, EXPECTED_TIMESTAMP_NS + 70_000_000),
        );

        assert_hit_grade(&mut session, Grade::Late, 70.0, 1);
    }

    #[test]
    fn tick_after_outer_window_emits_miss() {
        let mut session = start_session();

        session_tick(&mut session, EXPECTED_TIMESTAMP_NS + OUTER_WINDOW_NS + 1);

        assert_eq!(
            drain_events(&mut session, 8),
            vec![EngineEvent::Missed {
                expected_id: EXPECTED_ID.to_owned(),
                lane_id: EXPECTED_LANE_ID.to_owned(),
            }]
        );
    }

    #[test]
    fn tick_before_outer_window_does_not_emit_miss() {
        let mut session = start_session();

        session_tick(&mut session, EXPECTED_TIMESTAMP_NS + OUTER_WINDOW_NS);

        assert!(drain_events(&mut session, 8).is_empty());
    }

    #[test]
    fn drain_events_respects_max() {
        let mut session = start_session();
        submit_hit(
            &mut session,
            InputHit::new("wrong", 96, EXPECTED_TIMESTAMP_NS),
        );
        submit_hit(
            &mut session,
            InputHit::new("wrong", 96, EXPECTED_TIMESTAMP_NS),
        );

        assert_eq!(drain_events(&mut session, 1).len(), 1);
        assert_eq!(drain_events(&mut session, 8).len(), 1);
    }

    fn assert_hit_grade(session: &mut Session, grade: Grade, delta_ms: f32, combo: u32) {
        let events = drain_events(session, 8);
        assert_eq!(events.len(), 1);

        match &events[0] {
            EngineEvent::HitGraded {
                expected_id,
                lane_id,
                grade: actual_grade,
                delta_ms: actual_delta_ms,
                combo: actual_combo,
                ..
            } => {
                assert_eq!(expected_id, EXPECTED_ID);
                assert_eq!(lane_id, EXPECTED_LANE_ID);
                assert_eq!(*actual_grade, grade);
                assert_eq!(*actual_delta_ms, delta_ms);
                assert_eq!(*actual_combo, combo);
            }
            other => panic!("expected HitGraded event, got {other:?}"),
        }
    }
}
