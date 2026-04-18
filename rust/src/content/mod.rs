pub mod compatibility;
pub mod compile;
pub mod error;
pub mod layout;
pub mod lesson;
pub mod scoring;

use serde::de::DeserializeOwned;

pub use compatibility::{
    compiled_lesson_for_scoring, evaluate_layout_compatibility, mapped_lanes_from_device_profile,
    LayoutCompatibility, LayoutCompatibilityStatus,
};
pub use compile::{compile_lesson, CompileError, CompiledEvent, CompiledLesson, CompiledSection};
pub use error::ContentError;
pub use layout::{
    load_layout, ArticulationDef, InstrumentLayout, LaneDefinition, MidiHint, VisualConfig,
    VisualSlot,
};
pub use lesson::{
    load_lesson, AssetRefs, ContentRefs, Event, EventPayload, InstrumentRef, Lane, Lesson,
    LessonMeta, MusicalPos, PracticeDefaults, PracticeMode, PublisherRef, Section, TempoEntry,
    TimeRange, TimeSignature, TimingConfig,
};
pub use scoring::{
    load_scoring_profile, ComboConfig, GradeWeights, ScoringProfile, ScoringRules, TimingWindows,
};

const SUPPORTED_SCHEMA_VERSION: &str = "1.0";

pub(crate) fn parse_json<T>(entity: &str, json: &str) -> Result<T, ContentError>
where
    T: DeserializeOwned,
{
    let value = serde_json::from_str::<serde_json::Value>(json)
        .map_err(|err| ContentError::InvalidJson(err.to_string()))?;

    serde_json::from_value(value)
        .map_err(|err| ContentError::schema("$", format!("{entity} schema violation: {err}")))
}

pub(crate) fn ensure_schema_version(found: &str) -> Result<(), ContentError> {
    if found == SUPPORTED_SCHEMA_VERSION {
        return Ok(());
    }

    Err(ContentError::UnsupportedSchemaVersion {
        found: found.to_owned(),
        supported: SUPPORTED_SCHEMA_VERSION.to_owned(),
    })
}
