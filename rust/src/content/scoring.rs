use serde::Deserialize;

use super::{ensure_schema_version, parse_json, ContentError};

#[derive(Debug, Clone, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScoringProfile {
    pub id: String,
    pub schema_version: String,
    pub timing_windows_ms: TimingWindows,
    pub grading: GradeWeights,
    pub combo: ComboConfig,
    pub rules: ScoringRules,
}

impl ScoringProfile {
    pub fn validate(&self) -> Result<(), ContentError> {
        ensure_schema_version(&self.schema_version)?;
        self.timing_windows_ms.validate()?;
        self.combo.validate()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct TimingWindows {
    pub perfect_ms: f32,
    pub good_ms: f32,
    pub outer_ms: f32,
}

impl TimingWindows {
    fn validate(&self) -> Result<(), ContentError> {
        if !(self.perfect_ms > 0.0
            && self.perfect_ms <= self.good_ms
            && self.good_ms <= self.outer_ms)
        {
            return Err(ContentError::invariant(
                "scoring.timing_windows_order",
                "timing windows must satisfy 0 < perfect_ms <= good_ms <= outer_ms",
            ));
        }

        Ok(())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GradeWeights {
    pub perfect: f32,
    pub good: f32,
    pub early: f32,
    pub late: f32,
    pub miss: f32,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ComboConfig {
    pub encouragement_milestones: Vec<u32>,
}

impl ComboConfig {
    fn validate(&self) -> Result<(), ContentError> {
        let mut previous = None;
        for milestone in &self.encouragement_milestones {
            if *milestone == 0 {
                return Err(ContentError::invariant(
                    "scoring.combo_milestones_positive",
                    "encouragement milestones must be positive integers",
                ));
            }

            if matches!(previous, Some(previous) if *milestone <= previous) {
                return Err(ContentError::invariant(
                    "scoring.combo_milestones_strictly_increasing",
                    "encouragement milestones must be strictly increasing",
                ));
            }

            previous = Some(*milestone);
        }

        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ScoringRules {}

pub fn load_scoring_profile(json: &str) -> Result<ScoringProfile, ContentError> {
    let profile = parse_json::<ScoringProfile>("ScoringProfile", json)?;
    profile.validate()?;
    Ok(profile)
}
