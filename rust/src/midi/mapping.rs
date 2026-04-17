use std::error::Error;
use std::fmt::{self, Display};

use serde::Deserialize;
use uuid::Uuid;

pub type DateTime = String;

const MIDI_NOTE_COUNT: usize = 128;
const DEFAULT_DEDUPE_WINDOW_MS: f32 = 8.0;
const DEFAULT_MIN_VELOCITY: u8 = 1;
const DEFAULT_MAX_VELOCITY: u8 = 127;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum RawMidiEventType {
    NoteOn,
    NoteOff,
    ControlChange,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RawMidiEvent {
    pub event_type: RawMidiEventType,
    pub channel: u8,
    pub data1: u8,
    pub data2: u8,
    pub timestamp_ns: i128,
}

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DeviceProfile {
    pub id: Uuid,
    pub name: String,
    pub instrument_family: String,
    pub layout_id: String,
    pub device_fingerprint: DeviceFingerprint,
    pub transport: MidiTransport,
    pub midi_channel: Option<u8>,
    pub note_map: Vec<NoteMapping>,
    pub hihat_model: Option<HiHatModel>,
    pub input_offset_ms: f32,
    #[serde(default = "default_dedupe_window_ms")]
    pub dedupe_window_ms: f32,
    pub velocity_curve: VelocityCurve,
    pub preset_origin: Option<String>,
    pub created_at: DateTime,
    pub updated_at: DateTime,
}

impl DeviceProfile {
    pub fn validate(&self) -> Result<(), MidiMappingError> {
        if matches!(self.midi_channel, Some(channel) if channel > 15) {
            return Err(MidiMappingError::profile(
                "midi_channel",
                "midi_channel must be in MIDI channel range 0..=15",
            ));
        }

        if !self.input_offset_ms.is_finite() {
            return Err(MidiMappingError::profile(
                "input_offset_ms",
                "input_offset_ms must be finite",
            ));
        }

        if !self.dedupe_window_ms.is_finite() || self.dedupe_window_ms < 0.0 {
            return Err(MidiMappingError::profile(
                "dedupe_window_ms",
                "dedupe_window_ms must be finite and non-negative",
            ));
        }

        for mapping in &self.note_map {
            mapping.validate()?;
        }

        if let Some(hihat_model) = &self.hihat_model {
            hihat_model.validate()?;
        }

        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DeviceFingerprint {
    pub vendor_name: Option<String>,
    pub model_name: Option<String>,
    pub platform_id: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum MidiTransport {
    Usb,
    Bluetooth,
    Virtual,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VelocityCurve {
    Linear,
    Soft,
    Hard,
    Custom(Vec<(u8, u8)>),
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct NoteMapping {
    pub midi_note: u8,
    pub lane_id: String,
    pub articulation: String,
    #[serde(default = "default_min_velocity")]
    pub min_velocity: u8,
    #[serde(default = "default_max_velocity")]
    pub max_velocity: u8,
}

impl NoteMapping {
    fn validate(&self) -> Result<(), MidiMappingError> {
        if self.min_velocity > self.max_velocity {
            return Err(MidiMappingError::profile(
                "note_map.min_velocity",
                format!(
                    "mapping for note {} has min_velocity greater than max_velocity",
                    self.midi_note
                ),
            ));
        }

        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HiHatModel {
    pub source_cc: u8,
    pub invert: bool,
    pub thresholds: Vec<HiHatThreshold>,
    pub auto_articulation_notes: Vec<u8>,
}

impl HiHatModel {
    fn validate(&self) -> Result<(), MidiMappingError> {
        if self.thresholds.is_empty() {
            return Err(MidiMappingError::profile(
                "hihat_model.thresholds",
                "hihat_model.thresholds must contain at least one threshold",
            ));
        }

        let mut previous_max = None;
        for threshold in &self.thresholds {
            if let Some(previous_max) = previous_max {
                if threshold.max_cc_value <= previous_max {
                    return Err(MidiMappingError::profile(
                        "hihat_model.thresholds",
                        "hihat_model.thresholds must be ordered by increasing max_cc_value",
                    ));
                }
            }
            previous_max = Some(threshold.max_cc_value);
        }

        Ok(())
    }

    fn resolve_state(&self, cc_value: u8) -> &str {
        let adjusted = if self.invert {
            DEFAULT_MAX_VELOCITY - cc_value
        } else {
            cc_value
        };

        self.thresholds
            .iter()
            .find(|threshold| adjusted <= threshold.max_cc_value)
            .or_else(|| self.thresholds.last())
            .expect("HiHatModel validation requires non-empty thresholds")
            .state
            .as_str()
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HiHatThreshold {
    pub max_cc_value: u8,
    pub state: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MappedHit {
    pub lane_id: String,
    pub velocity: u8,
    pub articulation: String,
    pub timestamp_ns: i128,
    pub raw_note: u8,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MappingResult {
    Hit(MappedHit),
    Unmapped {
        note: u8,
        velocity: u8,
        timestamp_ns: i128,
    },
    Suppressed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum MidiMappingError {
    InvalidJson(String),
    ProfileViolation { field: String, message: String },
}

impl MidiMappingError {
    fn profile(field: impl Into<String>, message: impl Into<String>) -> Self {
        Self::ProfileViolation {
            field: field.into(),
            message: message.into(),
        }
    }
}

impl Display for MidiMappingError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidJson(message) => write!(f, "invalid device profile JSON: {message}"),
            Self::ProfileViolation { field, message } => {
                write!(f, "device profile violation at {field}: {message}")
            }
        }
    }
}

impl Error for MidiMappingError {}

#[derive(Debug)]
pub struct MidiMapper {
    profile: DeviceProfile,
    hihat_cc_value: u8,
    hihat_auto_notes: [bool; MIDI_NOTE_COUNT],
    last_note_on: [Option<LastNoteOn>; MIDI_NOTE_COUNT],
    input_offset_ns: i128,
    dedupe_window_ns: i128,
}

impl MidiMapper {
    pub fn new(profile: DeviceProfile) -> Result<Self, MidiMappingError> {
        profile.validate()?;

        let mut hihat_auto_notes = [false; MIDI_NOTE_COUNT];
        if let Some(hihat_model) = &profile.hihat_model {
            for note in &hihat_model.auto_articulation_notes {
                hihat_auto_notes[usize::from(*note)] = true;
            }
        }

        Ok(Self {
            input_offset_ns: milliseconds_to_nanoseconds(profile.input_offset_ms),
            dedupe_window_ns: milliseconds_to_nanoseconds(profile.dedupe_window_ms),
            profile,
            hihat_cc_value: 0,
            hihat_auto_notes,
            last_note_on: [None; MIDI_NOTE_COUNT],
        })
    }

    pub fn profile(&self) -> &DeviceProfile {
        &self.profile
    }

    pub fn hihat_cc_value(&self) -> u8 {
        self.hihat_cc_value
    }

    pub fn process_event(&mut self, event: RawMidiEvent) -> Option<MappingResult> {
        if !self.channel_matches(event.channel) {
            return None;
        }

        match event.event_type {
            RawMidiEventType::ControlChange => {
                self.process_control_change(event);
                None
            }
            RawMidiEventType::NoteOn if event.data2 > 0 => Some(self.process_note_on(event)),
            RawMidiEventType::NoteOn | RawMidiEventType::NoteOff => None,
        }
    }

    fn channel_matches(&self, channel: u8) -> bool {
        channel <= 15
            && self
                .profile
                .midi_channel
                .is_none_or(|expected| expected == channel)
    }

    fn process_control_change(&mut self, event: RawMidiEvent) {
        if self
            .profile
            .hihat_model
            .as_ref()
            .is_some_and(|model| model.source_cc == event.data1)
        {
            self.hihat_cc_value = event.data2.min(DEFAULT_MAX_VELOCITY);
        }
    }

    fn process_note_on(&mut self, event: RawMidiEvent) -> MappingResult {
        let effective_timestamp_ns = self.effective_timestamp_ns(event.timestamp_ns);

        if self.should_suppress(event.data1, event.data2, event.timestamp_ns) {
            return MappingResult::Suppressed;
        }
        self.record_note_on(event.data1, event.data2, event.timestamp_ns);

        let Some(mapping) = self.resolve_note_mapping(event.data1, event.data2) else {
            return MappingResult::Unmapped {
                note: event.data1,
                velocity: event.data2,
                timestamp_ns: effective_timestamp_ns,
            };
        };

        MappingResult::Hit(MappedHit {
            lane_id: mapping.lane_id.clone(),
            velocity: event.data2,
            articulation: self.resolve_articulation(event.data1, &mapping.articulation),
            timestamp_ns: effective_timestamp_ns,
            raw_note: event.data1,
        })
    }

    fn resolve_note_mapping(&self, midi_note: u8, velocity: u8) -> Option<&NoteMapping> {
        self.profile.note_map.iter().find(|mapping| {
            mapping.midi_note == midi_note
                && velocity >= mapping.min_velocity
                && velocity <= mapping.max_velocity
        })
    }

    fn resolve_articulation(&self, midi_note: u8, mapped_articulation: &str) -> String {
        if !self.hihat_auto_notes[usize::from(midi_note)] {
            return mapped_articulation.to_owned();
        }

        self.profile
            .hihat_model
            .as_ref()
            .map(|model| model.resolve_state(self.hihat_cc_value).to_owned())
            .unwrap_or_else(|| mapped_articulation.to_owned())
    }

    fn should_suppress(&self, midi_note: u8, velocity: u8, timestamp_ns: i128) -> bool {
        let Some(previous) = self.last_note_on[usize::from(midi_note)] else {
            return false;
        };

        let delta_ns = timestamp_ns - previous.timestamp_ns;
        delta_ns >= 0
            && delta_ns <= self.dedupe_window_ns
            && velocity.abs_diff(previous.velocity) <= 10
    }

    fn record_note_on(&mut self, midi_note: u8, velocity: u8, timestamp_ns: i128) {
        self.last_note_on[usize::from(midi_note)] = Some(LastNoteOn {
            timestamp_ns,
            velocity,
        });
    }

    fn effective_timestamp_ns(&self, timestamp_ns: i128) -> i128 {
        timestamp_ns - self.input_offset_ns
    }
}

#[derive(Debug, Clone, Copy)]
struct LastNoteOn {
    timestamp_ns: i128,
    velocity: u8,
}

pub fn load_device_profile(json: &str) -> Result<DeviceProfile, MidiMappingError> {
    let value = serde_json::from_str::<serde_json::Value>(json)
        .map_err(|err| MidiMappingError::InvalidJson(err.to_string()))?;

    let profile = serde_json::from_value::<DeviceProfile>(value).map_err(|err| {
        MidiMappingError::profile("$", format!("DeviceProfile schema violation: {err}"))
    })?;
    profile.validate()?;
    Ok(profile)
}

fn milliseconds_to_nanoseconds(value_ms: f32) -> i128 {
    (f64::from(value_ms) * 1_000_000.0).round() as i128
}

fn default_dedupe_window_ms() -> f32 {
    DEFAULT_DEDUPE_WINDOW_MS
}

fn default_min_velocity() -> u8 {
    DEFAULT_MIN_VELOCITY
}

fn default_max_velocity() -> u8 {
    DEFAULT_MAX_VELOCITY
}
