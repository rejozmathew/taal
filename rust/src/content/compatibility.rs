use std::collections::HashSet;

use crate::midi::DeviceProfile;

use super::CompiledLesson;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LayoutCompatibilityStatus {
    Full,
    OptionalMissing,
    RequiredMissing,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LayoutCompatibility {
    pub status: LayoutCompatibilityStatus,
    pub lesson_lanes: Vec<String>,
    pub required_lanes: Vec<String>,
    pub optional_lanes: Vec<String>,
    pub mapped_lanes: Vec<String>,
    pub missing_required_lanes: Vec<String>,
    pub missing_optional_lanes: Vec<String>,
    pub excluded_lanes: Vec<String>,
}

impl LayoutCompatibility {
    pub fn full_for_lesson(compiled: &CompiledLesson) -> Self {
        let lesson_lanes = lesson_lanes(compiled);
        Self {
            status: LayoutCompatibilityStatus::Full,
            required_lanes: lesson_lanes.clone(),
            optional_lanes: Vec::new(),
            mapped_lanes: lesson_lanes.clone(),
            lesson_lanes,
            missing_required_lanes: Vec::new(),
            missing_optional_lanes: Vec::new(),
            excluded_lanes: Vec::new(),
        }
    }

    pub fn has_excluded_lanes(&self) -> bool {
        !self.excluded_lanes.is_empty()
    }
}

pub fn evaluate_layout_compatibility(
    compiled: &CompiledLesson,
    optional_lanes: &[String],
    mapped_lanes: &[String],
) -> LayoutCompatibility {
    let lesson_lanes = lesson_lanes(compiled);
    let lesson_set = lesson_lanes
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    let optional_set = optional_lanes
        .iter()
        .map(String::as_str)
        .filter(|lane_id| lesson_set.contains(*lane_id))
        .collect::<HashSet<_>>();
    let mapped_set = mapped_lanes
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();

    let optional_lanes = ordered_filter(&lesson_lanes, |lane_id| optional_set.contains(lane_id));
    let required_lanes = ordered_filter(&lesson_lanes, |lane_id| !optional_set.contains(lane_id));
    let missing_required_lanes =
        ordered_filter(&required_lanes, |lane_id| !mapped_set.contains(lane_id));
    let missing_optional_lanes =
        ordered_filter(&optional_lanes, |lane_id| !mapped_set.contains(lane_id));
    let mapped_lanes = ordered_unique(mapped_lanes);

    let mut excluded_lanes = missing_required_lanes.clone();
    excluded_lanes.extend(missing_optional_lanes.clone());

    let status = if !missing_required_lanes.is_empty() {
        LayoutCompatibilityStatus::RequiredMissing
    } else if !missing_optional_lanes.is_empty() {
        LayoutCompatibilityStatus::OptionalMissing
    } else {
        LayoutCompatibilityStatus::Full
    };

    LayoutCompatibility {
        status,
        lesson_lanes,
        required_lanes,
        optional_lanes,
        mapped_lanes,
        missing_required_lanes,
        missing_optional_lanes,
        excluded_lanes,
    }
}

pub fn mapped_lanes_from_device_profile(profile: Option<&DeviceProfile>) -> Vec<String> {
    let Some(profile) = profile else {
        return Vec::new();
    };
    ordered_unique(
        &profile
            .note_map
            .iter()
            .map(|mapping| mapping.lane_id.clone())
            .collect::<Vec<_>>(),
    )
}

pub fn compiled_lesson_for_scoring(
    compiled: &CompiledLesson,
    compatibility: &LayoutCompatibility,
) -> CompiledLesson {
    if !compatibility.has_excluded_lanes() {
        return compiled.clone();
    }

    let excluded = compatibility
        .excluded_lanes
        .iter()
        .map(String::as_str)
        .collect::<HashSet<_>>();
    let mut filtered = compiled.clone();
    filtered
        .events
        .retain(|event| !excluded.contains(event.lane_id.as_str()));
    filtered
        .lane_ids
        .retain(|lane_id| !excluded.contains(lane_id.as_str()));
    filtered
}

fn lesson_lanes(compiled: &CompiledLesson) -> Vec<String> {
    let event_lanes = compiled
        .events
        .iter()
        .map(|event| event.lane_id.as_str())
        .collect::<HashSet<_>>();
    ordered_filter(&compiled.lane_ids, |lane_id| event_lanes.contains(lane_id))
}

fn ordered_unique(values: &[String]) -> Vec<String> {
    let mut seen = HashSet::new();
    values
        .iter()
        .filter(|value| seen.insert(value.as_str()))
        .cloned()
        .collect()
}

fn ordered_filter(values: &[String], predicate: impl Fn(&str) -> bool) -> Vec<String> {
    values
        .iter()
        .filter(|value| predicate(value.as_str()))
        .cloned()
        .collect()
}
