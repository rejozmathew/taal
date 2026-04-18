import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taal/features/app_shell/practice_habit_store.dart';
import 'package:taal/features/library/lesson_catalog.dart';
import 'package:taal/features/library/library_screen.dart';
import 'package:taal/features/onboarding/onboarding_flow.dart';
import 'package:taal/features/profiles/local_profile_store.dart';
import 'package:taal/features/settings/settings_screen.dart';
import 'package:taal/features/settings/settings_store.dart';
import 'package:taal/main.dart';
import 'package:taal/platform/midi/midi_device_monitor.dart';
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

typedef AppShellProfileStoreOpener = Future<AppShellProfileStore> Function();

abstract class AppShellProfileStore {
  SettingsScreenStore get settingsStore;

  PracticeHabitStore get habitStore;

  rust_profiles.LocalProfileStateDto load();

  rust_profiles.LocalProfileStateDto createProfile({
    required String name,
    required String? avatar,
    required rust_profiles.ProfileExperienceLevelDto experienceLevel,
  });

  rust_profiles.LocalProfileStateDto switchProfile(String profileId);

  rust_profiles.LocalProfileStateDto deleteProfile(String profileId);
}

class TaalAppShell extends StatefulWidget {
  const TaalAppShell({
    super.key,
    this.openProfileStore = _openLocalProfileStore,
    this.midiDeviceMonitor,
    this.loadCatalog = loadLessonCatalog,
  });

  final AppShellProfileStoreOpener openProfileStore;
  final MidiDeviceMonitor? midiDeviceMonitor;
  final Future<List<LessonSummary>> Function() loadCatalog;

  @override
  State<TaalAppShell> createState() => _TaalAppShellState();
}

class _TaalAppShellState extends State<TaalAppShell> {
  int _selectedIndex = 0;
  AppShellProfileStore? _store;
  rust_profiles.LocalProfileStateDto? _profileState;
  PracticeHabitSnapshot? _habitSnapshot;
  String? _habitError;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _rerunOnboarding = false;
  List<LessonSummary> _lessonCatalog = const [];
  MidiConnectionState _midiConnectionState = MidiConnectionState.disconnected;
  StreamSubscription<MidiDeviceChange>? _deviceChangeSub;
  StreamSubscription<MidiConnectionState>? _connectionStateSub;

  @override
  void initState() {
    super.initState();
    _initMidiMonitor();
    _load();
  }

  @override
  void dispose() {
    _deviceChangeSub?.cancel();
    _connectionStateSub?.cancel();
    super.dispose();
  }

