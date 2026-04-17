import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taal/src/rust/api/device_profiles.dart';
import 'package:taal/src/rust/api/profiles.dart';
import 'package:taal/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dart persists device profiles through the Rust bridge', () async {
    await RustLib.init();

    final tempDir = await Directory.systemTemp.createTemp(
      'taal_device_profile_bridge_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final databasePath = [
      tempDir.path,
      'device_profiles.sqlite',
    ].join(Platform.pathSeparator);

    final player = createLocalProfile(
      databasePath: databasePath,
      name: 'Rejo',
      avatar: null,
      experienceLevel: ProfileExperienceLevelDto.beginner,
    ).state!.activeProfileId!;

    final created = createPersistedDeviceProfile(
      databasePath: databasePath,
      playerId: player,
      profileJson: jsonEncode(_deviceProfile(name: 'TD-27 Practice')),
    );
    expect(created.error, isNull);
    expect(jsonDecode(created.profileJson!)['name'], 'TD-27 Practice');

    final profiles = listPersistedDeviceProfiles(
      databasePath: databasePath,
      playerId: player,
    );
    expect(profiles.error, isNull);
    expect(profiles.profilesJson, hasLength(1));

    final lastUsed = setLastUsedDeviceProfile(
      databasePath: databasePath,
      playerId: player,
      deviceProfileId: _deviceProfileId,
    );
    expect(lastUsed.error, isNull);
    expect(jsonDecode(lastUsed.profileJson!)['id'], _deviceProfileId);

    final reconnected = lastUsedDeviceProfileForDevice(
      databasePath: databasePath,
      playerId: player,
      vendorName: 'Roland',
      modelName: 'TD-27',
      platformId: 'winmm:0',
    );
    expect(reconnected.error, isNull);
    expect(jsonDecode(reconnected.profileJson!)['id'], _deviceProfileId);

    final updatedProfile = _deviceProfile(
      name: 'TD-27 Performance',
      inputOffsetMs: 12.5,
      updatedAt: '2026-04-17T12:00:00Z',
    );
    final updateResult = updatePersistedDeviceProfile(
      databasePath: databasePath,
      playerId: player,
      profileJson: jsonEncode(updatedProfile),
    );
    expect(updateResult.error, isNull);
    expect(jsonDecode(updateResult.profileJson!)['input_offset_ms'], 12.5);

    final deleted = deletePersistedDeviceProfile(
      databasePath: databasePath,
      playerId: player,
      deviceProfileId: _deviceProfileId,
    );
    expect(deleted.error, isNull);

    final afterDelete = listPersistedDeviceProfiles(
      databasePath: databasePath,
      playerId: player,
    );
    expect(afterDelete.error, isNull);
    expect(afterDelete.profilesJson, isEmpty);
  });
}

const _deviceProfileId = '550e8400-e29b-41d4-a716-446655440081';

Map<String, Object?> _deviceProfile({
  required String name,
  double inputOffsetMs = 0.0,
  String updatedAt = '2026-04-17T10:00:00Z',
}) {
  return {
    'id': _deviceProfileId,
    'name': name,
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
    'input_offset_ms': inputOffsetMs,
    'dedupe_window_ms': 8.0,
    'velocity_curve': 'linear',
    'preset_origin': 'test',
    'created_at': '2026-04-17T10:00:00Z',
    'updated_at': updatedAt,
  };
}
