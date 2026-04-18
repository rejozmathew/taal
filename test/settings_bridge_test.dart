import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taal/src/rust/api/device_profiles.dart';
import 'package:taal/src/rust/api/profiles.dart';
import 'package:taal/src/rust/api/settings.dart';
import 'package:taal/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dart reads and updates settings through the Rust bridge', () async {
    await RustLib.init();

    final tempDir = await Directory.systemTemp.createTemp(
      'taal_settings_bridge_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final databasePath = [
      tempDir.path,
      'settings.sqlite',
    ].join(Platform.pathSeparator);

    final playerId = createLocalProfile(
      databasePath: databasePath,
      name: 'Rejo',
      avatar: null,
      experienceLevel: ProfileExperienceLevelDto.beginner,
    ).state!.activeProfileId!;

    createPersistedDeviceProfile(
      databasePath: databasePath,
      playerId: playerId,
      profileJson: jsonEncode(_deviceProfile()),
    );

    final defaults = loadSettingsSnapshot(
      databasePath: databasePath,
      playerId: playerId,
    );
    expect(defaults.error, isNull);
    final defaultsJson = jsonDecode(defaults.settingsJson!);
    expect(defaultsJson['profile']['theme'], 'system');
    expect(defaultsJson['profile']['metronome_volume'], 0.8);
    expect(defaultsJson['profile']['auto_pause_enabled'], isFalse);
    expect(defaultsJson['profile']['daily_goal_minutes'], 10);
    expect(defaultsJson['profile']['play_kit_hit_sounds'], isFalse);

    final profileUpdate = updateProfileSettings(
      databasePath: databasePath,
      playerId: playerId,
      settingsUpdateJson: jsonEncode({
        'preferred_view': 'notation',
        'theme': 'dark',
        'reduce_motion': true,
        'high_contrast': true,
        'metronome_volume': 0.45,
        'metronome_click_sound': 'woodblock',
        'auto_pause_enabled': true,
        'auto_pause_timeout_ms': 4500,
        'record_practice_mode_attempts': false,
        'daily_goal_minutes': 25,
        'play_kit_hit_sounds': true,
        'active_device_profile_id': _deviceProfileId,
      }),
    );
    expect(profileUpdate.error, isNull);
    final profileJson = jsonDecode(profileUpdate.settingsJson!);
    expect(profileJson['preferred_view'], 'notation');
    expect(profileJson['daily_goal_minutes'], 25);
    expect(profileJson['play_kit_hit_sounds'], isTrue);
    expect(profileJson['active_device_profile_id'], _deviceProfileId);

    final appUpdate = updateAppSettings(
      databasePath: databasePath,
      settingsJson: jsonEncode({
        'last_active_profile_id': playerId,
        'audio_output_device_id': 'wasapi:headphones',
      }),
    );
    expect(appUpdate.error, isNull);
    expect(
      jsonDecode(appUpdate.settingsJson!)['audio_output_device_id'],
      'wasapi:headphones',
    );

    final renamed = updatePlayerProfileName(
      databasePath: databasePath,
      profileId: playerId,
      name: 'Rejo M',
    );
    expect(renamed.error, isNull);
    expect(renamed.state!.profiles.single.name, 'Rejo M');

    final deviceUpdate = updateDeviceProfileSettings(
      databasePath: databasePath,
      playerId: playerId,
      deviceProfileId: _deviceProfileId,
      inputOffsetMs: -12.5,
      velocityCurve: VelocityCurveDto.hard,
    );
    expect(deviceUpdate.error, isNull);
    final deviceJson = jsonDecode(deviceUpdate.profileJson!);
    expect(deviceJson['input_offset_ms'], -12.5);
    expect(deviceJson['velocity_curve'], 'hard');
  });
}

const _deviceProfileId = '550e8400-e29b-41d4-a716-446655440091';

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
