use std::collections::HashSet;

use serde::Deserialize;

use super::{ensure_schema_version, parse_json, ContentError};

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct InstrumentLayout {
    pub id: String,
    pub schema_version: String,
    pub family: String,
    pub variant: String,
    pub lanes: Vec<LaneDefinition>,
    pub visual: VisualConfig,
}

impl InstrumentLayout {
    pub fn validate(&self) -> Result<(), ContentError> {
        ensure_schema_version(&self.schema_version)?;

        let mut lane_ids = HashSet::new();
        for lane in &self.lanes {
            if !lane_ids.insert(lane.lane_id.as_str()) {
                return Err(ContentError::invariant(
                    "layout.lane_id_unique",
                    format!("duplicate lane_id '{}'", lane.lane_id),
                ));
            }

            lane.validate()?;
        }

        let mut slot_ids = HashSet::new();
        let mut visual_lane_ids = HashSet::new();
        for slot in &self.visual.lane_slots {
            if !lane_ids.contains(slot.lane_id.as_str()) {
                return Err(ContentError::invariant(
                    "layout.visual_lane_references_defined_lane",
                    format!(
                        "visual slot '{}' references unknown lane_id '{}'",
                        slot.slot_id, slot.lane_id
                    ),
                ));
            }

            if !visual_lane_ids.insert(slot.lane_id.as_str()) {
                return Err(ContentError::invariant(
                    "layout.visual_lane_exactly_once",
                    format!(
                        "lane_id '{}' appears more than once in visual.lane_slots",
                        slot.lane_id
                    ),
                ));
            }

            if !slot_ids.insert(slot.slot_id.as_str()) {
                return Err(ContentError::invariant(
                    "layout.slot_id_unique",
                    format!("duplicate slot_id '{}'", slot.slot_id),
                ));
            }
        }

        for lane_id in lane_ids {
            if !visual_lane_ids.contains(lane_id) {
                return Err(ContentError::invariant(
                    "layout.every_lane_has_visual_slot",
                    format!("lane_id '{lane_id}' is missing from visual.lane_slots"),
                ));
            }
        }

        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LaneDefinition {
    pub lane_id: String,
    pub label: String,
    pub midi_hints: Vec<MidiHint>,
    pub articulations: Option<Vec<ArticulationDef>>,
}

impl LaneDefinition {
    fn validate(&self) -> Result<(), ContentError> {
        for hint in &self.midi_hints {
            hint.validate()?;
        }

        if let Some(articulations) = &self.articulations {
            let mut articulation_ids = HashSet::new();
            for articulation in articulations {
                if !articulation_ids.insert(articulation.id.as_str()) {
                    return Err(ContentError::invariant(
                        "layout.articulation_id_unique",
                        format!(
                            "duplicate articulation id '{}' in lane '{}'",
                            articulation.id, self.lane_id
                        ),
                    ));
                }

                if articulation.midi_note > 127 {
                    return Err(ContentError::invariant(
                        "layout.articulation_midi_note_range",
                        format!(
                            "articulation '{}' in lane '{}' has midi_note outside 0..=127",
                            articulation.id, self.lane_id
                        ),
                    ));
                }
            }
        }

        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MidiHint {
    pub hint_type: String,
    pub values: Vec<u8>,
}

impl MidiHint {
    fn validate(&self) -> Result<(), ContentError> {
        if self.hint_type != "note" && self.hint_type != "cc" {
            return Err(ContentError::invariant(
                "layout.midi_hint_type",
                format!("unsupported midi hint_type '{}'", self.hint_type),
            ));
        }

        if self.values.iter().any(|value| *value > 127) {
            return Err(ContentError::invariant(
                "layout.midi_hint_value_range",
                "midi hint values must be in MIDI range 0..=127",
            ));
        }

        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ArticulationDef {
    pub id: String,
    pub label: String,
    pub midi_note: u8,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct VisualConfig {
    pub lane_slots: Vec<VisualSlot>,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct VisualSlot {
    pub lane_id: String,
    pub slot_id: String,
}

pub fn load_layout(json: &str) -> Result<InstrumentLayout, ContentError> {
    let layout = parse_json::<InstrumentLayout>("InstrumentLayout", json)?;
    layout.validate()?;
    Ok(layout)
}
