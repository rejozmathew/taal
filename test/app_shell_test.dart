import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/app_shell/app_shell.dart';
import 'package:taal/features/settings/settings_store.dart';
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

void main() {
  testWidgets('home reaches all major shell sections on mobile navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpShell(tester, _FakeProfileStore(_state(activeId: 'ada')));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Welcome back, Ada.'), findsOneWidget);
    expect(find.text('Recommended next lesson'), findsOneWidget);
    expect(find.text('Recent practice'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);

    await _openHomeSection(
      tester,
      actionKey: 'home-action-practice',
      sectionKey: 'app-shell-section-practice',
    );
    await _returnHome(tester);

    await _openHomeSection(
      tester,
      actionKey: 'home-action-library',
      sectionKey: 'app-shell-section-library',
    );
    await _returnHome(tester);

    await _openHomeSection(
      tester,
      actionKey: 'home-action-studio',
      sectionKey: 'app-shell-section-studio',
    );
    await _returnHome(tester);

    await _openHomeSection(
      tester,
      actionKey: 'home-action-insights',
      sectionKey: 'app-shell-section-insights',
    );
    await _returnHome(tester);

    await _openHomeSection(
      tester,
      actionKey: 'home-action-settings',
      sectionKey: 'app-shell-section-settings',
    );
  });

  testWidgets('desktop shell uses a navigation rail', (tester) async {
    tester.view.physicalSize = const Size(1100, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpShell(tester, _FakeProfileStore(_state(activeId: 'ada')));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('profile switcher changes profile-specific home data', (
    tester,
  ) async {
    await _pumpShell(tester, _FakeProfileStore(_state(activeId: 'ada')));

    expect(find.text('Welcome back, Ada.'), findsOneWidget);
    expect(find.text('Basic Rock Beat 1'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('profile-switch-ben')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('profile-switch-ben')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back, Ben.'), findsOneWidget);
    expect(find.text('Syncopated 16ths'), findsOneWidget);
  });

  testWidgets('settings exposes the same profile switcher', (tester) async {
    await _pumpShell(tester, _FakeProfileStore(_state(activeId: 'ada')));

    await tester.ensureVisible(
      find.byKey(const ValueKey('home-action-settings')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-action-settings')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('app-shell-section-settings')),
      findsOneWidget,
    );
    expect(find.text('Settings for Ada.'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-switch-ben')), findsOneWidget);
  });
}

Future<void> _pumpShell(WidgetTester tester, AppShellProfileStore store) async {
  await tester.pumpWidget(
    MaterialApp(home: TaalAppShell(openProfileStore: () async => store)),
  );
  await tester.pumpAndSettle();
}

Future<void> _openHomeSection(
  WidgetTester tester, {
  required String actionKey,
  required String sectionKey,
}) async {
  await tester.ensureVisible(find.byKey(ValueKey(actionKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(actionKey)));
  await tester.pumpAndSettle();
  expect(find.byKey(ValueKey(sectionKey)), findsOneWidget);
}

Future<void> _returnHome(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-home')));
  await tester.pumpAndSettle();
  expect(find.text('Welcome back, Ada.'), findsOneWidget);
}

class _FakeProfileStore implements AppShellProfileStore {
  _FakeProfileStore(this._state) : settingsStore = _FakeSettingsStore();

  rust_profiles.LocalProfileStateDto _state;

  @override
  final SettingsScreenStore settingsStore;

  @override
  rust_profiles.LocalProfileStateDto load() => _state;

  @override
  rust_profiles.LocalProfileStateDto switchProfile(String profileId) {
    _state = rust_profiles.LocalProfileStateDto(
      profiles: _state.profiles,
      activeProfileId: profileId,
    );
    return _state;
  }
}

class _FakeSettingsStore implements SettingsScreenStore {
  SettingsSnapshot _snapshot = const SettingsSnapshot(
    app: AppSettings(lastActiveProfileId: 'ada', audioOutputDeviceId: null),
    profile: ProfileSettings(
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
      activeDeviceProfileId: null,
      updatedAt: '2026-04-17T10:00:00Z',
    ),
  );

  @override
  SettingsSnapshot loadSettings(String playerId) {
    _snapshot = SettingsSnapshot(
      app: AppSettings(
        lastActiveProfileId: playerId,
        audioOutputDeviceId: _snapshot.app.audioOutputDeviceId,
      ),
      profile: ProfileSettings(
        playerId: playerId,
        preferredView: _snapshot.profile.preferredView,
        theme: _snapshot.profile.theme,
        reduceMotion: _snapshot.profile.reduceMotion,
        highContrast: _snapshot.profile.highContrast,
        metronomeVolume: _snapshot.profile.metronomeVolume,
        metronomeClickSound: _snapshot.profile.metronomeClickSound,
        autoPauseEnabled: _snapshot.profile.autoPauseEnabled,
        autoPauseTimeoutMs: _snapshot.profile.autoPauseTimeoutMs,
        recordPracticeModeAttempts:
            _snapshot.profile.recordPracticeModeAttempts,
        activeDeviceProfileId: _snapshot.profile.activeDeviceProfileId,
        updatedAt: _snapshot.profile.updatedAt,
      ),
    );
    return _snapshot;
  }

  @override
  AppSettings updateAppSettings(AppSettings settings) {
    _snapshot = SettingsSnapshot(app: settings, profile: _snapshot.profile);
    return settings;
  }

  @override
  ProfileSettings updateProfileSettings({
    required String playerId,
    required ProfileSettingsUpdate update,
  }) {
    final updated = ProfileSettings(
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
      activeDeviceProfileId: update.activeDeviceProfileId,
      updatedAt: '2026-04-17T10:01:00Z',
    );
    _snapshot = SettingsSnapshot(app: _snapshot.app, profile: updated);
    return updated;
  }

  @override
  rust_profiles.LocalProfileStateDto updatePlayerProfileName({
    required String profileId,
    required String name,
  }) {
    return _state(activeId: profileId);
  }

  @override
  List<DeviceProfileSettings> listDeviceProfiles(String playerId) => const [];

  @override
  DeviceProfileSettings updateDeviceProfileSettings({
    required String playerId,
    required String deviceProfileId,
    required double inputOffsetMs,
    required DeviceVelocityCurve velocityCurve,
  }) {
    throw UnimplementedError();
  }
}

rust_profiles.LocalProfileStateDto _state({required String activeId}) {
  return rust_profiles.LocalProfileStateDto(
    profiles: const [
      rust_profiles.PlayerProfileDto(
        id: 'ada',
        name: 'Ada',
        avatar: 'sticks',
        experienceLevel: rust_profiles.ProfileExperienceLevelDto.beginner,
        preferredView: rust_profiles.ProfilePracticeViewDto.noteHighway,
        createdAt: '2026-04-17T10:00:00Z',
        updatedAt: '2026-04-17T10:00:00Z',
      ),
      rust_profiles.PlayerProfileDto(
        id: 'ben',
        name: 'Ben',
        avatar: 'snare',
        experienceLevel: rust_profiles.ProfileExperienceLevelDto.intermediate,
        preferredView: rust_profiles.ProfilePracticeViewDto.notation,
        createdAt: '2026-04-17T10:00:00Z',
        updatedAt: '2026-04-17T10:00:00Z',
      ),
    ],
    activeProfileId: activeId,
  );
}
