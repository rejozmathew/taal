use std::collections::{HashMap, VecDeque};
use std::error::Error;
use std::fmt::{self, Display};

use uuid::Uuid;

use crate::content::{
    ComboConfig, CompiledLesson, EventPayload, GradeWeights, MusicalPos, PracticeMode,
    ScoringProfile, ScoringRules, TempoEntry, TimeSignature, TimingWindows,
};
use crate::scoring::{grade_delta_ms, ScoringEngine, ScoringUpdate};
use crate::time::TimingIndex;

pub use crate::scoring::{AttemptSummary, LaneStats};

const EXPECTED_ID: &str = "p0-expected-1";
const EXPECTED_LANE_ID: &str = "kick";
const EVENT_BUFFER_MAX: usize = 256;

#[repr(u8)]
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
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

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionState {
    Ready,
    Running,
    Paused,
    Stopped,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct SessionOpts {
    pub mode: PracticeMode,
    pub bpm: f32,
    pub start_time_ns: i128,
    pub lookahead_ms: i64,
}

impl SessionOpts {
    pub fn new(mode: PracticeMode, bpm: f32, start_time_ns: i128) -> Self {
        Self {
            mode,
            bpm,
            start_time_ns,
            lookahead_ms: 0,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum SessionError {
    InvalidState {
        current: SessionState,
        attempted: String,
    },
}

impl Display for SessionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidState { current, attempted } => {
                write!(f, "cannot {attempted} while session is {current:?}")
            }
        }
    }
}

impl Error for SessionError {}

#[derive(Debug)]
pub struct Session {
    compiled: CompiledLesson,
    opts: SessionOpts,
    state: SessionState,
    events: VecDeque<EngineEvent>,
    expected_status: Vec<ExpectedStatus>,
    pulse_emitted: Vec<bool>,
    metronome_clicks: Vec<MetronomeScheduleEntry>,
    next_metronome_index: usize,
    scoring: ScoringEngine,
    last_timeline_ms: i64,
    summary: Option<AttemptSummary>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct MetronomeScheduleEntry {
    t_ms: i64,
    accent: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ExpectedStatus {
    Pending,
    Hit,
    Missed,
}

pub fn session_start(compiled: &CompiledLesson, opts: SessionOpts) -> Session {
    let mut session = Session::new(compiled, opts);
    session
        .start()
        .expect("newly-created session must start from Ready");
    session
}

pub fn session_on_hit(session: &mut Session, hit: InputHit) -> Result<(), SessionError> {
    session.on_hit(hit)
}

pub fn session_tick(session: &mut Session, now_ns: i128) -> Result<(), SessionError> {
    session.tick(now_ns)
}

pub fn drain_events(session: &mut Session, max: usize) -> Vec<EngineEvent> {
    session.drain_events(max)
}

pub fn session_pause(session: &mut Session) -> Result<(), SessionError> {
    session.pause()
}

pub fn session_resume(session: &mut Session) -> Result<(), SessionError> {
    session.resume()
}

pub fn session_stop(session: &mut Session) -> Result<AttemptSummary, SessionError> {
    session.stop()
}

impl Session {
    pub fn new(compiled: &CompiledLesson, opts: SessionOpts) -> Self {
        let mut lane_counts = HashMap::<String, u32>::new();
        for lane_id in &compiled.lane_ids {
            lane_counts.entry(lane_id.clone()).or_insert(0);
        }
        for event in &compiled.events {
            *lane_counts.entry(event.lane_id.clone()).or_insert(0) += 1;
        }
        let metronome_clicks = build_metronome_schedule(compiled);

        Self {
            compiled: compiled.clone(),
            opts,
            state: SessionState::Ready,
            events: VecDeque::new(),
            expected_status: vec![ExpectedStatus::Pending; compiled.events.len()],
            pulse_emitted: vec![false; compiled.events.len()],
            metronome_clicks,
            next_metronome_index: 0,
            scoring: ScoringEngine::new(&compiled.scoring_profile, lane_counts),
            last_timeline_ms: 0,
            summary: None,
        }
    }

    pub fn state(&self) -> SessionState {
        self.state
    }

    pub fn start(&mut self) -> Result<(), SessionError> {
        match self.state {
            SessionState::Ready => {
                self.state = SessionState::Running;
                Ok(())
            }
            _ => Err(self.invalid_state("start")),
        }
    }

    pub fn pause(&mut self) -> Result<(), SessionError> {
        match self.state {
            SessionState::Running => {
                self.state = SessionState::Paused;
                Ok(())
            }
            _ => Err(self.invalid_state("pause")),
        }
    }

    pub fn resume(&mut self) -> Result<(), SessionError> {
        match self.state {
            SessionState::Paused => {
                self.state = SessionState::Running;
                Ok(())
            }
            _ => Err(self.invalid_state("resume")),
        }
    }

    pub fn on_hit(&mut self, hit: InputHit) -> Result<(), SessionError> {
        self.require_running("submit hit")?;

        let hit_timeline_ms = self.timestamp_to_timeline_ms(hit.timestamp_ns);
        self.last_timeline_ms = self.last_timeline_ms.max(hit_timeline_ms.round() as i64);
        let Some(index) = self.nearest_match_index(&hit.lane_id, hit_timeline_ms) else {
            self.push_event(EngineEvent::Warning {
                code: "unmatched_hit".to_owned(),
                message: format!(
                    "No pending expected event matched lane '{}' at {:.3}ms.",
                    hit.lane_id, hit_timeline_ms
                ),
            });
            return Ok(());
        };

        let expected_t_ms = self.compiled.events[index].t_ms as f64;
        let delta_ms = (hit_timeline_ms - expected_t_ms) as f32;
        let grade = grade_delta_ms(delta_ms, &self.compiled.scoring_profile.timing_windows_ms);
        let expected_id = self.compiled.events[index].expected_id.clone();
        let lane_id = self.compiled.events[index].lane_id.clone();

        self.expected_status[index] = ExpectedStatus::Hit;
        let scoring_update = self.scoring.record_hit(&lane_id, grade, delta_ms);

        self.push_event(EngineEvent::HitGraded {
            expected_id,
            lane_id,
            grade,
            delta_ms,
            combo: scoring_update.combo,
            streak: scoring_update.streak,
            score_running: scoring_update.score_running,
        });
        self.push_scoring_events(scoring_update);

        Ok(())
    }

    pub fn tick(&mut self, now_ns: i128) -> Result<(), SessionError> {
        self.require_running("tick")?;

        let now_ms = self.timestamp_to_timeline_ms(now_ns);
        self.last_timeline_ms = self.last_timeline_ms.max(now_ms.round() as i64);
        self.emit_expected_pulses(now_ms);
        self.emit_metronome_clicks(now_ms);
        let miss_cutoff_ms =
            now_ms - f64::from(self.compiled.scoring_profile.timing_windows_ms.outer_ms);

        for index in 0..self.compiled.events.len() {
            if self.expected_status[index] == ExpectedStatus::Pending
                && (self.compiled.events[index].t_ms as f64) < miss_cutoff_ms
            {
                self.record_miss(index, true);
            }
        }

        Ok(())
    }

    pub fn drain_events(&mut self, max: usize) -> Vec<EngineEvent> {
        let count = max.min(self.events.len());
        self.events.drain(..count).collect()
    }

    pub fn stop(&mut self) -> Result<AttemptSummary, SessionError> {
        match self.state {
            SessionState::Running | SessionState::Paused => {
                for index in 0..self.expected_status.len() {
                    self.record_miss(index, false);
                }
                self.state = SessionState::Stopped;
                let summary = self.build_summary();
                self.summary = Some(summary.clone());
                Ok(summary)
            }
            SessionState::Stopped => {
                Ok(self.summary.clone().unwrap_or_else(|| self.build_summary()))
            }
            SessionState::Ready => Err(self.invalid_state("stop")),
        }
    }

    fn nearest_match_index(&self, lane_id: &str, hit_timeline_ms: f64) -> Option<usize> {
        let outer_ms = f64::from(self.compiled.scoring_profile.timing_windows_ms.outer_ms);
        self.compiled
            .events
            .iter()
            .enumerate()
            .filter(|(index, event)| {
                self.expected_status[*index] == ExpectedStatus::Pending
                    && event.lane_id == lane_id
                    && (hit_timeline_ms - event.t_ms as f64).abs() <= outer_ms
            })
            .min_by(|(_, left), (_, right)| {
                let left_delta = (hit_timeline_ms - left.t_ms as f64).abs();
                let right_delta = (hit_timeline_ms - right.t_ms as f64).abs();
                left_delta.total_cmp(&right_delta)
            })
            .map(|(index, _)| index)
    }

    fn record_miss(&mut self, index: usize, emit_event: bool) {
        if self.expected_status[index] != ExpectedStatus::Pending {
            return;
        }

        let expected_id = self.compiled.events[index].expected_id.clone();
        let lane_id = self.compiled.events[index].lane_id.clone();

        self.expected_status[index] = ExpectedStatus::Missed;
        self.scoring.record_miss(&lane_id);

        if emit_event {
            self.push_event(EngineEvent::Missed {
                expected_id,
                lane_id,
            });
        }
    }

    fn emit_expected_pulses(&mut self, now_ms: f64) {
        let lookahead_end_ms = now_ms + self.opts.lookahead_ms.max(0) as f64;
        let pulses = self
            .compiled
            .events
            .iter()
            .enumerate()
            .filter(|(index, event)| {
                self.expected_status[*index] == ExpectedStatus::Pending
                    && !self.pulse_emitted[*index]
                    && (event.t_ms as f64) >= now_ms
                    && (event.t_ms as f64) <= lookahead_end_ms
            })
            .map(|(index, event)| {
                (
                    index,
                    EngineEvent::ExpectedPulse {
                        expected_id: event.expected_id.clone(),
                        lane_id: event.lane_id.clone(),
                        t_expected_ms: event.t_ms,
                    },
                )
            })
            .collect::<Vec<_>>();

        for (index, event) in pulses {
            self.pulse_emitted[index] = true;
            self.push_event(event);
        }
    }

    fn emit_metronome_clicks(&mut self, now_ms: f64) {
        let lookahead_end_ms = now_ms + self.opts.lookahead_ms.max(0) as f64;
        while let Some(click) = self
            .metronome_clicks
            .get(self.next_metronome_index)
            .copied()
        {
            if (click.t_ms as f64) < now_ms {
                self.next_metronome_index += 1;
                continue;
            }

            if (click.t_ms as f64) > lookahead_end_ms {
                break;
            }

            self.next_metronome_index += 1;
            self.push_event(EngineEvent::MetronomeClick {
                t_ms: click.t_ms,
                accent: click.accent,
            });
        }
    }

    fn build_summary(&self) -> AttemptSummary {
        self.scoring.summary(
            self.compiled.lesson_id,
            self.opts.mode,
            self.opts.bpm,
            self.last_timeline_ms.max(0) as u64,
        )
    }

    fn timestamp_to_timeline_ms(&self, timestamp_ns: i128) -> f64 {
        (timestamp_ns - self.opts.start_time_ns) as f64 / 1_000_000.0
    }

    fn require_running(&self, attempted: &str) -> Result<(), SessionError> {
        if self.state == SessionState::Running {
            Ok(())
        } else {
            Err(self.invalid_state(attempted))
        }
    }

    fn invalid_state(&self, attempted: &str) -> SessionError {
        SessionError::InvalidState {
            current: self.state,
            attempted: attempted.to_owned(),
        }
    }

    fn push_event(&mut self, event: EngineEvent) {
        if self.events.len() >= EVENT_BUFFER_MAX {
            if let Some(position) = self
                .events
                .iter()
                .position(|event| matches!(event, EngineEvent::ExpectedPulse { .. }))
            {
                self.events.remove(position);
            } else if matches!(event, EngineEvent::ExpectedPulse { .. }) {
                return;
            }
        }

        self.events.push_back(event);
    }

    fn push_scoring_events(&mut self, scoring_update: ScoringUpdate) {
        if let Some(milestone) = scoring_update.milestone {
            self.push_event(EngineEvent::ComboMilestone {
                combo: milestone.combo,
            });
            self.push_event(EngineEvent::Encouragement {
                message_id: milestone.message_id,
                text: milestone.text,
            });
        }
    }
}

fn build_metronome_schedule(compiled: &CompiledLesson) -> Vec<MetronomeScheduleEntry> {
    if compiled.total_duration_ms <= 0 {
        return Vec::new();
    }

    let time_signature = compiled.timing_index.time_signature();
    let ticks_per_beat = compiled.timing_index.ticks_per_beat();
    let mut pos = MusicalPos::new(1, 1, 0);
    let mut clicks = Vec::new();

    loop {
        let Ok(t_ms) = compiled.timing_index.pos_to_ms(pos) else {
            break;
        };
        if !t_ms.is_finite() || t_ms >= compiled.total_duration_ms as f64 {
            break;
        }

        clicks.push(MetronomeScheduleEntry {
            t_ms: t_ms.round() as i64,
            accent: pos.beat == 1,
        });

        let Ok(next_pos) =
            pos.checked_add_ticks(i64::from(ticks_per_beat), time_signature, ticks_per_beat)
        else {
            break;
        };
        pos = next_pos;
    }

    clicks
}

// Phase 0 compatibility helpers used by the latency bridge.
pub fn start_session() -> Session {
    let compiled = phase0_compiled_lesson();
    session_start(
        &compiled,
        SessionOpts::new(PracticeMode::Practice, 120.0, 0),
    )
}

pub fn submit_hit(session: &mut Session, hit: InputHit) {
    let _ = session_on_hit(session, hit);
}

fn phase0_compiled_lesson() -> CompiledLesson {
    let time_signature = TimeSignature { num: 4, den: 4 };
    let ticks_per_beat = 480;
    let tempo_map = [TempoEntry {
        pos: MusicalPos::new(1, 1, 0),
        bpm: 120.0,
    }];

    CompiledLesson {
        lesson_id: Uuid::nil(),
        timing_index: TimingIndex::from_tempo_map(time_signature, ticks_per_beat, &tempo_map)
            .expect("phase 0 timing fixture must be valid"),
        events: vec![crate::content::CompiledEvent {
            expected_id: EXPECTED_ID.to_owned(),
            lane_id: EXPECTED_LANE_ID.to_owned(),
            t_ms: 1000,
            pos: MusicalPos::new(1, 3, 0),
            payload: EventPayload::Hit {
                velocity: 96,
                articulation: "normal".to_owned(),
            },
        }],
        sections: Vec::new(),
        lane_ids: vec![EXPECTED_LANE_ID.to_owned()],
        scoring_profile: ScoringProfile {
            id: "phase0-standard".to_owned(),
            schema_version: "1.0".to_owned(),
            timing_windows_ms: TimingWindows {
                perfect_ms: 20.0,
                good_ms: 45.0,
                outer_ms: 120.0,
            },
            grading: GradeWeights {
                perfect: 1.0,
                good: 0.75,
                early: 0.5,
                late: 0.5,
                miss: 0.0,
            },
            combo: ComboConfig {
                encouragement_milestones: vec![8, 16, 32],
            },
            rules: ScoringRules {},
        },
        total_duration_ms: 1000,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const EXPECTED_TIMESTAMP_NS: i128 = 1_000_000_000;

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

        session_tick(&mut session, EXPECTED_TIMESTAMP_NS + 120_000_001).unwrap();

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

        session_tick(&mut session, EXPECTED_TIMESTAMP_NS + 120_000_000).unwrap();

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
