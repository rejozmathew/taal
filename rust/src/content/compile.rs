use std::collections::HashSet;
use std::error::Error;
use std::fmt::{self, Display};

use uuid::Uuid;

use crate::time::{TimeError, TimingIndex};

use super::{EventPayload, InstrumentLayout, Lesson, MusicalPos, ScoringProfile};

#[derive(Debug, Clone, PartialEq)]
pub enum CompileError {
    MissingLayout { layout_id: String },
    MissingScoringProfile { profile_id: String },
    EmptyLesson,
    InvalidTempoMap(String),
    InvariantViolation { rule: String, message: String },
}

impl CompileError {
    fn invariant(rule: impl Into<String>, message: impl Into<String>) -> Self {
        Self::InvariantViolation {
            rule: rule.into(),
            message: message.into(),
        }
    }
}

impl Display for CompileError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::MissingLayout { layout_id } => {
                write!(f, "missing compatible layout '{layout_id}'")
            }
            Self::MissingScoringProfile { profile_id } => {
                write!(f, "missing scoring profile '{profile_id}'")
            }
            Self::EmptyLesson => write!(f, "lesson contains no events to compile"),
            Self::InvalidTempoMap(message) => write!(f, "invalid tempo map: {message}"),
            Self::InvariantViolation { rule, message } => {
                write!(f, "compile invariant '{rule}' failed: {message}")
            }
        }
    }
}

impl Error for CompileError {}

#[derive(Debug, Clone, PartialEq)]
pub struct CompiledLesson {
    pub lesson_id: Uuid,
    pub timing_index: TimingIndex,
    pub events: Vec<CompiledEvent>,
    pub sections: Vec<CompiledSection>,
    pub lane_ids: Vec<String>,
    pub scoring_profile: ScoringProfile,
    pub total_duration_ms: i64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct CompiledEvent {
    pub expected_id: String,
    pub lane_id: String,
    pub t_ms: i64,
    pub pos: MusicalPos,
    pub payload: EventPayload,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CompiledSection {
    pub section_id: String,
    pub label: String,
    pub start_ms: i64,
    pub end_ms: i64,
    pub loopable: bool,
}

pub fn compile_lesson(
    lesson: &Lesson,
    layout: &InstrumentLayout,
    scoring: &ScoringProfile,
) -> Result<CompiledLesson, CompileError> {
    validate_layout_reference(lesson, layout)?;
    validate_scoring_reference(lesson, scoring)?;

    let timing_index = TimingIndex::from_timing_config(&lesson.timing).map_err(map_time_error)?;

    let lane_ids = lesson
        .lanes
        .iter()
        .map(|lane| lane.lane_id.clone())
        .collect::<Vec<_>>();

    let mut events = Vec::new();
    for lane in &lesson.lanes {
        for event in &lane.events {
            let t_ms = pos_to_rounded_ms(&timing_index, event.pos)?;
            events.push(CompiledEvent {
                expected_id: event.event_id.clone(),
                lane_id: lane.lane_id.clone(),
                t_ms,
                pos: event.pos,
                payload: event.payload.clone(),
            });
        }
    }

    if events.is_empty() {
        return Err(CompileError::EmptyLesson);
    }

    events.sort_by(|left, right| {
        left.t_ms
            .cmp(&right.t_ms)
            .then_with(|| left.lane_id.cmp(&right.lane_id))
            .then_with(|| left.expected_id.cmp(&right.expected_id))
    });
    validate_no_duplicate_lane_time(&events)?;

    let mut sections = Vec::with_capacity(lesson.sections.len());
    for section in &lesson.sections {
        let start_ms = pos_to_rounded_ms(&timing_index, section.range.start)?;
        let end_ms = pos_to_rounded_ms(&timing_index, section.range.end)?;
        sections.push(CompiledSection {
            section_id: section.section_id.clone(),
            label: section.label.clone(),
            start_ms,
            end_ms,
            loopable: section.loopable,
        });
    }

    let total_duration_ms = sections
        .iter()
        .map(|section| section.end_ms)
        .chain(events.iter().map(|event| event.t_ms))
        .max()
        .unwrap_or(0);

    Ok(CompiledLesson {
        lesson_id: lesson.id,
        timing_index,
        events,
        sections,
        lane_ids,
        scoring_profile: scoring.clone(),
        total_duration_ms,
    })
}

fn validate_layout_reference(
    lesson: &Lesson,
    layout: &InstrumentLayout,
) -> Result<(), CompileError> {
    if lesson.instrument.layout_id != layout.id {
        return Err(CompileError::MissingLayout {
            layout_id: lesson.instrument.layout_id.clone(),
        });
    }

    if lesson.instrument.family != layout.family || lesson.instrument.variant != layout.variant {
        return Err(CompileError::MissingLayout {
            layout_id: lesson.instrument.layout_id.clone(),
        });
    }

    let layout_lanes = layout
        .lanes
        .iter()
        .map(|lane| lane.lane_id.as_str())
        .collect::<HashSet<_>>();

    for lane in &lesson.lanes {
        if !layout_lanes.contains(lane.lane_id.as_str()) {
            return Err(CompileError::invariant(
                "compile.lane_in_layout",
                format!(
                    "lesson lane '{}' is not defined by layout '{}'",
                    lane.lane_id, layout.id
                ),
            ));
        }
    }

    Ok(())
}

fn validate_scoring_reference(
    lesson: &Lesson,
    scoring: &ScoringProfile,
) -> Result<(), CompileError> {
    if matches!(&lesson.scoring_profile_id, Some(profile_id) if profile_id != &scoring.id) {
        return Err(CompileError::MissingScoringProfile {
            profile_id: lesson.scoring_profile_id.clone().unwrap(),
        });
    }

    Ok(())
}

fn pos_to_rounded_ms(timing_index: &TimingIndex, pos: MusicalPos) -> Result<i64, CompileError> {
    let ms = timing_index.pos_to_ms(pos).map_err(map_time_error)?;
    if !ms.is_finite() || ms < i64::MIN as f64 || ms > i64::MAX as f64 {
        return Err(CompileError::InvalidTempoMap(
            "position conversion produced milliseconds outside i64 range".to_owned(),
        ));
    }

    Ok(ms.round() as i64)
}

fn validate_no_duplicate_lane_time(events: &[CompiledEvent]) -> Result<(), CompileError> {
    let mut seen = HashSet::with_capacity(events.len());
    for event in events {
        if !seen.insert((event.lane_id.as_str(), event.t_ms)) {
            return Err(CompileError::invariant(
                "compile.no_duplicate_lane_time",
                format!(
                    "duplicate compiled event for lane '{}' at {}ms",
                    event.lane_id, event.t_ms
                ),
            ));
        }
    }

    Ok(())
}

fn map_time_error(error: TimeError) -> CompileError {
    CompileError::InvalidTempoMap(error.to_string())
}
