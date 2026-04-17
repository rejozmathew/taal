use taal_core::midi::{
    load_device_profile, DeviceFingerprint, DeviceProfile, HiHatModel, HiHatThreshold, MappedHit,
    MappingResult, MidiMapper, MidiTransport, NoteMapping, RawMidiEvent, RawMidiEventType,
    VelocityCurve,
};
use uuid::Uuid;

const T0_NS: i128 = 1_000_000_000;

#[test]
fn maps_note_to_lane() {
    let mut mapper = MidiMapper::new(base_profile()).unwrap();

    let result = mapper.process_event(note_on(38, 96, T0_NS));

    assert_eq!(
        result,
        Some(MappingResult::Hit(MappedHit {
            lane_id: "snare".to_owned(),
            velocity: 96,
            articulation: "normal".to_owned(),
            timestamp_ns: T0_NS,
            raw_note: 38,
        }))
    );
}

#[test]
fn unknown_note_returns_unmapped_warning_result() {
    let mut mapper = MidiMapper::new(base_profile()).unwrap();

    let result = mapper.process_event(note_on(99, 64, T0_NS));

    assert_eq!(
        result,
        Some(MappingResult::Unmapped {
            note: 99,
            velocity: 64,
            timestamp_ns: T0_NS,
        })
    );
}

#[test]
fn hihat_auto_articulation_uses_cc4_state() {
    let mut profile = base_profile();
    profile.note_map.push(NoteMapping {
        midi_note: 42,
        lane_id: "hihat".to_owned(),
        articulation: "closed".to_owned(),
        min_velocity: 1,
        max_velocity: 127,
    });
    profile.hihat_model = Some(HiHatModel {
        source_cc: 4,
        invert: false,
        thresholds: vec![
            HiHatThreshold {
                max_cc_value: 15,
                state: "closed".to_owned(),
            },
            HiHatThreshold {
                max_cc_value: 127,
                state: "open".to_owned(),
            },
        ],
        auto_articulation_notes: vec![42],
    });
    let mut mapper = MidiMapper::new(profile).unwrap();

    assert_eq!(mapper.process_event(cc(4, 10, T0_NS)), None);
    assert_hihat_articulation(&mut mapper, "closed", T0_NS + 1_000_000);

    assert_eq!(mapper.process_event(cc(4, 100, T0_NS + 2_000_000)), None);
    assert_hihat_articulation(&mut mapper, "open", T0_NS + 20_000_000);
}

#[test]
fn suppresses_duplicate_note_on_within_dedupe_window() {
    let mut mapper = MidiMapper::new(base_profile()).unwrap();

    assert!(matches!(
        mapper.process_event(note_on(38, 90, T0_NS)),
        Some(MappingResult::Hit(_))
    ));

    assert_eq!(
        mapper.process_event(note_on(38, 96, T0_NS + 7_000_000)),
        Some(MappingResult::Suppressed)
    );

    assert!(matches!(
        mapper.process_event(note_on(38, 110, T0_NS + 7_500_000)),
        Some(MappingResult::Hit(_))
    ));
}

#[test]
fn applies_input_offset_to_mapped_hits() {
    let mut profile = base_profile();
    profile.input_offset_ms = 12.5;
    let mut mapper = MidiMapper::new(profile).unwrap();

    let result = mapper.process_event(note_on(38, 96, T0_NS));

    match result {
        Some(MappingResult::Hit(hit)) => {
            assert_eq!(hit.timestamp_ns, T0_NS - 12_500_000);
        }
        other => panic!("expected mapped hit, got {other:?}"),
    }
}

#[test]
fn device_profile_loading_rejects_reserved_cc_map() {
    let json = r#"
{
  "id": "550e8400-e29b-41d4-a716-446655440031",
  "name": "Test Kit",
  "instrument_family": "drums",
  "layout_id": "std-5pc-v1",
  "device_fingerprint": {
    "vendor_name": "Test",
    "model_name": "Kit",
    "platform_id": null
  },
  "transport": "usb",
  "midi_channel": null,
  "note_map": [
    { "midi_note": 38, "lane_id": "snare", "articulation": "normal" }
  ],
  "hihat_model": null,
  "input_offset_ms": 0.0,
  "dedupe_window_ms": 8.0,
  "velocity_curve": "linear",
  "cc_map": [],
  "preset_origin": "test",
  "created_at": "2026-04-16T12:34:56Z",
  "updated_at": "2026-04-16T12:34:56Z"
}
"#;

    let error = load_device_profile(json).unwrap_err();

    assert!(
        error.to_string().contains("cc_map"),
        "expected cc_map rejection, got {error}"
    );
}

fn assert_hihat_articulation(mapper: &mut MidiMapper, expected: &str, timestamp_ns: i128) {
    match mapper.process_event(note_on(42, 80, timestamp_ns)) {
        Some(MappingResult::Hit(hit)) => {
            assert_eq!(hit.lane_id, "hihat");
            assert_eq!(hit.articulation, expected);
        }
        other => panic!("expected hi-hat hit, got {other:?}"),
    }
}

fn base_profile() -> DeviceProfile {
    DeviceProfile {
        id: Uuid::nil(),
        name: "Test Kit".to_owned(),
        instrument_family: "drums".to_owned(),
        layout_id: "std-5pc-v1".to_owned(),
        device_fingerprint: DeviceFingerprint {
            vendor_name: Some("Test".to_owned()),
            model_name: Some("Kit".to_owned()),
            platform_id: None,
        },
        transport: MidiTransport::Usb,
        midi_channel: None,
        note_map: vec![NoteMapping {
            midi_note: 38,
            lane_id: "snare".to_owned(),
            articulation: "normal".to_owned(),
            min_velocity: 1,
            max_velocity: 127,
        }],
        hihat_model: None,
        input_offset_ms: 0.0,
        dedupe_window_ms: 8.0,
        velocity_curve: VelocityCurve::Linear,
        preset_origin: Some("test".to_owned()),
        created_at: "2026-04-16T12:34:56Z".to_owned(),
        updated_at: "2026-04-16T12:34:56Z".to_owned(),
    }
}

fn note_on(note: u8, velocity: u8, timestamp_ns: i128) -> RawMidiEvent {
    RawMidiEvent {
        event_type: RawMidiEventType::NoteOn,
        channel: 9,
        data1: note,
        data2: velocity,
        timestamp_ns,
    }
}

fn cc(controller: u8, value: u8, timestamp_ns: i128) -> RawMidiEvent {
    RawMidiEvent {
        event_type: RawMidiEventType::ControlChange,
        channel: 9,
        data1: controller,
        data2: value,
        timestamp_ns,
    }
}
