use std::collections::HashSet;

use serde::{de, Deserialize, Deserializer, Serialize};
use serde_json::{Map, Value};
use uuid::Uuid;

use super::{ensure_schema_version, parse_json, ContentError};

pub type PublisherRef = Map<String, Value>;

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Lesson {
    pub id: Uuid,
    pub schema_version: String,
    pub revision: String,
    pub title: String,
    pub description: Option<String>,
    pub language: Option<String>,
    pub instrument: InstrumentRef,
    pub timing: TimingConfig,
    pub lanes: Vec<Lane>,
    pub sections: Vec<Section>,
    pub practice: PracticeDefaults,
    pub metadata: LessonMeta,
    #[serde(default)]
    pub optional_lanes: Vec<String>,
    pub scoring_profile_id: Option<String>,
    #[serde(default)]
    pub assets: AssetRefs,
    #[serde(default)]
    pub references: ContentRefs,
    #[serde(default, deserialize_with = "deserialize_optional_json_object")]
    pub publisher: Option<PublisherRef>,
    pub extensions: Option<Value>,
}

impl Lesson {
    pub fn validate(&self) -> Result<(), ContentError> {
        ensure_schema_version(&self.schema_version)?;
        self.timing.validate()?;
        self.practice.validate()?;

        let mut lane_ids = HashSet::new();
        let mut event_ids = HashSet::new();
        let mut total_events = 0_usize;

        for lane in &self.lanes {
            if !lane_ids.insert(lane.lane_id.as_str()) {
                return Err(ContentError::invariant(
                    "lesson.lane_id_unique",
                    format!("duplicate lane_id '{}'", lane.lane_id),
                ));
            }

            let mut previous_pos = None;
            for event in &lane.events {
                total_events += 1;

                if !event_ids.insert(event.event_id.as_str()) {
                    return Err(ContentError::invariant(
                        "lesson.event_id_unique",
                        format!("duplicate event_id '{}'", event.event_id),
                    ));
                }

                self.timing
                    .validate_position(&event.pos, "lanes.events.pos")?;

                if let Some(previous_pos) = previous_pos {
                    if event.pos < previous_pos {
                        return Err(ContentError::invariant(
                            "lesson.events_sorted_by_position",
                            format!(
                                "events in lane '{}' are not sorted by musical position",
                                lane.lane_id
                            ),
                        ));
                    }
                }
                previous_pos = Some(event.pos);

                event.validate()?;
            }
        }

        if total_events == 0 {
            return Err(ContentError::invariant(
                "lesson.has_events",
                "lesson must contain at least one lane event",
            ));
        }

        self.validate_sections()
    }

