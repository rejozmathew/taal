import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:taal/src/rust/api/device_profiles.dart' as rust_devices;
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;
import 'package:taal/src/rust/api/settings.dart' as rust_settings;

abstract class SettingsScreenStore {
  SettingsSnapshot loadSettings(String playerId);

  AppSettings updateAppSettings(AppSettings settings);

  ProfileSettings updateProfileSettings({
    required String playerId,
    required ProfileSettingsUpdate update,
  });

  rust_profiles.LocalProfileStateDto updatePlayerProfileName({
    required String profileId,
    required String name,
  });

  List<DeviceProfileSettings> listDeviceProfiles(String playerId);

  DeviceProfileSettings updateDeviceProfileSettings({
    required String playerId,
    required String deviceProfileId,
    required double inputOffsetMs,
    required DeviceVelocityCurve velocityCurve,
  });
}

class RustSettingsStore implements SettingsScreenStore {
  RustSettingsStore(this.databasePath);

  final String databasePath;

  static Future<RustSettingsStore> open() async {
    final directory = await getApplicationSupportDirectory();
    final databasePath = [
      directory.path,
      'taal.sqlite',
    ].join(Platform.pathSeparator);
    return RustSettingsStore(databasePath);
  }

  @override
  SettingsSnapshot loadSettings(String playerId) {
    final result = rust_settings.loadSettingsSnapshot(
      databasePath: databasePath,
      playerId: playerId,
    );
    return SettingsSnapshot.fromJson(_unwrapSettingsJson(result));
  }

  @override
  AppSettings updateAppSettings(AppSettings settings) {
    final result = rust_settings.updateAppSettings(
      databasePath: databasePath,
      settingsJson: jsonEncode(settings.toJson()),
    );
    return AppSettings.fromJson(_unwrapSettingsJson(result));
  }

  @override
  ProfileSettings updateProfileSettings({
    required String playerId,
    required ProfileSettingsUpdate update,
  }) {
    final result = rust_settings.updateProfileSettings(
      databasePath: databasePath,
      playerId: playerId,
      settingsUpdateJson: jsonEncode(update.toJson()),
    );
    return ProfileSettings.fromJson(_unwrapSettingsJson(result));
  }

  @override
  rust_profiles.LocalProfileStateDto updatePlayerProfileName({
    required String profileId,
    required String name,
  }) {
    final result = rust_profiles.updatePlayerProfileName(
      databasePath: databasePath,
      profileId: profileId,
      name: name,
    );
    final state = result.state;
    if (state != null) {
      return state;
    }
    throw SettingsStoreException(result.error ?? 'Profile update failed.');
  }

  @override
  List<DeviceProfileSettings> listDeviceProfiles(String playerId) {
    final result = rust_devices.listPersistedDeviceProfiles(
      databasePath: databasePath,
      playerId: playerId,
    );
    if (result.error != null) {
      throw SettingsStoreException(result.error!);
    }
    return result.profilesJson
        .map((json) => DeviceProfileSettings.fromJson(jsonDecode(json)))
        .toList(growable: false);
  }

  @override
  DeviceProfileSettings updateDeviceProfileSettings({
    required String playerId,
    required String deviceProfileId,
    required double inputOffsetMs,
    required DeviceVelocityCurve velocityCurve,
  }) {
    final result = rust_devices.updateDeviceProfileSettings(
      databasePath: databasePath,
      playerId: playerId,
      deviceProfileId: deviceProfileId,
      inputOffsetMs: inputOffsetMs,
      velocityCurve: velocityCurve.toRustDto(),
    );
    if (result.error != null) {
      throw SettingsStoreException(result.error!);
    }
    final profileJson = result.profileJson;
    if (profileJson == null) {
      throw SettingsStoreException(
        'Device profile update returned no profile.',
      );
    }
    return DeviceProfileSettings.fromJson(jsonDecode(profileJson));
  }

