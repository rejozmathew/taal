import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/settings/settings_screen.dart';
import 'package:taal/features/settings/settings_store.dart';
import 'package:taal/platform/audio/metronome_audio.dart';
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

void main() {
  testWidgets('settings screen exposes persisted settings controls', (
    tester,
  ) async {
    final store = _FakeSettingsStore();
    var recalibrateTapped = false;

    await _pumpSettings(
      tester,
      store: store,
      audioOutput: _FakeMetronomeAudioOutput(),
      onRecalibrate: () {
        recalibrateTapped = true;
      },
    );

    expect(find.text('Settings for Ada.'), findsOneWidget);
    expect(find.text('MIDI'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Display'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Daily goal: 10 min'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settings-latency-slider')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('settings-preview-latency')));
    await tester.pump();
    expect(find.textContaining('Current input offset'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-recalibrate')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-recalibrate')));
    expect(recalibrateTapped, isTrue);
  });

  testWidgets('settings changes persist through store and apply audio output', (
    tester,
  ) async {
    final store = _FakeSettingsStore();
    final audioOutput = _FakeMetronomeAudioOutput();

    await _pumpSettings(tester, store: store, audioOutput: audioOutput);

    final volumeSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('settings-metronome-volume')),
    );
    volumeSlider.onChanged!(0.35);
    volumeSlider.onChangeEnd!(0.35);
    await tester.pumpAndSettle();

    expect(store.profileSettings.metronomeVolume, 0.35);
    expect(audioOutput.lastSettings?.volume, 0.35);

    final latencySlider = tester.widget<Slider>(
      find.byKey(const ValueKey('settings-latency-slider')),
    );
    latencySlider.onChanged!(14.5);
    latencySlider.onChangeEnd!(14.5);
    await tester.pumpAndSettle();

    expect(store.device.inputOffsetMs, 14.5);

    await tester.enterText(
      find.byKey(const ValueKey('settings-audio-output-device')),
      'wasapi:headphones',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-save-audio-output')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-save-audio-output')));
    await tester.pumpAndSettle();

    expect(store.appSettings.audioOutputDeviceId, 'wasapi:headphones');

    final goalSlider = tester.widget<Slider>(
      find.byKey(const ValueKey('settings-daily-goal-minutes')),
    );
    goalSlider.onChanged!(25);
    await tester.pumpAndSettle();

    expect(store.profileSettings.dailyGoalMinutes, 25);
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required _FakeSettingsStore store,
  _FakeMetronomeAudioOutput? audioOutput,
  VoidCallback? onRecalibrate,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            TaalSettingsScreen(
              store: store,
              profileState: _profileState,
              activeProfile: _profileState.profiles.single,
              busy: false,
              onSwitchProfile: (_) {},
              onProfileStateChanged: (_) {},
              onRecalibrate: onRecalibrate,
              metronomeAudioOutput: audioOutput,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeSettingsStore implements SettingsScreenStore {
  AppSettings appSettings = const AppSettings(
    lastActiveProfileId: 'ada',
    audioOutputDeviceId: null,
  );
  ProfileSettings profileSettings = const ProfileSettings(
    playerId: 'ada',
    preferredView: SettingsPracticeView.noteHighway,
    theme: ThemePreference.system,
    reduceMotion: false,
    highContrast: false,
    metronomeVolume: 0.8,
    metronomeClickSound: SettingsClickSoundPreset.classic,
    autoPauseEnabled: false,
    autoPauseTimeoutMs: 3000,
    recordPracticeModeAttempts: true,
    dailyGoalMinutes: 10,
    activeDeviceProfileId: 'device-1',
    updatedAt: '2026-04-17T10:00:00Z',
  );
  DeviceProfileSettings device = const DeviceProfileSettings(
    id: 'device-1',
    name: 'TD-27 Practice',
    layoutId: 'std-5pc-v1',
    mappingCount: 10,
    inputOffsetMs: 0,
    velocityCurve: DeviceVelocityCurve.linear,
  );

  @override
  SettingsSnapshot loadSettings(String playerId) {
    return SettingsSnapshot(app: appSettings, profile: profileSettings);
  }

  @override
  AppSettings updateAppSettings(AppSettings settings) {
    appSettings = settings;
    return appSettings;
  }

  @override
  ProfileSettings updateProfileSettings({
    required String playerId,
    required ProfileSettingsUpdate update,
  }) {
    profileSettings = ProfileSettings(
      playerId: playerId,
      preferredView: update.preferredView,
      theme: update.theme,
      reduceMotion: update.reduceMotion,
      highContrast: update.highContrast,
      metronomeVolume: update.metronomeVolume,
      metronomeClickSound: update.metronomeClickSound,
      autoPauseEnabled: update.autoPauseEnabled,
      autoPauseTimeoutMs: update.autoPauseTimeoutMs,
      recordPracticeModeAttempts: update.recordPracticeModeAttempts,
      dailyGoalMinutes: update.dailyGoalMinutes,
      activeDeviceProfileId: update.activeDeviceProfileId,
      updatedAt: '2026-04-17T10:01:00Z',
    );
    return profileSettings;
  }

  @override
  rust_profiles.LocalProfileStateDto updatePlayerProfileName({
    required String profileId,
    required String name,
  }) {
    return _profileState;
  }

  @override
  List<DeviceProfileSettings> listDeviceProfiles(String playerId) {
    return [device];
  }

  @override
  DeviceProfileSettings updateDeviceProfileSettings({
    required String playerId,
    required String deviceProfileId,
    required double inputOffsetMs,
    required DeviceVelocityCurve velocityCurve,
  }) {
    device = DeviceProfileSettings(
      id: device.id,
      name: device.name,
      layoutId: device.layoutId,
      mappingCount: device.mappingCount,
      inputOffsetMs: inputOffsetMs,
      velocityCurve: velocityCurve,
    );
    return device;
  }
}

class _FakeMetronomeAudioOutput implements MetronomeAudioOutput {
  MetronomeAudioSettings? lastSettings;

  @override
  Future<void> configure(MetronomeAudioSettings settings) async {
    lastSettings = settings;
  }

  @override
  Future<void> scheduleClicks({
    required int sessionStartTimeNs,
    required List<ScheduledMetronomeClick> clicks,
  }) async {}

  @override
  Future<void> scheduleDrumHits({
    required int sessionStartTimeNs,
    required List<ScheduledDrumHit> hits,
  }) async {}

  @override
  Future<void> stop() async {}
}

const _profileState = rust_profiles.LocalProfileStateDto(
  profiles: [
    rust_profiles.PlayerProfileDto(
      id: 'ada',
      name: 'Ada',
      avatar: 'sticks',
      experienceLevel: rust_profiles.ProfileExperienceLevelDto.beginner,
      preferredView: rust_profiles.ProfilePracticeViewDto.noteHighway,
      createdAt: '2026-04-17T10:00:00Z',
      updatedAt: '2026-04-17T10:00:00Z',
    ),
  ],
  activeProfileId: 'ada',
);
