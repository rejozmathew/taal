use std::error::Error;
use std::fmt::{self, Display};

pub use crate::content::{MusicalPos, TempoEntry, TimeSignature, TimingConfig};

const TIMELINE_ORIGIN: MusicalPos = MusicalPos {
    bar: 1,
    beat: 1,
    tick: 0,
};

#[derive(Debug, Clone, PartialEq)]
pub enum TimeError {
    InvalidTimeSignature { num: u8, den: u8 },
    InvalidTicksPerBeat { ticks_per_beat: u16 },
    InvalidPosition { pos: MusicalPos, message: String },
    InvalidTempoMap(String),
    NegativeMilliseconds { ms: f64 },
    PositionOverflow,
}

impl Display for TimeError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidTimeSignature { num, den } => {
                write!(f, "invalid time signature {num}/{den}")
            }
            Self::InvalidTicksPerBeat { ticks_per_beat } => {
                write!(
                    f,
                    "ticks_per_beat must be greater than 0, got {ticks_per_beat}"
                )
            }
            Self::InvalidPosition { pos, message } => {
                write!(
                    f,
                    "invalid musical position bar {}, beat {}, tick {}: {message}",
                    pos.bar, pos.beat, pos.tick
                )
            }
            Self::InvalidTempoMap(message) => write!(f, "invalid tempo map: {message}"),
            Self::NegativeMilliseconds { ms } => {
                write!(f, "milliseconds must be non-negative, got {ms}")
            }
            Self::PositionOverflow => write!(f, "musical position arithmetic overflowed"),
        }
    }
}

impl Error for TimeError {}

impl MusicalPos {
    pub const fn new(bar: u32, beat: u8, tick: u16) -> Self {
        Self { bar, beat, tick }
    }

    pub fn to_absolute_ticks(
        self,
        time_signature: TimeSignature,
        ticks_per_beat: u16,
    ) -> Result<i64, TimeError> {
        validate_position(self, time_signature, ticks_per_beat)?;

        let beats_per_bar = i64::from(time_signature.num);
        let ticks_per_beat = i64::from(ticks_per_beat);
        let completed_bars = i64::from(self.bar - 1);
        let completed_beats_in_bar = i64::from(self.beat - 1);
        let tick = i64::from(self.tick);

        let ticks_per_bar = beats_per_bar
            .checked_mul(ticks_per_beat)
            .ok_or(TimeError::PositionOverflow)?;
        let bar_ticks = completed_bars
            .checked_mul(ticks_per_bar)
            .ok_or(TimeError::PositionOverflow)?;
        let beat_ticks = completed_beats_in_bar
            .checked_mul(ticks_per_beat)
            .ok_or(TimeError::PositionOverflow)?;

        bar_ticks
            .checked_add(beat_ticks)
            .and_then(|value| value.checked_add(tick))
            .ok_or(TimeError::PositionOverflow)
    }

    pub fn from_absolute_ticks(
        absolute_ticks: i64,
        time_signature: TimeSignature,
        ticks_per_beat: u16,
    ) -> Result<Self, TimeError> {
        validate_timing_inputs(time_signature, ticks_per_beat)?;

        if absolute_ticks < 0 {
            return Err(TimeError::InvalidPosition {
                pos: TIMELINE_ORIGIN,
                message: format!("absolute tick offset must be non-negative, got {absolute_ticks}"),
            });
        }

        let beats_per_bar = i64::from(time_signature.num);
        let ticks_per_beat_i64 = i64::from(ticks_per_beat);
        let ticks_per_bar = beats_per_bar
            .checked_mul(ticks_per_beat_i64)
            .ok_or(TimeError::PositionOverflow)?;

        let completed_bars = absolute_ticks / ticks_per_bar;
        let ticks_into_bar = absolute_ticks % ticks_per_bar;
        let completed_beats = ticks_into_bar / ticks_per_beat_i64;
        let tick = ticks_into_bar % ticks_per_beat_i64;

        let bar = u32::try_from(completed_bars + 1).map_err(|_| TimeError::PositionOverflow)?;
        let beat = u8::try_from(completed_beats + 1).map_err(|_| TimeError::PositionOverflow)?;
        let tick = u16::try_from(tick).map_err(|_| TimeError::PositionOverflow)?;

        Ok(Self { bar, beat, tick })
    }

    pub fn checked_add_ticks(
        self,
        delta_ticks: i64,
        time_signature: TimeSignature,
        ticks_per_beat: u16,
    ) -> Result<Self, TimeError> {
        let absolute_ticks = self.to_absolute_ticks(time_signature, ticks_per_beat)?;
        let target_ticks = absolute_ticks
            .checked_add(delta_ticks)
            .ok_or(TimeError::PositionOverflow)?;

        Self::from_absolute_ticks(target_ticks, time_signature, ticks_per_beat)
    }

    pub fn checked_sub_ticks(
        self,
        delta_ticks: i64,
        time_signature: TimeSignature,
        ticks_per_beat: u16,
    ) -> Result<Self, TimeError> {
        let absolute_ticks = self.to_absolute_ticks(time_signature, ticks_per_beat)?;
        let target_ticks = absolute_ticks
            .checked_sub(delta_ticks)
            .ok_or(TimeError::PositionOverflow)?;

        Self::from_absolute_ticks(target_ticks, time_signature, ticks_per_beat)
    }