  Map<String, Object?> _unwrapSettingsJson(
    rust_settings.SettingsOperationResult result,
  ) {
    final settingsJson = result.settingsJson;
    if (settingsJson != null) {
      final decoded = jsonDecode(settingsJson);
      if (decoded is Map<String, Object?>) {
        return decoded;
      }
    }
    throw SettingsStoreException(result.error ?? 'Settings operation failed.');
  }
}

class SettingsSnapshot {
  const SettingsSnapshot({required this.app, required this.profile});

  final AppSettings app;
  final ProfileSettings profile;

  factory SettingsSnapshot.fromJson(Map<String, Object?> json) {
    return SettingsSnapshot(
      app: AppSettings.fromJson(_map(json['app'])),
      profile: ProfileSettings.fromJson(_map(json['profile'])),
    );
  }
}

class AppSettings {
  const AppSettings({
    required this.lastActiveProfileId,
    required this.audioOutputDeviceId,
  });

  final String? lastActiveProfileId;
  final String? audioOutputDeviceId;

  factory AppSettings.fromJson(Map<String, Object?> json) {
    return AppSettings(
      lastActiveProfileId: json['last_active_profile_id'] as String?,
      audioOutputDeviceId: json['audio_output_device_id'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'last_active_profile_id': lastActiveProfileId,
      'audio_output_device_id': audioOutputDeviceId,
    };
  }
}

class ProfileSettings {
  const ProfileSettings({
    required this.playerId,
    required this.preferredView,
    required this.theme,
    required this.reduceMotion,
    required this.highContrast,
    required this.metronomeVolume,
    required this.metronomeClickSound,
    required this.autoPauseEnabled,
    required this.autoPauseTimeoutMs,
    required this.recordPracticeModeAttempts,
    required this.activeDeviceProfileId,
    required this.updatedAt,
  });

  final String playerId;
  final SettingsPracticeView preferredView;
  final ThemePreference theme;
  final bool reduceMotion;
  final bool highContrast;
  final double metronomeVolume;
  final SettingsClickSoundPreset metronomeClickSound;
  final bool autoPauseEnabled;
  final int autoPauseTimeoutMs;
  final bool recordPracticeModeAttempts;
  final String? activeDeviceProfileId;
  final String updatedAt;

  factory ProfileSettings.fromJson(Map<String, Object?> json) {
    return ProfileSettings(
      playerId: json['player_id'] as String,
      preferredView: SettingsPracticeViewX.fromJson(
        json['preferred_view'] as String,
      ),
      theme: ThemePreferenceX.fromJson(json['theme'] as String),
      reduceMotion: json['reduce_motion'] as bool,
      highContrast: json['high_contrast'] as bool,
      metronomeVolume: (json['metronome_volume'] as num).toDouble(),
      metronomeClickSound: SettingsClickSoundPresetX.fromJson(
        json['metronome_click_sound'] as String,
      ),
      autoPauseEnabled: json['auto_pause_enabled'] as bool,
      autoPauseTimeoutMs: json['auto_pause_timeout_ms'] as int,
      recordPracticeModeAttempts: json['record_practice_mode_attempts'] as bool,
      activeDeviceProfileId: json['active_device_profile_id'] as String?,
      updatedAt: json['updated_at'] as String,
    );
  }

  ProfileSettingsUpdate toUpdate() {
    return ProfileSettingsUpdate(
      preferredView: preferredView,
      theme: theme,
      reduceMotion: reduceMotion,
      highContrast: highContrast,
      metronomeVolume: metronomeVolume,
      metronomeClickSound: metronomeClickSound,
      autoPauseEnabled: autoPauseEnabled,
      autoPauseTimeoutMs: autoPauseTimeoutMs,
      recordPracticeModeAttempts: recordPracticeModeAttempts,
      activeDeviceProfileId: activeDeviceProfileId,
    );
  }
}

class ProfileSettingsUpdate {
  const ProfileSettingsUpdate({
    required this.preferredView,
    required this.theme,
    required this.reduceMotion,
    required this.highContrast,
    required this.metronomeVolume,
    required this.metronomeClickSound,
    required this.autoPauseEnabled,
    required this.autoPauseTimeoutMs,
    required this.recordPracticeModeAttempts,
    required this.activeDeviceProfileId,
  });

