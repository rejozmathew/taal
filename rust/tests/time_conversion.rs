use taal_core::time::{MusicalPos, TempoEntry, TimeError, TimeSignature, TimingIndex};

const FOUR_FOUR: TimeSignature = TimeSignature { num: 4, den: 4 };
const TICKS_PER_BEAT: u16 = 480;

#[test]
fn constant_120_bpm_converts_positions_to_ms() {
    let index = constant_120_index();

    assert_ms(index.pos_to_ms(pos(1, 1, 0)).unwrap(), 0.0);
    assert_ms(index.pos_to_ms(pos(1, 2, 0)).unwrap(), 500.0);
    assert_ms(index.pos_to_ms(pos(2, 1, 0)).unwrap(), 2000.0);
}

#[test]
fn constant_120_bpm_preserves_subdivision_accuracy() {
    let index = constant_120_index();

    assert_ms(index.pos_to_ms(pos(1, 1, 1)).unwrap(), 500.0 / 480.0);
    assert_ms(index.pos_to_ms(pos(1, 1, 240)).unwrap(), 250.0);
}

#[test]
fn musical_position_arithmetic_crosses_beat_and_bar_boundaries() {
    assert_eq!(
        pos(1, 1, 0)
            .checked_add_ticks(480, FOUR_FOUR, TICKS_PER_BEAT)
            .unwrap(),
        pos(1, 2, 0)
    );
    assert_eq!(
        pos(1, 4, 479)
            .checked_add_ticks(1, FOUR_FOUR, TICKS_PER_BEAT)
            .unwrap(),
        pos(2, 1, 0)
    );
    assert_eq!(
        pos(2, 1, 0)
            .checked_sub_ticks(1, FOUR_FOUR, TICKS_PER_BEAT)
            .unwrap(),
        pos(1, 4, 479)
    );
    assert_eq!(
        pos(1, 1, 0)
            .ticks_until(pos(2, 1, 0), FOUR_FOUR, TICKS_PER_BEAT)
            .unwrap(),
        1920
    );
}

#[test]
fn pos_to_ms_to_pos_round_trips_grid_aligned_positions() {
    let index = constant_120_index();

    for position in [
        pos(1, 1, 0),
        pos(1, 1, 240),
        pos(1, 4, 479),
        pos(2, 1, 0),
        pos(3, 3, 120),
    ] {
        let ms = index.pos_to_ms(position).unwrap();
        assert_eq!(index.ms_to_pos(ms).unwrap(), position);
    }
}

#[test]
fn multi_tempo_map_converts_at_and_between_tempo_changes() {
    let index = TimingIndex::from_tempo_map(
        FOUR_FOUR,
        TICKS_PER_BEAT,
        &[
            TempoEntry {
                pos: pos(1, 1, 0),
                bpm: 120.0,
            },
            TempoEntry {
                pos: pos(2, 1, 0),
                bpm: 60.0,
            },
        ],
    )
    .unwrap();

    assert_eq!(index.tempo_count(), 2);
    assert_ms(index.pos_to_ms(pos(2, 1, 0)).unwrap(), 2000.0);
    assert_ms(index.pos_to_ms(pos(2, 2, 0)).unwrap(), 3000.0);
    assert_eq!(index.ms_to_pos(2500.0).unwrap(), pos(2, 1, 240));
}

#[test]
fn invalid_tempo_map_without_origin_returns_clear_error() {
    let error = TimingIndex::from_tempo_map(
        FOUR_FOUR,
        TICKS_PER_BEAT,
        &[TempoEntry {
            pos: pos(2, 1, 0),
            bpm: 120.0,
        }],
    )
    .unwrap_err();

    match error {
        TimeError::InvalidTempoMap(message) => {
            assert!(message.contains("bar 1, beat 1, tick 0"));
        }
        other => panic!("expected InvalidTempoMap, got {other:?}"),
    }
}

fn constant_120_index() -> TimingIndex {
    TimingIndex::from_tempo_map(
        FOUR_FOUR,
        TICKS_PER_BEAT,
        &[TempoEntry {
            pos: pos(1, 1, 0),
            bpm: 120.0,
        }],
    )
    .unwrap()
}

fn pos(bar: u32, beat: u8, tick: u16) -> MusicalPos {
    MusicalPos::new(bar, beat, tick)
}

fn assert_ms(actual: f64, expected: f64) {
    assert!(
        (actual - expected).abs() < 0.000_001,
        "expected {expected}ms, got {actual}ms"
    );
}