    pub fn ticks_until(
        self,
        other: Self,
        time_signature: TimeSignature,
        ticks_per_beat: u16,
    ) -> Result<i64, TimeError> {
        let start_ticks = self.to_absolute_ticks(time_signature, ticks_per_beat)?;
        let end_ticks = other.to_absolute_ticks(time_signature, ticks_per_beat)?;

        end_ticks
            .checked_sub(start_ticks)
            .ok_or(TimeError::PositionOverflow)
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct TimingIndex {
    time_signature: TimeSignature,
    ticks_per_beat: u16,
    segments: Vec<TimingSegment>,
}

#[derive(Debug, Clone, PartialEq)]
struct TimingSegment {
    start_pos: MusicalPos,
    start_tick: i64,
    start_ms: f64,
    bpm: f32,
    ms_per_tick: f64,
}

impl TimingIndex {
    pub fn from_timing_config(config: &TimingConfig) -> Result<Self, TimeError> {
        Self::from_tempo_map(
            config.time_signature,
            config.ticks_per_beat,
            &config.tempo_map,
        )
    }

    pub fn from_tempo_map(
        time_signature: TimeSignature,
        ticks_per_beat: u16,
        tempo_map: &[TempoEntry],
    ) -> Result<Self, TimeError> {
        validate_timing_inputs(time_signature, ticks_per_beat)?;

        if tempo_map.is_empty() {
            return Err(TimeError::InvalidTempoMap(
                "tempo_map must contain at least one entry".to_owned(),
            ));
        }

        if tempo_map[0].pos != TIMELINE_ORIGIN {
            return Err(TimeError::InvalidTempoMap(
                "tempo_map must start at bar 1, beat 1, tick 0".to_owned(),
            ));
        }

        let mut segments: Vec<TimingSegment> = Vec::with_capacity(tempo_map.len());

        for entry in tempo_map {
            validate_position(entry.pos, time_signature, ticks_per_beat)?;

            if !entry.bpm.is_finite() || entry.bpm <= 0.0 {
                return Err(TimeError::InvalidTempoMap(
                    "tempo_map bpm values must be finite and greater than 0".to_owned(),
                ));
            }

            let start_tick = entry
                .pos
                .to_absolute_ticks(time_signature, ticks_per_beat)?;

            if let Some(previous) = segments.last() {
                if start_tick <= previous.start_tick {
                    return Err(TimeError::InvalidTempoMap(
                        "tempo_map positions must be strictly increasing".to_owned(),
                    ));
                }
            }

            let start_ms = match segments.last() {
                Some(previous) => {
                    previous.start_ms
                        + (start_tick - previous.start_tick) as f64 * previous.ms_per_tick
                }
                None => 0.0,
            };
            let ms_per_tick = 60_000.0 / (f64::from(entry.bpm) * f64::from(ticks_per_beat));

            segments.push(TimingSegment {
                start_pos: entry.pos,
                start_tick,
                start_ms,
                bpm: entry.bpm,
                ms_per_tick,
            });
        }

        Ok(Self {
            time_signature,
            ticks_per_beat,
            segments,
        })
    }

    pub fn time_signature(&self) -> TimeSignature {
        self.time_signature
    }

    pub fn ticks_per_beat(&self) -> u16 {
        self.ticks_per_beat
    }

    pub fn tempo_count(&self) -> usize {
        self.segments.len()
    }

    pub fn pos_to_ms(&self, pos: MusicalPos) -> Result<f64, TimeError> {
        let absolute_ticks = pos.to_absolute_ticks(self.time_signature, self.ticks_per_beat)?;
        let segment_index = self
            .segments
            .partition_point(|segment| segment.start_tick <= absolute_ticks)
            .saturating_sub(1);
        let segment = &self.segments[segment_index];

        Ok(segment.start_ms + (absolute_ticks - segment.start_tick) as f64 * segment.ms_per_tick)
    }

    pub fn ms_to_pos(&self, ms: f64) -> Result<MusicalPos, TimeError> {
        if !ms.is_finite() || ms < 0.0 {
            return Err(TimeError::NegativeMilliseconds { ms });
        }

        let segment_index = self
            .segments
            .partition_point(|segment| segment.start_ms <= ms)
            .saturating_sub(1);
        let segment = &self.segments[segment_index];
        let elapsed_ticks = ((ms - segment.start_ms) / segment.ms_per_tick).round();

        if !elapsed_ticks.is_finite()
            || elapsed_ticks < i64::MIN as f64
            || elapsed_ticks > i64::MAX as f64
        {
            return Err(TimeError::PositionOverflow);
        }

        let absolute_ticks = segment
            .start_tick
            .checked_add(elapsed_ticks as i64)
            .ok_or(TimeError::PositionOverflow)?;

        MusicalPos::from_absolute_ticks(absolute_ticks, self.time_signature, self.ticks_per_beat)
    }
}

fn validate_timing_inputs(
    time_signature: TimeSignature,
    ticks_per_beat: u16,
) -> Result<(), TimeError> {
    if time_signature.num == 0 || time_signature.den == 0 {
        return Err(TimeError::InvalidTimeSignature {
            num: time_signature.num,
            den: time_signature.den,
        });
    }

    if ticks_per_beat == 0 {
        return Err(TimeError::InvalidTicksPerBeat { ticks_per_beat });
    }

    Ok(())
}

fn validate_position(
    pos: MusicalPos,
    time_signature: TimeSignature,
    ticks_per_beat: u16,
) -> Result<(), TimeError> {
    validate_timing_inputs(time_signature, ticks_per_beat)?;

    if pos.bar == 0 {
        return Err(TimeError::InvalidPosition {
            pos,
            message: "bar must be greater than or equal to 1".to_owned(),
        });
    }

    if pos.beat == 0 || pos.beat > time_signature.num {
        return Err(TimeError::InvalidPosition {
            pos,
            message: format!("beat must be between 1 and {}", time_signature.num),
        });
    }

    if pos.tick >= ticks_per_beat {
        return Err(TimeError::InvalidPosition {
            pos,
            message: format!("tick must be less than {ticks_per_beat}"),
        });
    }

    Ok(())
}