  final SettingsPracticeView preferredView;
  final ThemePreference theme;
  final bool reduceMotion;
  final bool highContrast;
  final double metronomeVolume;
  final SettingsClickSoundPreset metronomeClickSound;
  final bool autoPauseEnabled;
  final int autoPauseTimeoutMs;
  final bool recordPracticeModeAttempts;
  final String? activeDeviceProfileId;

  ProfileSettingsUpdate copyWith({
    SettingsPracticeView? preferredView,
    ThemePreference? theme,
    bool? reduceMotion,
    bool? highContrast,
    double? metronomeVolume,
    SettingsClickSoundPreset? metronomeClickSound,
    bool? autoPauseEnabled,
    int? autoPauseTimeoutMs,
    bool? recordPracticeModeAttempts,
    String? activeDeviceProfileId,
    bool clearActiveDeviceProfileId = false,
  }) {
    return ProfileSettingsUpdate(
      preferredView: preferredView ?? this.preferredView,
      theme: theme ?? this.theme,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      highContrast: highContrast ?? this.highContrast,
      metronomeVolume: metronomeVolume ?? this.metronomeVolume,
      metronomeClickSound: metronomeClickSound ?? this.metronomeClickSound,
      autoPauseEnabled: autoPauseEnabled ?? this.autoPauseEnabled,
      autoPauseTimeoutMs: autoPauseTimeoutMs ?? this.autoPauseTimeoutMs,
      recordPracticeModeAttempts:
          recordPracticeModeAttempts ?? this.recordPracticeModeAttempts,
      activeDeviceProfileId: clearActiveDeviceProfileId
          ? null
          : activeDeviceProfileId ?? this.activeDeviceProfileId,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'preferred_view': preferredView.jsonValue,
      'theme': theme.jsonValue,
      'reduce_motion': reduceMotion,
      'high_contrast': highContrast,
      'metronome_volume': metronomeVolume,
      'metronome_click_sound': metronomeClickSound.jsonValue,
      'auto_pause_enabled': autoPauseEnabled,
      'auto_pause_timeout_ms': autoPauseTimeoutMs,
      'record_practice_mode_attempts': recordPracticeModeAttempts,
      'active_device_profile_id': activeDeviceProfileId,
    };
  }
}

class DeviceProfileSettings {
  const DeviceProfileSettings({
    required this.id,
    required this.name,
    required this.layoutId,
    required this.mappingCount,
    required this.inputOffsetMs,
    required this.velocityCurve,
  });

  final String id;
  final String name;
  final String layoutId;
  final int mappingCount;
  final double inputOffsetMs;
  final DeviceVelocityCurve velocityCurve;

  factory DeviceProfileSettings.fromJson(Map<String, Object?> json) {
    final noteMap = json['note_map'];
    return DeviceProfileSettings(
      id: json['id'] as String,
      name: json['name'] as String,
      layoutId: json['layout_id'] as String,
      mappingCount: noteMap is List<Object?> ? noteMap.length : 0,
      inputOffsetMs: (json['input_offset_ms'] as num).toDouble(),
      velocityCurve: DeviceVelocityCurveX.fromJson(json['velocity_curve']),
    );
  }
}

enum SettingsPracticeView { noteHighway, notation }

extension SettingsPracticeViewX on SettingsPracticeView {
  String get jsonValue {
    switch (this) {
      case SettingsPracticeView.noteHighway:
        return 'note_highway';
      case SettingsPracticeView.notation:
        return 'notation';
    }
  }

  String get label {
    switch (this) {
      case SettingsPracticeView.noteHighway:
        return 'Note highway';
      case SettingsPracticeView.notation:
        return 'Notation';
    }
  }

