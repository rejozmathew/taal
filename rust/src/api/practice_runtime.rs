use std::collections::HashMap;

use serde::Serialize;

use crate::api::simple::monotonic_now_ns;
use crate::content::{
    compile_lesson, load_layout, load_lesson, load_scoring_profile, CompiledLesson, EventPayload,
    InstrumentLayout, PracticeMode,
};
use crate::midi::{load_device_profile, MappingResult, MidiMapper, RawMidiEvent, RawMidiEventType};
use crate::runtime::practice_runtime::{
    insert_runtime_session, remove_runtime_session, with_runtime_session, PracticeRuntimeSession,
};
use crate::runtime::session::{
    drain_events, session_on_hit, session_pause, session_resume, session_start, session_stop,
    session_tick, EngineEvent, Grade, InputHit, Session, SessionOpts,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PracticeRuntimeModeDto {
    Practice,
    Play,
    CourseGate,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PracticeRuntimeStartResult {
    pub session_id: Option<u32>,
    pub timeline_json: Option<String>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PracticeRuntimeStartRequest {
    pub lesson_json: String,
    pub layout_json: String,
    pub scoring_profile_json: String,
    pub device_profile_json: Option<String>,
    pub mode: PracticeRuntimeModeDto,
    pub bpm: f32,
    pub start_time_ns: i64,
    pub lookahead_ms: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PracticeRuntimeOperationResult {
    pub events_json: Option<String>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PracticeRuntimeStopResult {
    pub summary_json: Option<String>,
    pub events_json: Option<String>,
    pub error: Option<String>,
}

#[flutter_rust_bridge::frb(sync)]
pub fn practice_runtime_clock_ns() -> i64 {
    monotonic_now_ns()
}

#[flutter_rust_bridge::frb(sync)]
pub fn start_practice_runtime_session(
    request: PracticeRuntimeStartRequest,
) -> PracticeRuntimeStartResult {
    match start_session_impl(&request) {
        Ok((session_id, timeline_json)) => PracticeRuntimeStartResult {
            session_id: Some(session_id),
            timeline_json: Some(timeline_json),
            error: None,
        },
        Err(error) => PracticeRuntimeStartResult {
            session_id: None,
            timeline_json: None,
            error: Some(error),
        },
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn practice_runtime_submit_touch_hit(
    session_id: u32,
    lane_id: String,
    velocity: u8,
    timestamp_ns: i64,
) -> PracticeRuntimeOperationResult {
    let result = with_runtime_session(session_id, |runtime| {
        validate_velocity(velocity)?;
        let hit = InputHit {
            lane_id,
            velocity,
            timestamp_ns: i128::from(timestamp_ns),
            midi_note: None,
        };
        session_on_hit(&mut runtime.session, hit).map_err(|error| error.to_string())?;
        drain_runtime_events(&mut runtime.session)
    });
    PracticeRuntimeOperationResult::from_result(result)
}

#[flutter_rust_bridge::frb(sync)]
pub fn practice_runtime_submit_midi_note_on(
    session_id: u32,
    channel: u8,
    note: u8,
    velocity: u8,
    timestamp_ns: i64,
) -> PracticeRuntimeOperationResult {
    let result = with_runtime_session(session_id, |runtime| {
        validate_channel(channel)?;
        let event = RawMidiEvent {
            event_type: RawMidiEventType::NoteOn,
            channel,
            data1: note,
            data2: velocity,
            timestamp_ns: i128::from(timestamp_ns),
        };
        submit_midi_event(runtime, event)
    });
    PracticeRuntimeOperationResult::from_result(result)
}

#[flutter_rust_bridge::frb(sync)]
pub fn practice_runtime_submit_midi_control_change(
    session_id: u32,
    channel: u8,
    controller: u8,
    value: u8,
    timestamp_ns: i64,
) -> PracticeRuntimeOperationResult {
    let result = with_runtime_session(session_id, |runtime| {
        validate_channel(channel)?;
        let event = RawMidiEvent {
            event_type: RawMidiEventType::ControlChange,
            channel,
            data1: controller,
            data2: value,
            timestamp_ns: i128::from(timestamp_ns),
        };
        submit_midi_event(runtime, event)
    });
    PracticeRuntimeOperationResult::from_result(result)
}

#[flutter_rust_bridge::frb(sync)]
pub fn practice_runtime_tick(session_id: u32, now_ns: i64) -> PracticeRuntimeOperationResult {
    let result = with_runtime_session(session_id, |runtime| {
        session_tick(&mut runtime.session, i128::from(now_ns))
            .map_err(|error| error.to_string())?;
        drain_runtime_events(&mut runtime.session)
    });
    PracticeRuntimeOperationResult::from_result(result)
}

#[flutter_rust_bridge::frb(sync)]
pub fn practice_runtime_drain_events(session_id: u32) -> PracticeRuntimeOperationResult {
    let result = with_runtime_session(session_id, |runtime| {
        drain_runtime_events(&mut runtime.session)
    });
    PracticeRuntimeOperationResult::from_result(result)
}

#[flutter_rust_bridge::frb(sync)]
pub fn practice_runtime_pause(session_id: u32) -> PracticeRuntimeOperationResult {
    let result = with_runtime_session(session_id, |runtime| {
        session_pause(&mut runtime.session).map_err(|error| error.to_string())?;
        drain_runtime_events(&mut runtime.session)
    });
    PracticeRuntimeOperationResult::from_result(result)
}

#[flutter_rust_bridge::frb(sync)]
pub fn practice_runtime_resume(session_id: u32) -> PracticeRuntimeOperationResult {
    let result = with_runtime_session(session_id, |runtime| {
        session_resume(&mut runtime.session).map_err(|error| error.to_string())?;
        drain_runtime_events(&mut runtime.session)
    });
    PracticeRuntimeOperationResult::from_result(result)
}

#[flutter_rust_bridge::frb(sync)]
pub fn practice_runtime_stop(session_id: u32) -> PracticeRuntimeStopResult {
    let result = with_runtime_session(session_id, |runtime| {
        let summary = session_stop(&mut runtime.session).map_err(|error| error.to_string())?;
        let summary_json = serde_json::to_string(&summary).map_err(|error| error.to_string())?;
        let events_json = drain_runtime_events(&mut runtime.session)?;
        Ok((summary_json, events_json))
    });

    match result {
        Ok((summary_json, events_json)) => PracticeRuntimeStopResult {
            summary_json: Some(summary_json),
            events_json: Some(events_json),
            error: None,
        },
        Err(error) => PracticeRuntimeStopResult {
            summary_json: None,
            events_json: None,
            error: Some(error),
        },
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn practice_runtime_dispose(session_id: u32) -> PracticeRuntimeOperationResult {
    let result = remove_runtime_session(session_id).map(|()| empty_events_json());
    PracticeRuntimeOperationResult::from_result(result)
}

fn start_session_impl(request: &PracticeRuntimeStartRequest) -> Result<(u32, String), String> {
    if !request.bpm.is_finite() || request.bpm <= 0.0 {
        return Err("bpm must be finite and positive".to_owned());
    }

    let lesson = load_lesson(&request.lesson_json).map_err(|error| error.to_string())?;
    let layout = load_layout(&request.layout_json).map_err(|error| error.to_string())?;
    let scoring =
        load_scoring_profile(&request.scoring_profile_json).map_err(|error| error.to_string())?;
    let compiled = compile_lesson(&lesson, &layout, &scoring).map_err(|error| error.to_string())?;
    let timeline_json = timeline_json(&compiled, &layout, request.mode, request.bpm)?;

    let mapper = match request.device_profile_json.as_deref() {
        Some(json) if !json.trim().is_empty() => {
            let profile = load_device_profile(json).map_err(|error| error.to_string())?;
            Some(MidiMapper::new(profile).map_err(|error| error.to_string())?)
        }
        _ => None,
    };

    let mut opts = SessionOpts::new(
        request.mode.into(),
        request.bpm,
        i128::from(request.start_time_ns),
    );
    opts.lookahead_ms = request.lookahead_ms;
    let session = session_start(&compiled, opts);

    let session_id = insert_runtime_session(PracticeRuntimeSession { session, mapper })?;
    Ok((session_id, timeline_json))
}

fn submit_midi_event(
    runtime: &mut PracticeRuntimeSession,
    event: RawMidiEvent,
) -> Result<String, String> {
    let Some(mapper) = runtime.mapper.as_mut() else {
        return Err("MIDI input requires a device profile for lane mapping".to_owned());
    };

    match mapper.process_event(event) {
        Some(MappingResult::Hit(mapped)) => {
            let hit = InputHit {
                lane_id: mapped.lane_id,
                velocity: mapped.velocity,
                timestamp_ns: mapped.timestamp_ns,
                midi_note: Some(mapped.raw_note),
            };
            session_on_hit(&mut runtime.session, hit).map_err(|error| error.to_string())?;
        }
        Some(MappingResult::Unmapped {
            note,
            velocity,
            timestamp_ns,
        }) => runtime.session.push_warning(
            "unmapped_midi_note",
            format!("MIDI note {note} velocity {velocity} at {timestamp_ns}ns is not mapped."),
        ),
        Some(MappingResult::Suppressed) | None => {}
    }

    drain_runtime_events(&mut runtime.session)
}

fn drain_runtime_events(session: &mut Session) -> Result<String, String> {
    let events = drain_events(session, 256)
        .into_iter()
        .map(EngineEventDto::from)
        .collect::<Vec<_>>();
    serde_json::to_string(&events).map_err(|error| error.to_string())
}

fn empty_events_json() -> String {
    "[]".to_owned()
}

fn validate_channel(channel: u8) -> Result<(), String> {
    if channel <= 15 {
        Ok(())
    } else {
        Err("MIDI channel must be in range 0..=15".to_owned())
    }
}

fn validate_velocity(velocity: u8) -> Result<(), String> {
    if (1..=127).contains(&velocity) {
        Ok(())
    } else {
        Err("velocity must be in MIDI range 1..=127".to_owned())
    }
}

fn timeline_json(
    compiled: &CompiledLesson,
    layout: &InstrumentLayout,
    mode: PracticeRuntimeModeDto,
    bpm: f32,
) -> Result<String, String> {
    let slot_by_lane = layout
        .visual
        .lane_slots
        .iter()
        .map(|slot| (slot.lane_id.as_str(), slot.slot_id.as_str()))
        .collect::<HashMap<_, _>>();

    let lanes = layout
        .lanes
        .iter()
        .filter(|lane| compiled.lane_ids.iter().any(|id| id == &lane.lane_id))
        .map(|lane| TimelineLaneDto {
            lane_id: lane.lane_id.clone(),
            label: lane.label.clone(),
            slot_id: slot_by_lane
                .get(lane.lane_id.as_str())
                .copied()
                .unwrap_or(lane.lane_id.as_str())
                .to_owned(),
        })
        .collect();

    let notes = compiled
        .events
        .iter()
        .map(|event| TimelineNoteDto {
            expected_id: event.expected_id.clone(),
            lane_id: event.lane_id.clone(),
            t_ms: event.t_ms,
            articulation: match &event.payload {
                EventPayload::Hit { articulation, .. } => articulation.clone(),
                EventPayload::Note { .. } => "note".to_owned(),
            },
        })
        .collect();

    let sections = compiled
        .sections
        .iter()
        .map(|section| TimelineSectionDto {
            section_id: section.section_id.clone(),
            label: section.label.clone(),
            start_ms: section.start_ms,
            end_ms: section.end_ms,
            loopable: section.loopable,
        })
        .collect();

    serde_json::to_string(&PracticeRuntimeTimelineDto {
        lesson_id: compiled.lesson_id.to_string(),
        mode: mode.as_str().to_owned(),
        bpm,
        total_duration_ms: compiled.total_duration_ms,
        lanes,
        notes,
        sections,
    })
    .map_err(|error| error.to_string())
}

impl PracticeRuntimeOperationResult {
    fn from_result(result: Result<String, String>) -> Self {
        match result {
            Ok(events_json) => Self {
                events_json: Some(events_json),
                error: None,
            },
            Err(error) => Self {
                events_json: None,
                error: Some(error),
            },
        }
    }
}

impl From<PracticeRuntimeModeDto> for PracticeMode {
    fn from(value: PracticeRuntimeModeDto) -> Self {
        match value {
            PracticeRuntimeModeDto::Practice => PracticeMode::Practice,
            PracticeRuntimeModeDto::Play => PracticeMode::Play,
            PracticeRuntimeModeDto::CourseGate => PracticeMode::CourseGate,
        }
    }
}

impl PracticeRuntimeModeDto {
    fn as_str(self) -> &'static str {
        match self {
            Self::Practice => "practice",
            Self::Play => "play",
            Self::CourseGate => "course_gate",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
struct PracticeRuntimeTimelineDto {
    lesson_id: String,
    mode: String,
    bpm: f32,
    total_duration_ms: i64,
    lanes: Vec<TimelineLaneDto>,
    notes: Vec<TimelineNoteDto>,
    sections: Vec<TimelineSectionDto>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
struct TimelineLaneDto {
    lane_id: String,
    label: String,
    slot_id: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
struct TimelineNoteDto {
    expected_id: String,
    lane_id: String,
    t_ms: i64,
    articulation: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
struct TimelineSectionDto {
    section_id: String,
    label: String,
    start_ms: i64,
    end_ms: i64,
    loopable: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
#[serde(tag = "type", rename_all = "snake_case")]
enum EngineEventDto {
    ExpectedPulse {
        expected_id: String,
        lane_id: String,
        t_expected_ms: i64,
    },
    HitGraded {
        expected_id: String,
        lane_id: String,
        grade: &'static str,
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

impl From<EngineEvent> for EngineEventDto {
    fn from(value: EngineEvent) -> Self {
        match value {
            EngineEvent::ExpectedPulse {
                expected_id,
                lane_id,
                t_expected_ms,
            } => Self::ExpectedPulse {
                expected_id,
                lane_id,
                t_expected_ms,
            },
            EngineEvent::HitGraded {
                expected_id,
                lane_id,
                grade,
                delta_ms,
                combo,
                streak,
                score_running,
            } => Self::HitGraded {
                expected_id,
                lane_id,
                grade: grade_as_str(grade),
                delta_ms,
                combo,
                streak,
                score_running,
            },
            EngineEvent::Missed {
                expected_id,
                lane_id,
            } => Self::Missed {
                expected_id,
                lane_id,
            },
            EngineEvent::ComboMilestone { combo } => Self::ComboMilestone { combo },
            EngineEvent::Encouragement { message_id, text } => {
                Self::Encouragement { message_id, text }
            }
            EngineEvent::SectionBoundary {
                section_id,
                entering,
            } => Self::SectionBoundary {
                section_id,
                entering,
            },
            EngineEvent::MetronomeClick { t_ms, accent } => Self::MetronomeClick { t_ms, accent },
            EngineEvent::Warning { code, message } => Self::Warning { code, message },
        }
    }
}

fn grade_as_str(grade: Grade) -> &'static str {
    match grade {
        Grade::Perfect => "perfect",
        Grade::Good => "good",
        Grade::Early => "early",
        Grade::Late => "late",
        Grade::Miss => "miss",
    }
}