    fn validate_sections(&self) -> Result<(), ContentError> {
        let mut section_ids = HashSet::new();
        let mut ranges = Vec::with_capacity(self.sections.len());

        for section in &self.sections {
            if !section_ids.insert(section.section_id.as_str()) {
                return Err(ContentError::invariant(
                    "lesson.section_id_unique",
                    format!("duplicate section_id '{}'", section.section_id),
                ));
            }

            self.timing
                .validate_position(&section.range.start, "sections.range.start")?;
            self.timing
                .validate_position(&section.range.end, "sections.range.end")?;

            if section.range.end <= section.range.start {
                return Err(ContentError::invariant(
                    "lesson.section_end_after_start",
                    format!("section '{}' has end <= start", section.section_id),
                ));
            }

            ranges.push((&section.section_id, section.range.start, section.range.end));
        }

        ranges.sort_by_key(|(_, start, _)| *start);
        for pair in ranges.windows(2) {
            let (_, _, previous_end) = pair[0];
            let (section_id, next_start, _) = pair[1];

            if next_start < previous_end {
                return Err(ContentError::invariant(
                    "lesson.sections_non_overlapping",
                    format!("section '{section_id}' overlaps a previous section"),
                ));
            }
        }

        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct InstrumentRef {
    pub family: String,
    pub variant: String,
    pub layout_id: String,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TimingConfig {
    pub time_signature: TimeSignature,
    pub ticks_per_beat: u16,
    pub tempo_map: Vec<TempoEntry>,
}

impl TimingConfig {
    fn validate(&self) -> Result<(), ContentError> {
        if self.time_signature.num == 0 {
            return Err(ContentError::invariant(
                "lesson.time_signature_num_positive",
                "time_signature.num must be greater than 0",
            ));
        }

        if self.time_signature.den == 0 {
            return Err(ContentError::invariant(
                "lesson.time_signature_den_positive",
                "time_signature.den must be greater than 0",
            ));
        }

        if self.ticks_per_beat == 0 {
            return Err(ContentError::invariant(
                "lesson.ticks_per_beat_positive",
                "ticks_per_beat must be greater than 0",
            ));
        }

        if self.tempo_map.is_empty() {
            return Err(ContentError::invariant(
                "lesson.tempo_map_non_empty",
                "tempo_map must contain at least one entry",
            ));
        }

        let mut previous_pos = None;
        for entry in &self.tempo_map {
            self.validate_position(&entry.pos, "timing.tempo_map.pos")?;

            if entry.bpm <= 0.0 {
                return Err(ContentError::invariant(
                    "lesson.tempo_bpm_positive",
                    "tempo_map bpm values must be greater than 0",
                ));
            }

            if let Some(previous_pos) = previous_pos {
                if entry.pos <= previous_pos {
                    return Err(ContentError::invariant(
                        "lesson.tempo_map_monotonic",
                        "tempo_map positions must be strictly increasing",
                    ));
                }
            }
            previous_pos = Some(entry.pos);
        }

        Ok(())
    }

    fn validate_position(&self, pos: &MusicalPos, field: &str) -> Result<(), ContentError> {
        if pos.bar == 0 {
            return Err(ContentError::invariant(
                "lesson.position_bar_one_based",
                format!("{field}.bar must be greater than or equal to 1"),
            ));
        }

        if pos.beat == 0 || pos.beat > self.time_signature.num {
            return Err(ContentError::invariant(
                "lesson.position_beat_in_time_signature",
                format!(
                    "{field}.beat must be between 1 and {}",
                    self.time_signature.num
                ),
            ));
        }

        if pos.tick >= self.ticks_per_beat {
            return Err(ContentError::invariant(
                "lesson.position_tick_in_beat",
                format!("{field}.tick must be less than {}", self.ticks_per_beat),
            ));
        }

        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TimeSignature {
    pub num: u8,
    pub den: u8,
}

#[derive(Debug, Clone, Copy, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TempoEntry {
    pub pos: MusicalPos,
    pub bpm: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MusicalPos {
    pub bar: u32,
    pub beat: u8,
    pub tick: u16,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TimeRange {
    pub start: MusicalPos,
    pub end: MusicalPos,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Lane {
    pub lane_id: String,
    pub events: Vec<Event>,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Event {
    pub event_id: String,
    pub pos: MusicalPos,
    pub duration_ticks: u16,
    pub payload: EventPayload,
}

impl Event {
    fn validate(&self) -> Result<(), ContentError> {
        self.payload.validate()?;

        if matches!(self.payload, EventPayload::Hit { .. }) && self.duration_ticks != 0 {
            return Err(ContentError::invariant(
                "lesson.hit_duration_zero",
                format!(
                    "hit event '{}' must have duration_ticks set to 0",
                    self.event_id
                ),
            ));
        }

        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(tag = "type", rename_all = "snake_case", deny_unknown_fields)]
pub enum EventPayload {
    Hit { velocity: u8, articulation: String },
    Note { pitch: u8, velocity: u8 },
}

impl EventPayload {
    fn validate(&self) -> Result<(), ContentError> {
        match self {
            Self::Hit { velocity, .. } => validate_midi_velocity(*velocity, "hit.velocity"),
            Self::Note { pitch, velocity } => {
                if *pitch > 127 {
                    return Err(ContentError::invariant(
                        "lesson.note_pitch_midi_range",
                        "note pitch must be in MIDI range 0..=127",
                    ));
                }
                validate_midi_velocity(*velocity, "note.velocity")
            }
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Section {
    pub section_id: String,
    pub label: String,
    pub range: TimeRange,
    pub loopable: bool,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PracticeDefaults {
    pub modes_supported: Vec<PracticeMode>,
    pub count_in_bars: u8,
    pub metronome_enabled: bool,
    pub start_tempo_bpm: f32,
    pub tempo_floor_bpm: Option<f32>,
}

impl PracticeDefaults {
    fn validate(&self) -> Result<(), ContentError> {
        if self.start_tempo_bpm <= 0.0 {
            return Err(ContentError::invariant(
                "lesson.start_tempo_positive",
                "practice.start_tempo_bpm must be greater than 0",
            ));
        }

        if matches!(self.tempo_floor_bpm, Some(value) if value <= 0.0) {
            return Err(ContentError::invariant(
                "lesson.tempo_floor_positive",
                "practice.tempo_floor_bpm must be greater than 0 when present",
            ));
        }

        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PracticeMode {
    Practice,
    Play,
    CourseGate,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LessonMeta {
    pub difficulty: Option<String>,
    pub tags: Vec<String>,
    pub skills: Vec<String>,
    pub objectives: Vec<String>,
    pub prerequisites: Vec<String>,
    pub estimated_minutes: Option<u16>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AssetRefs {
    pub backing: Option<String>,
    pub artwork: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ContentRefs {}

pub fn load_lesson(json: &str) -> Result<Lesson, ContentError> {
    let lesson = parse_json::<Lesson>("Lesson", json)?;
    lesson.validate()?;
    Ok(lesson)
}

fn validate_midi_velocity(velocity: u8, field: &str) -> Result<(), ContentError> {
    if !(1..=127).contains(&velocity) {
        return Err(ContentError::invariant(
            "lesson.velocity_midi_range",
            format!("{field} must be in MIDI range 1..=127"),
        ));
    }

    Ok(())
}

fn deserialize_optional_json_object<'de, D>(
    deserializer: D,
) -> Result<Option<PublisherRef>, D::Error>
where
    D: Deserializer<'de>,
{
    let value = Value::deserialize(deserializer)?;
    match value {
        Value::Object(map) => Ok(Some(map)),
        _ => Err(de::Error::custom("publisher must be a JSON object")),
    }
}
