import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:taal/src/rust/api/practice_runtime.dart';
import 'package:taal/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Dart bridge submits touch and MIDI hits into one Rust session',
    () async {
      await RustLib.init();

      final start = startPracticeRuntimeSession(
        request: const PracticeRuntimeStartRequest(
          lessonJson: _lessonJson,
          layoutJson: _layoutJson,
          scoringProfileJson: _scoringJson,
          deviceProfileJson: _deviceProfileJson,
          mode: PracticeRuntimeModeDto.practice,
          bpm: 120,
          startTimeNs: _startNs,
          lookaheadMs: 250,
        ),
      );
      expect(start.error, isNull);
      final sessionId = start.sessionId!;
      final timeline = jsonDecode(start.timelineJson!) as Map<String, Object?>;
      expect(timeline['total_duration_ms'], 2000);

      final touch = practiceRuntimeSubmitTouchHit(
        sessionId: sessionId,
        laneId: 'kick',
        velocity: 96,
        timestampNs: _timestampMs(5),
      );
      expect(touch.error, isNull);
      final touchEvents = jsonDecode(touch.eventsJson!) as List<Object?>;
      expect(
        (touchEvents.first! as Map<String, Object?>)['type'],
        'hit_graded',
      );
      expect((touchEvents.first! as Map<String, Object?>)['lane_id'], 'kick');

      final midi = practiceRuntimeSubmitMidiNoteOn(
        sessionId: sessionId,
        channel: 9,
        note: 38,
        velocity: 100,
        timestampNs: _timestampMs(505),
      );
      expect(midi.error, isNull);
      final midiEvents = jsonDecode(midi.eventsJson!) as List<Object?>;
      final midiHit = midiEvents.first! as Map<String, Object?>;
      expect(midiHit['type'], 'hit_graded');
      expect(midiHit['lane_id'], 'snare');
      expect(midiHit['combo'], 2);

      final stopped = practiceRuntimeStop(sessionId: sessionId);
      expect(stopped.error, isNull);
      final summary = jsonDecode(stopped.summaryJson!) as Map<String, Object?>;
      expect(summary['score_total'], 100.0);
      expect(summary['hit_rate_pct'], 100.0);

      final disposed = practiceRuntimeDispose(sessionId: sessionId);
      expect(disposed.error, isNull);
    },
  );
}

const _startNs = 10000000000;

int _timestampMs(int ms) => _startNs + ms * 1000000;

const _lessonJson = r'''
{
  "schema_version": "1.0",
  "id": "550e8400-e29b-41d4-a716-446655440231",
  "revision": "1.0.0",
  "title": "Runtime Tap Fixture",
  "instrument": {
    "family": "drums",
    "variant": "kit",
    "layout_id": "std-runtime-v1"
  },
  "timing": {
    "time_signature": { "num": 4, "den": 4 },
    "ticks_per_beat": 480,
    "tempo_map": [
      { "pos": { "bar": 1, "beat": 1, "tick": 0 }, "bpm": 120.0 }
    ]
  },
  "lanes": [
    {
      "lane_id": "kick",
      "events": [
        { "event_id": "kick-1", "pos": { "bar": 1, "beat": 1, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 90, "articulation": "normal" } }
      ]
    },
    {
      "lane_id": "snare",
      "events": [
        { "event_id": "snare-1", "pos": { "bar": 1, "beat": 2, "tick": 0 }, "duration_ticks": 0,
          "payload": { "type": "hit", "velocity": 95, "articulation": "normal" } }
      ]
    }
  ],
  "sections": [
    {
      "section_id": "main",
      "label": "Main",
      "range": {
        "start": { "bar": 1, "beat": 1, "tick": 0 },
        "end": { "bar": 2, "beat": 1, "tick": 0 }
      },
      "loopable": true
    }
  ],
  "practice": {
    "modes_supported": ["practice", "play"],
    "count_in_bars": 1,
    "metronome_enabled": true,
    "start_tempo_bpm": 120.0,
    "tempo_floor_bpm": 60.0
  },
  "metadata": {
    "difficulty": "beginner",
    "tags": [],
    "skills": [],
    "objectives": [],
    "prerequisites": [],
    "estimated_minutes": 1
  },
  "scoring_profile_id": "score-runtime-v1"
}
''';

const _layoutJson = r'''
{
  "schema_version": "1.0",
  "id": "std-runtime-v1",
  "family": "drums",
  "variant": "kit",
  "visual": {
    "lane_slots": [
      { "lane_id": "kick", "slot_id": "kick" },
      { "lane_id": "snare", "slot_id": "snare" }
    ]
  },
  "lanes": [
    { "lane_id": "kick", "label": "Kick", "midi_hints": [{ "hint_type": "note", "values": [36] }] },
    { "lane_id": "snare", "label": "Snare", "midi_hints": [{ "hint_type": "note", "values": [38] }] }
  ]
}
''';

const _scoringJson = r'''
{
  "id": "score-runtime-v1",
  "schema_version": "1.0",
  "timing_windows_ms": {
    "perfect_ms": 20.0,
    "good_ms": 45.0,
    "outer_ms": 120.0
  },
  "grading": {
    "perfect": 1.0,
    "good": 0.75,
    "early": 0.5,
    "late": 0.5,
    "miss": 0.0
  },
  "combo": {
    "encouragement_milestones": [2]
  },
  "rules": {}
}
''';

const _deviceProfileJson = r'''
{
  "id": "550e8400-e29b-41d4-a716-446655440232",
  "name": "Runtime Test Kit",
  "instrument_family": "drums",
  "layout_id": "std-runtime-v1",
  "device_fingerprint": {
    "vendor_name": "Test",
    "model_name": "Runtime",
    "platform_id": "test:runtime"
  },
  "transport": "usb",
  "midi_channel": 9,
  "note_map": [
    {
      "midi_note": 38,
      "lane_id": "snare",
      "articulation": "normal",
      "min_velocity": 1,
      "max_velocity": 127
    }
  ],
  "hihat_model": null,
  "input_offset_ms": 0.0,
  "dedupe_window_ms": 8.0,
  "velocity_curve": "linear",
  "preset_origin": "test",
  "created_at": "2026-04-17T10:00:00Z",
  "updated_at": "2026-04-17T10:00:00Z"
}
''';
