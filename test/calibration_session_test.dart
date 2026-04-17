import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/calibration/calibration_session.dart';
import 'package:taal/platform/midi/midi_adapter.dart';

void main() {
  test('schedules 8 clicks at 100 BPM', () {
    final session = CalibrationSession(snareMidiNotes: {38});

    expect(session.beatIntervalMs, 600);
    expect(session.scheduledClicks.map((click) => click.tMs), [
      0,
      600,
      1200,
      1800,
      2400,
      3000,
      3600,
      4200,
    ]);
    expect(session.scheduledClicks.first.accent, isTrue);
    expect(
      session.scheduledClicks.skip(1).every((click) => !click.accent),
      isTrue,
    );
  });

  test('records snare hits and computes median offset', () {
    const startNs = 10 * 1000 * 1000;
    final session = CalibrationSession(snareMidiNotes: {38})
      ..start(sessionStartTimeNs: startNs);
    final offsets = [11, 12, 13, 12, 11, 14, 12, 13];

    for (var beat = 0; beat < offsets.length; beat += 1) {
      final timestampNs =
          startNs + beat * 600 * 1000000 + offsets[beat] * 1000000;
      final sample = session.recordHit(
        MidiNoteOnEvent(
          deviceId: 1,
          channel: 9,
          note: 38,
          velocity: 96,
          timestampNs: timestampNs,
        ),
      );
      expect(sample, isNotNull);
    }

    final result = session.result();
    expect(result.sampleCount, 8);
    expect(result.offsetMs, 12.0);
    expect(result.quality.level, CalibrationQualityLevel.excellent);
  });

  test('ignores non-snare notes and duplicate hits for a beat', () {
    const startNs = 20 * 1000 * 1000;
    final session = CalibrationSession(snareMidiNotes: {38})
      ..start(sessionStartTimeNs: startNs);

    final ignored = session.recordHit(
      const MidiNoteOnEvent(
        deviceId: 1,
        channel: 9,
        note: 36,
        velocity: 96,
        timestampNs: startNs + 12 * 1000000,
      ),
    );
    expect(ignored, isNull);

    final first = session.recordHit(
      const MidiNoteOnEvent(
        deviceId: 1,
        channel: 9,
        note: 38,
        velocity: 96,
        timestampNs: startNs + 12 * 1000000,
      ),
    );
    final duplicate = session.recordHit(
      const MidiNoteOnEvent(
        deviceId: 1,
        channel: 9,
        note: 38,
        velocity: 97,
        timestampNs: startNs + 15 * 1000000,
      ),
    );

    expect(first, isNotNull);
    expect(duplicate, isNull);
    expect(session.samples, hasLength(1));
  });
}
