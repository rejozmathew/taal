use taal_core::content::{load_layout, LaneDefinition};

const STANDARD_5PC_LAYOUT: &str = include_str!("../../assets/content/layouts/std-5pc-v1.json");

#[test]
fn bundled_standard_5pc_layout_validates() {
    let layout = load_layout(STANDARD_5PC_LAYOUT).expect("standard 5-piece layout should load");

    assert_eq!(layout.id, "std-5pc-v1");
    assert_eq!(layout.family, "drums");
    assert_eq!(layout.variant, "kit");

    let lane_ids: Vec<_> = layout
        .lanes
        .iter()
        .map(|lane| lane.lane_id.as_str())
        .collect();
    assert_eq!(
        lane_ids,
        vec![
            "kick",
            "snare",
            "hihat",
            "ride",
            "crash",
            "tom_high",
            "tom_low",
            "tom_floor",
        ]
    );
    assert_eq!(layout.visual.lane_slots.len(), layout.lanes.len());
}

#[test]
fn bundled_standard_5pc_layout_defines_required_articulations() {
    let layout = load_layout(STANDARD_5PC_LAYOUT).expect("standard 5-piece layout should load");
    let hihat = lane(&layout.lanes, "hihat");
    let articulations: Vec<_> = hihat
        .articulations
        .as_ref()
        .expect("hi-hat articulations should be present")
        .iter()
        .map(|articulation| articulation.id.as_str())
        .collect();

    assert_eq!(articulations, vec!["closed", "open", "pedal"]);
}

#[test]
fn bundled_standard_5pc_layout_contains_common_midi_hints() {
    let layout = load_layout(STANDARD_5PC_LAYOUT).expect("standard 5-piece layout should load");

    assert_notes(lane(&layout.lanes, "kick"), &[35, 36]);
    assert_notes(lane(&layout.lanes, "snare"), &[37, 38, 40]);
    assert_notes(lane(&layout.lanes, "hihat"), &[42, 44, 46]);
    assert_cc(lane(&layout.lanes, "hihat"), &[4]);
    assert_notes(lane(&layout.lanes, "ride"), &[51, 53, 59]);
    assert_notes(lane(&layout.lanes, "crash"), &[49, 55, 57]);
    assert_notes(lane(&layout.lanes, "tom_high"), &[48, 50]);
    assert_notes(lane(&layout.lanes, "tom_low"), &[45, 47]);
    assert_notes(lane(&layout.lanes, "tom_floor"), &[41, 43]);
}

fn lane<'a>(lanes: &'a [LaneDefinition], lane_id: &str) -> &'a LaneDefinition {
    lanes
        .iter()
        .find(|lane| lane.lane_id == lane_id)
        .unwrap_or_else(|| panic!("missing lane {lane_id}"))
}

fn assert_notes(lane: &LaneDefinition, expected: &[u8]) {
    let notes = hint_values(lane, "note");
    assert_eq!(notes, expected, "note hints for {}", lane.lane_id);
}

fn assert_cc(lane: &LaneDefinition, expected: &[u8]) {
    let values = hint_values(lane, "cc");
    assert_eq!(values, expected, "cc hints for {}", lane.lane_id);
}

fn hint_values<'a>(lane: &'a LaneDefinition, hint_type: &str) -> &'a [u8] {
    lane.midi_hints
        .iter()
        .find(|hint| hint.hint_type == hint_type)
        .map(|hint| hint.values.as_slice())
        .unwrap_or(&[])
}