  static SettingsPracticeView fromJson(String value) {
    switch (value) {
      case 'note_highway':
        return SettingsPracticeView.noteHighway;
      case 'notation':
        return SettingsPracticeView.notation;
    }
    throw SettingsStoreException('Unknown practice view: $value');
  }
}

enum ThemePreference { system, light, dark }

extension ThemePreferenceX on ThemePreference {
  String get jsonValue {
    switch (this) {
      case ThemePreference.system:
        return 'system';
      case ThemePreference.light:
        return 'light';
      case ThemePreference.dark:
        return 'dark';
    }
  }

  String get label {
    switch (this) {
      case ThemePreference.system:
        return 'System';
      case ThemePreference.light:
        return 'Light';
      case ThemePreference.dark:
        return 'Dark';
    }
  }

  static ThemePreference fromJson(String value) {
    switch (value) {
      case 'system':
        return ThemePreference.system;
      case 'light':
        return ThemePreference.light;
      case 'dark':
        return ThemePreference.dark;
    }
    throw SettingsStoreException('Unknown theme preference: $value');
  }
}

enum SettingsClickSoundPreset { classic, woodblock, hiHat }

extension SettingsClickSoundPresetX on SettingsClickSoundPreset {
  String get jsonValue {
    switch (this) {
      case SettingsClickSoundPreset.classic:
        return 'classic';
      case SettingsClickSoundPreset.woodblock:
        return 'woodblock';
      case SettingsClickSoundPreset.hiHat:
        return 'hi_hat';
    }
  }

  String get label {
    switch (this) {
      case SettingsClickSoundPreset.classic:
        return 'Classic';
      case SettingsClickSoundPreset.woodblock:
        return 'Woodblock';
      case SettingsClickSoundPreset.hiHat:
        return 'Hi-hat';
    }
  }

  static SettingsClickSoundPreset fromJson(String value) {
    switch (value) {
      case 'classic':
        return SettingsClickSoundPreset.classic;
      case 'woodblock':
        return SettingsClickSoundPreset.woodblock;
      case 'hi_hat':
      case 'hihat':
        return SettingsClickSoundPreset.hiHat;
    }
    throw SettingsStoreException('Unknown click sound preset: $value');
  }
}

enum DeviceVelocityCurve { linear, soft, hard, custom }

extension DeviceVelocityCurveX on DeviceVelocityCurve {
  String get label {
    switch (this) {
      case DeviceVelocityCurve.linear:
        return 'Linear';
      case DeviceVelocityCurve.soft:
        return 'Soft';
      case DeviceVelocityCurve.hard:
        return 'Hard';
      case DeviceVelocityCurve.custom:
        return 'Custom';
    }
  }

  rust_devices.VelocityCurveDto toRustDto() {
    switch (this) {
      case DeviceVelocityCurve.linear:
        return rust_devices.VelocityCurveDto.linear;
      case DeviceVelocityCurve.soft:
        return rust_devices.VelocityCurveDto.soft;
      case DeviceVelocityCurve.hard:
        return rust_devices.VelocityCurveDto.hard;
      case DeviceVelocityCurve.custom:
        throw SettingsStoreException(
          'Custom velocity curves are preserved but not edited in Settings.',
        );
    }
  }

  static DeviceVelocityCurve fromJson(Object? value) {
    if (value is String) {
      switch (value) {
        case 'linear':
          return DeviceVelocityCurve.linear;
        case 'soft':
          return DeviceVelocityCurve.soft;
        case 'hard':
          return DeviceVelocityCurve.hard;
      }
    }
    if (value is Map<String, Object?> || value is List<Object?>) {
      return DeviceVelocityCurve.custom;
    }
    throw SettingsStoreException('Unknown velocity curve: $value');
  }
}

class SettingsStoreException implements Exception {
  SettingsStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw SettingsStoreException('Expected JSON object.');
}