  void _initMidiMonitor() {
    final monitor = widget.midiDeviceMonitor;
    if (monitor == null) return;

    _deviceChangeSub = monitor.deviceChanges.listen((change) {
      if (!mounted) return;
      final message = switch (change.type) {
        MidiDeviceChangeType.connected => '${change.device.name} connected',
        MidiDeviceChangeType.disconnected => 'MIDI device disconnected',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });

    _connectionStateSub = monitor.connectionStateChanges.listen((state) {
      if (!mounted) return;
      setState(() => _midiConnectionState = state);
    });

    monitor.startMonitoring();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.openProfileStore(),
        widget.loadCatalog(),
      ]);
      final store = results[0] as AppShellProfileStore;
      final catalog = results[1] as List<LessonSummary>;
      final state = store.load();
      final habit = _loadHabitForState(store, state);
      if (!mounted) {
        return;
      }
      _applyPersistedTheme(store, state);
      setState(() {
        _store = store;
        _profileState = state;
        _lessonCatalog = catalog;
        _habitSnapshot = habit.snapshot;
        _habitError = habit.error;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _applyPersistedTheme(
    AppShellProfileStore store,
    rust_profiles.LocalProfileStateDto state,
  ) {
    final activeId = state.activeProfileId;
    if (activeId == null) return;
    try {
      final snapshot = store.settingsStore.loadSettings(activeId);
      TaalApp.setThemeMode(
        context,
        themeModeFromPreference(snapshot.profile.theme),
      );
    } on Object {
      // Settings unavailable — keep current theme.
    }
  }

  Future<void> _switchProfile(String profileId) async {
    final store = _store;
    if (store == null || _busy) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = store.switchProfile(profileId);
      final habit = _loadHabitForState(store, state);
      if (!mounted) {
        return;
      }
      _applyPersistedTheme(store, state);
      setState(() {
        _profileState = state;
        _habitSnapshot = habit.snapshot;
        _habitError = habit.error;
        _busy = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  void _rerunSetupWizard() {
    setState(() => _rerunOnboarding = true);
  }

  void _cancelRerunSetup(rust_profiles.LocalProfileStateDto state) {
    setState(() {
      _rerunOnboarding = false;
      _profileState = state;
      _selectedIndex = 0;
    });
    final store = _store;
    if (store != null) {
      _applyPersistedTheme(store, state);
      final habit = _loadHabitForState(store, state);
      setState(() {
        _habitSnapshot = habit.snapshot;
        _habitError = habit.error;
      });
    }
  }

  Future<void> _deleteProfile(String profileId) async {
    final store = _store;
    if (store == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = store.deleteProfile(profileId);
      final habit = _loadHabitForState(store, state);
      if (!mounted) return;
      _applyPersistedTheme(store, state);
      setState(() {
        _profileState = state;
        _habitSnapshot = habit.snapshot;
        _habitError = habit.error;
        _busy = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  Future<void> _createProfileFromSettings({
    required String name,
    required String? avatar,
    required rust_profiles.ProfileExperienceLevelDto experienceLevel,
  }) async {
    final store = _store;
    if (store == null || _busy) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = store.createProfile(
        name: name,
        avatar: avatar,
        experienceLevel: experienceLevel,
      );
      final habit = _loadHabitForState(store, state);
      if (!mounted) return;
      _applyPersistedTheme(store, state);
      setState(() {
        _profileState = state;
        _habitSnapshot = habit.snapshot;
        _habitError = habit.error;
        _busy = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final profileState =
        _profileState ?? const rust_profiles.LocalProfileStateDto(profiles: []);
    final activeProfile = _activeProfile(profileState);
    final store = _store;

    if (store != null && (profileState.profiles.isEmpty || _rerunOnboarding)) {
      return OnboardingFlow(
        onCreateProfile:
            ({required name, required avatar, required experienceLevel}) async {
              return store.createProfile(
                name: name,
                avatar: avatar,
                experienceLevel: experienceLevel,
              );
            },
        onComplete: (state) {
          _cancelRerunSetup(state);
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 760;
        final selected = _destinations[_selectedIndex];
        final body = _ShellSectionScaffold(
          child: _sectionBody(
            context,
            selected.kind,
            profileState,
            activeProfile,
          ),
        );

        if (useRail) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Taal'),
              actions: [
                IconButton(
                  tooltip: 'Reload profiles',
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectIndex,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Taal'),
            actions: [
              IconButton(
                tooltip: 'Reload profiles',
                onPressed: _busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _selectIndex,
            destinations: [
              for (final destination in _destinations)
                NavigationDestination(
                  key: ValueKey('nav-${destination.name}'),
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
            ],
          ),
        );
      },
    );
  }

  void _selectIndex(int index) {
    if (index == _selectedIndex) {
      return;
    }
    final store = _store;
    final profileState = _profileState;
    final selectingHome =
        _destinations[index].kind == _ShellDestinationKind.home;
    final habit = selectingHome && store != null && profileState != null
        ? _loadHabitForState(store, profileState)
        : null;
    setState(() {
      _selectedIndex = index;
      if (habit != null) {
        _habitSnapshot = habit.snapshot;
        _habitError = habit.error;
      }
    });
  }

  Widget _sectionBody(
    BuildContext context,
    _ShellDestinationKind kind,
    rust_profiles.LocalProfileStateDto profileState,
    rust_profiles.PlayerProfileDto? activeProfile,
  ) {
    switch (kind) {
      case _ShellDestinationKind.home:
        return _HomeSection(
          profileState: profileState,
          activeProfile: activeProfile,
          habitSnapshot: _habitSnapshot,
          habitError: _habitError,
          busy: _busy,
          error: _error,
          onSwitchProfile: _switchProfile,
          onSelectSection: _selectKind,
          onRetry: _load,
        );
      case _ShellDestinationKind.practice:
        return _PlaceholderSection(
          key: const ValueKey('app-shell-section-practice'),
          title: 'Practice',
          subtitle: 'Choose a lesson from the Library.',
          body:
              'No lesson loaded. Pick one from the Library to start practicing.',
          icon: Icons.music_note_outlined,
          primaryActionLabel: 'Open Library',
          onPrimaryAction: () => _selectKind(_ShellDestinationKind.library),
          midiMessage: _midiConnectionState == MidiConnectionState.connected
              ? null
              : 'No drum kit connected. Tap pads are active.',
          onScanDevices: widget.midiDeviceMonitor != null
              ? () => widget.midiDeviceMonitor!.scanDevices()
              : null,
        );
      case _ShellDestinationKind.library:
        return LibraryScreen(
          lessons: _lessonCatalog,
          onStartPractice: (lesson) =>
              _selectKind(_ShellDestinationKind.practice),
        );
      case _ShellDestinationKind.studio:
        return const _PlaceholderSection(
          key: ValueKey('app-shell-section-studio'),
          title: 'Studio',
          subtitle: 'Create lessons and courses here soon.',
          body: 'Authoring tools arrive after the core player is complete.',
          icon: Icons.edit_note_outlined,
        );
      case _ShellDestinationKind.insights:
        return _InsightsSection(
          activeProfile: activeProfile,
          onGoToLibrary: () => _selectKind(_ShellDestinationKind.library),
        );
      case _ShellDestinationKind.settings:
        final store = _store;
        if (store == null) {
          return _PlaceholderSection(
            key: const ValueKey('app-shell-section-settings'),
            title: 'Settings',
            subtitle: 'Profile, kit, audio, and display settings.',
            body: 'Profile storage is still loading.',
            icon: Icons.settings_outlined,
            primaryActionLabel: 'Retry',
            onPrimaryAction: _load,
          );
        }
        return TaalSettingsScreen(
          profileState: profileState,
          activeProfile: activeProfile,
          busy: _busy,
          error: _error,
          store: store.settingsStore,
          onSwitchProfile: _switchProfile,
          onProfileStateChanged: _setProfileState,
          onRerunSetup: _rerunSetupWizard,
          onDeleteProfile: _deleteProfile,
          onCreateProfile: _createProfileFromSettings,
          onRecalibrate: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calibration is ready from Settings.'),
            ),
          ),
          onScanDevices: widget.midiDeviceMonitor != null
              ? () => widget.midiDeviceMonitor!.scanDevices()
              : null,
          midiConnectionState: _midiConnectionState,
        );
    }
  }

  void _selectKind(_ShellDestinationKind kind) {
    final index = _destinations.indexWhere(
      (destination) => destination.kind == kind,
    );
    if (index >= 0) {
      _selectIndex(index);
    }
  }

  rust_profiles.PlayerProfileDto? _activeProfile(
    rust_profiles.LocalProfileStateDto state,
  ) {
    final activeId = state.activeProfileId;
    if (activeId == null) {
      return null;
    }
    for (final profile in state.profiles) {
      if (profile.id == activeId) {
        return profile;
      }
    }
    return null;
  }

  void _setProfileState(rust_profiles.LocalProfileStateDto state) {
    final store = _store;
    final habit = store == null ? null : _loadHabitForState(store, state);
    setState(() {
      _profileState = state;
      if (habit != null) {
        _habitSnapshot = habit.snapshot;
        _habitError = habit.error;
      }
    });
  }

  _HabitLoadResult _loadHabitForState(
    AppShellProfileStore store,
    rust_profiles.LocalProfileStateDto state,
  ) {
    final profile = _activeProfile(state);
    if (profile == null) {
      return const _HabitLoadResult();
    }
    try {
      return _HabitLoadResult(
        snapshot: store.habitStore.loadPracticeHabitSnapshot(
          playerId: profile.id,
          todayLocalDayKey: localDayKey(DateTime.now()),
        ),
      );
    } on Object catch (error) {
      return _HabitLoadResult(error: error.toString());
    }
  }
}

class _LocalAppShellProfileStore implements AppShellProfileStore {
  _LocalAppShellProfileStore(this._delegate)
    : settingsStore = RustSettingsStore(_delegate.databasePath),
      habitStore = RustPracticeHabitStore(_delegate.databasePath);

  final LocalProfileStore _delegate;

  @override
  final SettingsScreenStore settingsStore;

  @override
  final PracticeHabitStore habitStore;

  @override
  rust_profiles.LocalProfileStateDto load() => _delegate.load();

  @override
  rust_profiles.LocalProfileStateDto createProfile({
    required String name,
    required String? avatar,
    required rust_profiles.ProfileExperienceLevelDto experienceLevel,
  }) {
    return _delegate.createProfile(
      name: name,
      avatar: avatar,
      experienceLevel: experienceLevel,
    );
  }

  @override
  rust_profiles.LocalProfileStateDto switchProfile(String profileId) {
    return _delegate.switchProfile(profileId);
  }

  @override
  rust_profiles.LocalProfileStateDto deleteProfile(String profileId) {
    return _delegate.deleteProfile(profileId);
  }
}

Future<AppShellProfileStore> _openLocalProfileStore() async {
  final store = await LocalProfileStore.open();
  return _LocalAppShellProfileStore(store);
}

class _HabitLoadResult {
  const _HabitLoadResult({this.snapshot, this.error});

  final PracticeHabitSnapshot? snapshot;
  final String? error;
}

enum _ShellDestinationKind {
  home,
  practice,
  library,
  studio,
  insights,
  settings,
}

class _ShellDestination {
  const _ShellDestination({
    required this.kind,
    required this.name,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final _ShellDestinationKind kind;
  final String name;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _ShellDestination(
    kind: _ShellDestinationKind.home,
    name: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  _ShellDestination(
    kind: _ShellDestinationKind.practice,
    name: 'practice',
    label: 'Practice',
    icon: Icons.sports_esports_outlined,
    selectedIcon: Icons.sports_esports,
  ),
  _ShellDestination(
    kind: _ShellDestinationKind.library,
    name: 'library',
    label: 'Library',
    icon: Icons.library_music_outlined,
    selectedIcon: Icons.library_music,
  ),
  _ShellDestination(
    kind: _ShellDestinationKind.studio,
    name: 'studio',
    label: 'Studio',
    icon: Icons.edit_note_outlined,
    selectedIcon: Icons.edit_note,
  ),
  _ShellDestination(
    kind: _ShellDestinationKind.insights,
    name: 'insights',
    label: 'Insights',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
  ),
  _ShellDestination(
    kind: _ShellDestinationKind.settings,
    name: 'settings',
    label: 'Settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  ),
];

class _ShellSectionScaffold extends StatelessWidget {
  const _ShellSectionScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.profileState,
    required this.activeProfile,
    required this.habitSnapshot,
    required this.habitError,
    required this.busy,
    required this.error,
    required this.onSwitchProfile,
    required this.onSelectSection,
    this.onRetry,
  });

  final rust_profiles.LocalProfileStateDto profileState;
  final rust_profiles.PlayerProfileDto? activeProfile;
  final PracticeHabitSnapshot? habitSnapshot;
  final String? habitError;
  final bool busy;
  final String? error;
  final ValueChanged<String> onSwitchProfile;
  final ValueChanged<_ShellDestinationKind> onSelectSection;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final profile = activeProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile == null
              ? 'Welcome to Taal.'
              : 'Welcome back, ${profile.name}.',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          profile == null
              ? 'Create a local profile to keep practice history, kit mappings, and preferences separate.'
              : 'Your next lesson and practice history stay with this profile.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(
            message: 'Something went wrong. Try restarting.',
            onRetry: onRetry,
          ),
        ],
        const SizedBox(height: 24),
        _Panel(
          title: 'Recommended next lesson',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _recommendedLessonTitle(profile),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(_recommendedLessonDetail(profile)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    key: const ValueKey('home-action-practice'),
                    onPressed: () =>
                        onSelectSection(_ShellDestinationKind.practice),
                    child: const Text('Practice'),
                  ),
                  OutlinedButton(
                    key: const ValueKey('home-action-library'),
                    onPressed: () =>
                        onSelectSection(_ShellDestinationKind.library),
                    child: const Text('Library'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _HomeMetricsRow(
          activeProfile: profile,
          habitSnapshot: habitSnapshot,
          habitError: habitError,
        ),
        const SizedBox(height: 16),
        _ProfileSwitcherPanel(
          profileState: profileState,
          busy: busy,
          onSwitchProfile: onSwitchProfile,
        ),
        const SizedBox(height: 16),
        _Panel(
          title: 'Go to',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SectionButton(
                label: 'Studio',
                keyName: 'studio',
                onPressed: () => onSelectSection(_ShellDestinationKind.studio),
              ),
              _SectionButton(
                label: 'Insights',
                keyName: 'insights',
                onPressed: () =>
                    onSelectSection(_ShellDestinationKind.insights),
              ),
              _SectionButton(
                label: 'Settings',
                keyName: 'settings',
                onPressed: () =>
                    onSelectSection(_ShellDestinationKind.settings),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InsightsSection extends StatelessWidget {
  const _InsightsSection({
    required this.activeProfile,
    required this.onGoToLibrary,
  });

  final rust_profiles.PlayerProfileDto? activeProfile;
  final VoidCallback onGoToLibrary;

  @override
  Widget build(BuildContext context) {
    return _PlaceholderSection(
      key: const ValueKey('app-shell-section-insights'),
      title: 'Insights',
      subtitle: 'No practice sessions yet. Start your first lesson!',
      body:
          '${activeProfile?.name ?? 'This player'} has no scored attempts yet. '
          'Complete a Play Mode session to see your review history here.',
      icon: Icons.insights_outlined,
      primaryActionLabel: 'Go to Library',
      onPrimaryAction: onGoToLibrary,
    );
  }
}

class _PlaceholderSection extends StatelessWidget {
  const _PlaceholderSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.body,
    this.icon,
    this.primaryActionLabel,
    this.onPrimaryAction,
    this.midiMessage,
    this.onScanDevices,
  });

  final String title;
  final String subtitle;
  final String body;
  final IconData? icon;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final String? midiMessage;
  final Future<void> Function()? onScanDevices;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        _Panel(
          title: title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 48,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
              ],
              Text(body),
            ],
          ),
        ),
        if (midiMessage != null) ...[
          const SizedBox(height: 12),
          _MidiStatusBanner(
            message: midiMessage!,
            onScanDevices: onScanDevices,
          ),
        ],
        if (primaryActionLabel != null) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onPrimaryAction,
            child: Text(primaryActionLabel!),
          ),
        ],
      ],
    );
  }
}

class _MidiStatusBanner extends StatelessWidget {
  const _MidiStatusBanner({required this.message, this.onScanDevices});

  final String message;
  final Future<void> Function()? onScanDevices;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.cable, size: 20, color: scheme.outline),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (onScanDevices != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const ValueKey('empty-state-scan-devices'),
                onPressed: () => onScanDevices!(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Scan'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeMetricsRow extends StatelessWidget {
  const _HomeMetricsRow({
    required this.activeProfile,
    required this.habitSnapshot,
    required this.habitError,
  });

  final rust_profiles.PlayerProfileDto? activeProfile;
  final PracticeHabitSnapshot? habitSnapshot;
  final String? habitError;

  @override
  Widget build(BuildContext context) {
    final snapshot = habitSnapshot;
    if (activeProfile == null) {
      return const Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricPanel(label: 'Daily goal', value: 'No profile'),
          _MetricPanel(label: 'Streak', value: 'No profile'),
          _MetricPanel(label: 'Weekly summary', value: 'No profile'),
        ],
      );
    }

    if (snapshot == null) {
      final value = habitError == null ? 'No attempts yet' : 'Unavailable';
      final detail = habitError;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _MetricPanel(label: 'Daily goal', value: value, detail: detail),
          const _MetricPanel(label: 'Streak', value: '0 days'),
          _MetricPanel(label: 'Weekly summary', value: value, detail: detail),
          _MetricPanel(
            label: 'Preferred view',
            value: _preferredViewLabel(activeProfile?.preferredView),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _DailyGoalPanel(snapshot: snapshot),
        _MetricPanel(
          label: 'Streak',
          value: '${snapshot.currentStreakDays} days',
          detail: snapshot.milestoneMessage ?? snapshot.streakMessage,
        ),
        _MetricPanel(
          label: 'Weekly summary',
          value:
              '${snapshot.week.daysPracticed} days / ${snapshot.week.totalMinutesCompleted} min / ${snapshot.week.fullLessonCompletions} lessons',
          detail: '${snapshot.week.scoredAttemptCount} scored attempts',
        ),
        _MetricPanel(
          label: 'Preferred view',
          value: _preferredViewLabel(activeProfile?.preferredView),
        ),
      ],
    );
  }
}

class _MetricPanel extends StatelessWidget {
  const _MetricPanel({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180),
      child: _Panel(
        title: label,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailyGoalPanel extends StatelessWidget {
  const _DailyGoalPanel({required this.snapshot});

  final PracticeHabitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final goal = snapshot.dailyGoalMinutes;
    final completed = snapshot.todayMinutesCompleted;
    final progress = goal <= 0
        ? 0.0
        : (completed / goal).clamp(0.0, 1.0).toDouble();
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: _Panel(
        title: 'Daily goal',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$completed / $goal min',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 6),
            Text(
              snapshot.todayGoalMet
                  ? 'Goal met today.'
                  : 'Every focused minute counts.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSwitcherPanel extends StatelessWidget {
  const _ProfileSwitcherPanel({
    required this.profileState,
    required this.busy,
    required this.onSwitchProfile,
  });

  final rust_profiles.LocalProfileStateDto profileState;
  final bool busy;
  final ValueChanged<String> onSwitchProfile;

  @override
  Widget build(BuildContext context) {
    if (profileState.profiles.isEmpty) {
      return const _Panel(
        title: 'Switch profile',
        child: Text(
          'Create a profile to separate practice history and settings.',
        ),
      );
    }

    final activeId = profileState.activeProfileId;

    return _Panel(
      title: 'Switch profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('home-profile-dropdown'),
            isExpanded: true,
            value: profileState.profiles.any((p) => p.id == activeId)
                ? activeId
                : null,
            decoration: const InputDecoration(
              labelText: 'Active profile',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final profile in profileState.profiles)
                DropdownMenuItem(
                  value: profile.id,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text(_avatarInitial(profile)),
                      ),
                      const SizedBox(width: 8),
                      Text(profile.name),
                    ],
                  ),
                ),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value != null) {
                      onSwitchProfile(value);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.keyName,
    required this.onPressed,
  });

  final String label;
  final String keyName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      key: ValueKey('home-action-$keyName'),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('error-retry'),
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _recommendedLessonTitle(rust_profiles.PlayerProfileDto? profile) {
  switch (profile?.experienceLevel) {
    case rust_profiles.ProfileExperienceLevelDto.beginner:
      return 'Basic Rock Beat';
    case rust_profiles.ProfileExperienceLevelDto.intermediate:
      return 'Syncopated Kick Push';
    case rust_profiles.ProfileExperienceLevelDto.teacher:
      return 'Pocket Funk Groove';
    case null:
      return 'First Steps: Kick and Snare';
  }
}

String _recommendedLessonDetail(rust_profiles.PlayerProfileDto? profile) {
  if (profile == null) {
    return 'A short starter lesson is ready after profile setup.';
  }
  return 'Selected for ${profile.name} based on ${_experienceLabel(profile.experienceLevel).toLowerCase()}.';
}

String _experienceLabel(
  rust_profiles.ProfileExperienceLevelDto experienceLevel,
) {
  switch (experienceLevel) {
    case rust_profiles.ProfileExperienceLevelDto.beginner:
      return 'Just starting';
    case rust_profiles.ProfileExperienceLevelDto.intermediate:
      return 'Playing regularly';
    case rust_profiles.ProfileExperienceLevelDto.teacher:
      return 'Teaching';
  }
}

String _preferredViewLabel(rust_profiles.ProfilePracticeViewDto? view) {
  switch (view) {
    case rust_profiles.ProfilePracticeViewDto.noteHighway:
      return 'Note highway';
    case rust_profiles.ProfilePracticeViewDto.notation:
      return 'Notation';
    case null:
      return 'Not set';
  }
}

String _avatarInitial(rust_profiles.PlayerProfileDto profile) {
  final source = profile.avatar?.trim().isNotEmpty == true
      ? profile.avatar!
      : profile.name;
  return source.characters.first.toUpperCase();
}
