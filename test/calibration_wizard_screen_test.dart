import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/calibration/calibration_wizard_screen.dart';
import 'package:taal/features/calibration/device_profile_calibration_store.dart';
import 'package:taal/platform/audio/metronome_audio.dart';
import 'package:taal/platform/midi/midi_adapter.dart';
import 'package:taal/src/rust/api/device_profiles.dart';

void main() {
  testWidgets('captures 8 snare hits and stores calibration offset', (
    tester,
  ) async {
    final gateway = _FakeGateway([jsonEncode(_deviceProfile())]);
    final store = DeviceProfileCalibrationStore(
      databasePath: 'test.sqlite',
      playerId: 'player-1',
      gateway: gateway,
    );
    final midi = _FakeMidiAdapter();
    final audio = _FakeMetronomeAudioOutput();
    var nowNs = 1 * 1000 * 1000 * 1000;

    await tester.pumpWidget(
      MaterialApp(
        home: CalibrationWizardScreen(
          databasePath: 'test.sqlite',
          playerId: 'player-1',
          store: store,
          midiAdapter: midi,
          audioOutput: audio,
          clockNowNs: () => nowNs,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start calibration'));
    await tester.pump();

    expect(midi.openedDeviceId, 1);
    expect(audio.scheduledClicks, hasLength(8));

    final startNs = audio.sessionStartTimeNs!;
    for (var beat = 0; beat < 8; beat += 1) {
      midi.emit(
        MidiNoteOnEvent(
          deviceId: 1,
          channel: 9,
          note: 38,
          velocity: 96,
          timestampNs: startNs + beat * 600 * 1000000 + 12 * 1000000,
        ),
      );
      await tester.pump();
    }

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final updated =
        jsonDecode(gateway.updatedProfileJson!) as Map<String, Object?>;
    expect(updated['input_offset_ms'], 12.0);
    expect(gateway.lastUsedProfileId, _deviceProfileId);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('12ms - excellent'), findsOneWidget);
  });
}

class _FakeMidiAdapter implements Phase0MidiAdapter {
  final _controller = StreamController<MidiNoteOnEvent>.broadcast();
  int? openedDeviceId;
  bool closed = false;

  @override
  String get platformName => 'test';

  @override
  Stream<MidiNoteOnEvent> get noteOnEvents => _controller.stream;

  @override
  Future<List<MidiInputDevice>> listDevices() async {
    return const [MidiInputDevice(id: 1, name: 'Test MIDI')];
  }

  @override
  Future<void> openDevice(int deviceId) async {
    openedDeviceId = deviceId;
    closed = false;
  }

  @override
  Future<void> closeDevice() async {
    closed = true;
  }

  void emit(MidiNoteOnEvent event) {
    _controller.add(event);
  }
}

class _FakeMetronomeAudioOutput implements MetronomeAudioOutput {
  int? sessionStartTimeNs;
  List<ScheduledMetronomeClick> scheduledClicks = const [];

  @override
  Future<void> configure(MetronomeAudioSettings settings) async {}

  @override
  Future<void> scheduleClicks({
    required int sessionStartTimeNs,
    required List<ScheduledMetronomeClick> clicks,
  }) async {
    this.sessionStartTimeNs = sessionStartTimeNs;
    scheduledClicks = clicks;
  }

  @override
  Future<void> stop() async {}
}

class _FakeGateway implements DeviceProfilePersistenceGateway {
  _FakeGateway(this.profileJson);

  final List<String> profileJson;
  String? updatedProfileJson;
  String? lastUsedProfileId;

  @override
  DeviceProfileOperationResult listProfiles({
    required String databasePath,
    required String playerId,
  }) {
    return DeviceProfileOperationResult(profilesJson: profileJson);
  }

  @override
  DeviceProfileOperationResult updateProfile({
    required String databasePath,
    required String playerId,
    required String profileJson,
  }) {
    updatedProfileJson = profileJson;
    return DeviceProfileOperationResult(
      profileJson: profileJson,
      profilesJson: const [],
    );
  }

  @override
  DeviceProfileOperationResult setLastUsedProfile({
    required String databasePath,
    required String playerId,
    required String deviceProfileId,
  }) {
    lastUsedProfileId = deviceProfileId;
    return const DeviceProfileOperationResult(profilesJson: []);
  }
}

const _deviceProfileId = '550e8400-e29b-41d4-a716-446655440081';

Map<String, Object?> _deviceProfile() {
  return {
    'id': _deviceProfileId,
    'name': 'TD-27 Practice',
    'instrument_family': 'drums',
    'layout_id': 'std-5pc-v1',
    'device_fingerprint': {
      'vendor_name': 'Roland',
      'model_name': 'TD-27',
      'platform_id': 'winmm:0',
    },
    'transport': 'usb',
    'midi_channel': 9,
    'note_map': [
      {
        'midi_note': 38,
        'lane_id': 'snare',
        'articulation': 'normal',
        'min_velocity': 1,
        'max_velocity': 127,
      },
    ],
    'hihat_model': null,
    'input_offset_ms': 0.0,
    'dedupe_window_ms': 8.0,
    'velocity_curve': 'linear',
    'preset_origin': 'test',
    'created_at': '2026-04-17T10:00:00Z',
    'updated_at': '2026-04-17T10:00:00Z',
  };
}
