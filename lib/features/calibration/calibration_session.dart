import 'dart:math' as math;

import 'package:taal/platform/audio/metronome_audio.dart';
import 'package:taal/platform/midi/midi_adapter.dart';

const calibrationDefaultBpm = 100;
const calibrationDefaultBeatCount = 8;
const calibrationDefaultLeadInMs = 800;
const calibrationDefaultHitWindowMs = 260.0;

class CalibrationSession {
  CalibrationSession({
    required Set<int> snareMidiNotes,
    this.bpm = calibrationDefaultBpm,
    this.beatCount = calibrationDefaultBeatCount,
    this.hitWindowMs = calibrationDefaultHitWindowMs,
  }) : assert(snareMidiNotes.isNotEmpty, 'snareMidiNotes must not be empty'),
       assert(bpm > 0, 'bpm must be positive'),
       assert(
         beatCount >= 8 && beatCount <= 16,
         'beatCount must be between 8 and 16',
       ),
       assert(hitWindowMs > 0, 'hitWindowMs must be positive'),
       snareMidiNotes = Set.unmodifiable(snareMidiNotes);

  final Set<int> snareMidiNotes;
  final int bpm;
  final int beatCount;
  final double hitWindowMs;
  final List<CalibrationHitSample> _samples = [];
  final Set<int> _matchedBeatIndexes = {};
  int? _sessionStartTimeNs;

  int get beatIntervalMs => (60000 / bpm).round();

  int? get sessionStartTimeNs => _sessionStartTimeNs;

  List<CalibrationHitSample> get samples => List.unmodifiable(_samples);

  bool get isStarted => _sessionStartTimeNs != null;

  bool get isComplete => _samples.length >= beatCount;

  List<ScheduledMetronomeClick> get scheduledClicks {
    return [
      for (var index = 0; index < beatCount; index += 1)
        ScheduledMetronomeClick(
          tMs: index * beatIntervalMs,
          accent: index == 0,
        ),
    ];
  }

  void start({required int sessionStartTimeNs}) {
    _sessionStartTimeNs = sessionStartTimeNs;
    _samples.clear();
    _matchedBeatIndexes.clear();
  }

  CalibrationHitSample? recordHit(MidiNoteOnEvent event) {
    final sessionStartTimeNs = _sessionStartTimeNs;
    if (sessionStartTimeNs == null || isComplete) {
      return null;
    }
    if (!snareMidiNotes.contains(event.note)) {
      return null;
    }

    final hitTimelineMs = (event.timestampNs - sessionStartTimeNs) / 1000000.0;
    final nearestBeat = (hitTimelineMs / beatIntervalMs).round();
    if (nearestBeat < 0 || nearestBeat >= beatCount) {
      return null;
    }
    if (_matchedBeatIndexes.contains(nearestBeat)) {
      return null;
    }

    final expectedMs = nearestBeat * beatIntervalMs;
    final deltaMs = hitTimelineMs - expectedMs;
    if (deltaMs.abs() > hitWindowMs) {
      return null;
    }

    final sample = CalibrationHitSample(
      beatIndex: nearestBeat,
      expectedMs: expectedMs,
      hitTimestampNs: event.timestampNs,
      rawNote: event.note,
      deltaMs: deltaMs,
    );
    _matchedBeatIndexes.add(nearestBeat);
    _samples.add(sample);
    return sample;
  }

  CalibrationResult result() {
    if (!isComplete) {
      throw StateError(
        'Calibration needs $beatCount valid snare hits before a result is available.',
      );
    }

    final deltas = _samples.map((sample) => sample.deltaMs).toList();
    final offsetMs = _median(deltas);
    final jitterMs = _standardDeviation(deltas);
    return CalibrationResult(
      offsetMs: offsetMs,
      jitterMs: jitterMs,
      sampleCount: _samples.length,
      quality: CalibrationQuality.from(offsetMs: offsetMs, jitterMs: jitterMs),
    );
  }
}

class CalibrationHitSample {
  const CalibrationHitSample({
    required this.beatIndex,
    required this.expectedMs,
    required this.hitTimestampNs,
    required this.rawNote,
    required this.deltaMs,
  });

  final int beatIndex;
  final int expectedMs;
  final int hitTimestampNs;
  final int rawNote;
  final double deltaMs;
}

class CalibrationResult {
  const CalibrationResult({
    required this.offsetMs,
    required this.jitterMs,
    required this.sampleCount,
    required this.quality,
  });

  final double offsetMs;
  final double jitterMs;
  final int sampleCount;
  final CalibrationQuality quality;

  String get offsetLabel => '${offsetMs.round()}ms';
}

enum CalibrationQualityLevel { excellent, usable, noisy }

class CalibrationQuality {
  const CalibrationQuality({
    required this.level,
    required this.label,
    required this.message,
  });

  factory CalibrationQuality.from({
    required double offsetMs,
    required double jitterMs,
  }) {
    final absOffset = offsetMs.abs();
    if (absOffset <= 20 && jitterMs <= 10) {
      return const CalibrationQuality(
        level: CalibrationQualityLevel.excellent,
        label: 'excellent',
        message: 'Excellent timing signal.',
      );
    }
    if (absOffset <= 50 && jitterMs <= 25) {
      return const CalibrationQuality(
        level: CalibrationQualityLevel.usable,
        label: 'usable',
        message: 'Usable. USB is recommended for the tightest feel.',
      );
    }
    return const CalibrationQuality(
      level: CalibrationQualityLevel.noisy,
      label: 'noisy',
      message: 'Noisy signal. Try again with a steady snare hit.',
    );
  }

  final CalibrationQualityLevel level;
  final String label;
  final String message;
}

double _median(List<double> values) {
  if (values.isEmpty) {
    throw ArgumentError.value(values, 'values', 'must not be empty');
  }
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2.0;
}

double _standardDeviation(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  final mean = values.reduce((left, right) => left + right) / values.length;
  final variance =
      values
          .map((value) {
            final diff = value - mean;
            return diff * diff;
          })
          .reduce((left, right) => left + right) /
      values.length;
  return math.sqrt(variance);
}
