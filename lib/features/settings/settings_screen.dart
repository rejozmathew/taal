import 'package:flutter/material.dart';
import 'package:taal/features/settings/settings_store.dart';
import 'package:taal/platform/audio/metronome_audio.dart' as audio;
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

class TaalSettingsScreen extends StatefulWidget {
  const TaalSettingsScreen({
    super.key,
    required this.store,
    required this.profileState,
    required this.activeProfile,
    required this.busy,
    required this.onSwitchProfile,
    required this.onProfileStateChanged,
    this.error,
    this.onRecalibrate,
    this.metronomeAudioOutput,
  });

  final SettingsScreenStore store;
  final rust_profiles.LocalProfileStateDto profileState;
  final rust_profiles.PlayerProfileDto? activeProfile;
  final bool busy;
  final String? error;
  final ValueChanged<String> onSwitchProfile;
  final ValueChanged<rust_profiles.LocalProfileStateDto> onProfileStateChanged;
  final VoidCallback? onRecalibrate;
  final audio.MetronomeAudioOutput? metronomeAudioOutput;

  @override
  State<TaalSettingsScreen> createState() => _TaalSettingsScreenState();
}

class _TaalSettingsScreenState extends State<TaalSettingsScreen> {
  final _nameController = TextEditingController();

  SettingsSnapshot? _snapshot;
  List<DeviceProfileSettings> _devices = const [];
  String? _error;
  bool _loading = true;
  bool _saving = false;
  double? _draftOffsetMs;
  double? _draftMetronomeVolume;
  String? _previewText;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void didUpdateWidget(covariant TaalSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeProfile?.id != widget.activeProfile?.id ||
        oldWidget.store != widget.store) {
      _load();
    } else if (oldWidget.activeProfile?.name != widget.activeProfile?.name) {
      _nameController.text = widget.activeProfile?.name ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _load({bool initial = false}) {
    if (!initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final profile = widget.activeProfile;
    if (profile == null) {
      _nameController.clear();
      _snapshot = null;
      _devices = const [];
      _loading = false;
      return;
    }

    try {
      final snapshot = widget.store.loadSettings(profile.id);
      final devices = widget.store.listDeviceProfiles(profile.id);
      _nameController.text = profile.name;
      _draftOffsetMs = _activeDevice(snapshot, devices)?.inputOffsetMs;
      _draftMetronomeVolume = snapshot.profile.metronomeVolume;
      _snapshot = snapshot;
      _devices = devices;
      _loading = false;
      _error = null;
    } on Object catch (error) {
      _snapshot = null;
      _devices = const [];
      _loading = false;
      _error = error.toString();
    }

    if (!initial && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.activeProfile;
    final snapshot = _snapshot;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      key: const ValueKey('app-shell-section-settings'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          profile == null
              ? 'Create a local profile to configure practice.'
              : 'Settings for ${profile.name}.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        if (widget.error != null || _error != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(message: widget.error ?? _error!),
        ],
        const SizedBox(height: 24),
        _ProfileSection(
          profileState: widget.profileState,
          activeProfile: profile,
          busy: widget.busy || _saving,
          nameController: _nameController,
          onSwitchProfile: widget.onSwitchProfile,
          onSaveName: profile == null ? null : () => _saveProfileName(profile),
        ),
        if (snapshot != null) ...[
          const SizedBox(height: 16),
          _MidiSection(
            snapshot: snapshot,
            devices: _devices,
            draftOffsetMs: _draftOffsetMs,
            saving: _saving,
            previewText: _previewText,
            onSelectDeviceProfile: _selectDeviceProfile,
            onChangeVelocityCurve: _changeVelocityCurve,
            onOffsetChanged: (value) => setState(() {
              _draftOffsetMs = value;
            }),
            onOffsetChangeEnd: _changeInputOffset,
            onPreviewTap: _previewLatency,
            onRecalibrate: widget.onRecalibrate,
          ),
          const SizedBox(height: 16),
          _AudioSection(
            profile: snapshot.profile,
            draftVolume: _draftMetronomeVolume,
            saving: _saving,
            onVolumeChanged: (value) => setState(() {
              _draftMetronomeVolume = value;
            }),
            onVolumeChangeEnd: _changeMetronomeVolume,
            onClickSoundChanged: _changeClickSound,
            onPlayKitHitSoundsChanged: (value) => _saveProfileSettings(
              snapshot.profile.toUpdate().copyWith(playKitHitSounds: value),
              refreshProfiles: true,
            ),
          ),
          const SizedBox(height: 16),
          _DisplaySection(
            settings: snapshot.profile,
            saving: _saving,
            onPreferredViewChanged: (value) => _saveProfileSettings(
              snapshot.profile.toUpdate().copyWith(preferredView: value),
              refreshProfiles: true,
            ),
            onThemeChanged: (value) => _saveProfileSettings(
              snapshot.profile.toUpdate().copyWith(theme: value),
            ),
            onReduceMotionChanged: (value) => _saveProfileSettings(
              snapshot.profile.toUpdate().copyWith(reduceMotion: value),
            ),
            onHighContrastChanged: (value) => _saveProfileSettings(
              snapshot.profile.toUpdate().copyWith(highContrast: value),
            ),
          ),
          const SizedBox(height: 16),
          _PracticePreferencesSection(
            settings: snapshot.profile,
            saving: _saving,
            onAutoPauseChanged: (value) => _saveProfileSettings(
              snapshot.profile.toUpdate().copyWith(autoPauseEnabled: value),
            ),
            onAutoPauseTimeoutChanged: (value) => _saveProfileSettings(
              snapshot.profile.toUpdate().copyWith(
                autoPauseTimeoutMs: value.round(),
              ),
            ),
            onRecordPracticeChanged: (value) => _saveProfileSettings(
              snapshot.profile.toUpdate().copyWith(
                recordPracticeModeAttempts: value,
              ),
            ),
            onDailyGoalChanged: (value) => _saveProfileSettings(
              snapshot.profile.toUpdate().copyWith(
                dailyGoalMinutes: value.round(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _saveProfileSettings(
    ProfileSettingsUpdate update, {
    bool refreshProfiles = false,
  }) async {
    final profile = widget.activeProfile;
    if (profile == null || _saving) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = widget.store.updateProfileSettings(
        playerId: profile.id,
        update: update,
      );
      await _applyMetronomeSettings(updated);
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = SettingsSnapshot(app: _snapshot!.app, profile: updated);
        _draftMetronomeVolume = updated.metronomeVolume;
        _saving = false;
      });
      if (refreshProfiles) {
        _load();
      }
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  Future<void> _applyMetronomeSettings(ProfileSettings settings) async {
    final output = widget.metronomeAudioOutput;
    if (output == null) {
      return;
    }
    await output.configure(
      audio.MetronomeAudioSettings(
        volume: settings.metronomeVolume,
        preset: settings.metronomeClickSound.toAudioPreset(),
      ),
    );
  }

  void _selectDeviceProfile(String value) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return;
    }
    final clear = value.isEmpty;
    _saveProfileSettings(
      snapshot.profile.toUpdate().copyWith(
        activeDeviceProfileId: clear ? null : value,
        clearActiveDeviceProfileId: clear,
      ),
    );
  }

  Future<void> _changeInputOffset(double value) async {
    final snapshot = _snapshot;
    final active = _activeDevice(snapshot, _devices);
    final profile = widget.activeProfile;
    if (snapshot == null || active == null || profile == null || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = widget.store.updateDeviceProfileSettings(
        playerId: profile.id,
        deviceProfileId: active.id,
        inputOffsetMs: value,
        velocityCurve: active.velocityCurve.editableOrLinear,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = _replaceDevice(_devices, updated);
        _draftOffsetMs = updated.inputOffsetMs;
        _saving = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  Future<void> _changeVelocityCurve(DeviceVelocityCurve value) async {
    final snapshot = _snapshot;
    final active = _activeDevice(snapshot, _devices);
    final profile = widget.activeProfile;
    if (snapshot == null || active == null || profile == null || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = widget.store.updateDeviceProfileSettings(
        playerId: profile.id,
        deviceProfileId: active.id,
        inputOffsetMs: _draftOffsetMs ?? active.inputOffsetMs,
        velocityCurve: value,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = _replaceDevice(_devices, updated);
        _draftOffsetMs = updated.inputOffsetMs;
        _saving = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  Future<void> _changeMetronomeVolume(double value) async {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return;
    }
    await _saveProfileSettings(
      snapshot.profile.toUpdate().copyWith(metronomeVolume: value),
    );
  }

  void _changeClickSound(SettingsClickSoundPreset value) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return;
    }
    _saveProfileSettings(
      snapshot.profile.toUpdate().copyWith(metronomeClickSound: value),
    );
  }

  void _saveProfileName(rust_profiles.PlayerProfileDto profile) {
    if (_saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final state = widget.store.updatePlayerProfileName(
        profileId: profile.id,
        name: _nameController.text,
      );
      widget.onProfileStateChanged(state);
      setState(() {
        _saving = false;
      });
    } on Object catch (error) {
      setState(() {
        _error = error.toString();
        _saving = false;
      });
    }
  }

  void _previewLatency() {
    final offset = (_draftOffsetMs ?? 0).toStringAsFixed(1);
    setState(() {
      _previewText = 'Tap with the click. Current input offset: $offset ms.';
    });
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.profileState,
    required this.activeProfile,
    required this.busy,
    required this.nameController,
    required this.onSwitchProfile,
    required this.onSaveName,
  });

  final rust_profiles.LocalProfileStateDto profileState;
  final rust_profiles.PlayerProfileDto? activeProfile;
  final bool busy;
  final TextEditingController nameController;
  final ValueChanged<String> onSwitchProfile;
  final VoidCallback? onSaveName;

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      title: 'Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (activeProfile != null) ...[
            TextField(
              key: const ValueKey('settings-profile-name'),
              controller: nameController,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Profile name'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('settings-save-profile-name'),
              onPressed: busy ? null : onSaveName,
              child: const Text('Save name'),
            ),
            const SizedBox(height: 16),
          ],
          if (profileState.profiles.isEmpty)
            const Text('Create a profile to save settings.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final profile in profileState.profiles)
                  InputChip(
                    key: ValueKey('profile-switch-${profile.id}'),
                    selected: profile.id == profileState.activeProfileId,
                    label: Text(profile.name),
                    onPressed: busy ? null : () => onSwitchProfile(profile.id),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MidiSection extends StatelessWidget {
  const _MidiSection({
    required this.snapshot,
    required this.devices,
    required this.draftOffsetMs,
    required this.saving,
    required this.previewText,
    required this.onSelectDeviceProfile,
    required this.onChangeVelocityCurve,
    required this.onOffsetChanged,
    required this.onOffsetChangeEnd,
    required this.onPreviewTap,
    required this.onRecalibrate,
  });

  final SettingsSnapshot snapshot;
  final List<DeviceProfileSettings> devices;
  final double? draftOffsetMs;
  final bool saving;
  final String? previewText;
  final ValueChanged<String> onSelectDeviceProfile;
  final ValueChanged<DeviceVelocityCurve> onChangeVelocityCurve;
  final ValueChanged<double> onOffsetChanged;
  final ValueChanged<double> onOffsetChangeEnd;
  final VoidCallback onPreviewTap;
  final VoidCallback? onRecalibrate;

  @override
  Widget build(BuildContext context) {
    final activeDevice = _activeDevice(snapshot, devices);
    final activeId = snapshot.profile.activeDeviceProfileId ?? '';
    final offset = draftOffsetMs ?? activeDevice?.inputOffsetMs ?? 0.0;

    return _SettingsGroup(
      title: 'MIDI',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            key: const ValueKey('settings-active-device-profile'),
            isExpanded: true,
            initialValue: devices.any((device) => device.id == activeId)
                ? activeId
                : '',
            decoration: const InputDecoration(labelText: 'Kit profile'),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('No active kit profile'),
              ),
              for (final device in devices)
                DropdownMenuItem(value: device.id, child: Text(device.name)),
            ],
            onChanged: saving
                ? null
                : (value) => onSelectDeviceProfile(value ?? ''),
          ),
          const SizedBox(height: 12),
          Text(
            activeDevice == null
                ? 'No saved MIDI mapping selected.'
                : '${activeDevice.mappingCount} mapped notes for ${activeDevice.layoutId}.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Manual latency: ${offset.toStringAsFixed(1)} ms'),
              ),
              OutlinedButton(
                key: const ValueKey('settings-preview-latency'),
                onPressed: activeDevice == null || saving ? null : onPreviewTap,
                child: const Text('Preview tap'),
              ),
            ],
          ),
          Slider(
            key: const ValueKey('settings-latency-slider'),
            min: -50,
            max: 50,
            divisions: 200,
            value: offset.clamp(-50.0, 50.0).toDouble(),
            label: '${offset.toStringAsFixed(1)} ms',
            onChanged: activeDevice == null || saving ? null : onOffsetChanged,
            onChangeEnd: activeDevice == null || saving
                ? null
                : onOffsetChangeEnd,
          ),
          if (previewText != null) Text(previewText!),
          const SizedBox(height: 12),
          DropdownButtonFormField<DeviceVelocityCurve>(
            key: const ValueKey('settings-velocity-curve'),
            isExpanded: true,
            initialValue: activeDevice?.velocityCurve.editableDropdownValue,
            decoration: const InputDecoration(labelText: 'Velocity curve'),
            items: const [
              DropdownMenuItem(
                value: DeviceVelocityCurve.linear,
                child: Text('Linear'),
              ),
              DropdownMenuItem(
                value: DeviceVelocityCurve.soft,
                child: Text('Soft'),
              ),
              DropdownMenuItem(
                value: DeviceVelocityCurve.hard,
                child: Text('Hard'),
              ),
            ],
            hint: Text(
              activeDevice?.velocityCurve.label ?? 'No active profile',
            ),
            onChanged: activeDevice == null || saving
                ? null
                : (value) {
                    if (value != null) {
                      onChangeVelocityCurve(value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('settings-recalibrate'),
            onPressed: saving ? null : onRecalibrate,
            child: const Text('Recalibrate'),
          ),
        ],
      ),
    );
  }
}

class _AudioSection extends StatelessWidget {
  const _AudioSection({
    required this.profile,
    required this.draftVolume,
    required this.saving,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
    required this.onClickSoundChanged,
    required this.onPlayKitHitSoundsChanged,
  });

  final ProfileSettings profile;
  final double? draftVolume;
  final bool saving;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;
  final ValueChanged<SettingsClickSoundPreset> onClickSoundChanged;
  final ValueChanged<bool> onPlayKitHitSoundsChanged;

  @override
  Widget build(BuildContext context) {
    final volume = draftVolume ?? profile.metronomeVolume;

    return _SettingsGroup(
      title: 'Audio',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Metronome volume: ${(volume * 100).round()}%'),
          Slider(
            key: const ValueKey('settings-metronome-volume'),
            min: 0,
            max: 1,
            divisions: 20,
            value: volume.clamp(0.0, 1.0).toDouble(),
            onChanged: saving ? null : onVolumeChanged,
            onChangeEnd: saving ? null : onVolumeChangeEnd,
          ),
          DropdownButtonFormField<SettingsClickSoundPreset>(
            key: const ValueKey('settings-click-sound'),
            isExpanded: true,
            initialValue: profile.metronomeClickSound,
            decoration: const InputDecoration(labelText: 'Click sound'),
            items: [
              for (final preset in SettingsClickSoundPreset.values)
                DropdownMenuItem(value: preset, child: Text(preset.label)),
            ],
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) {
                      onClickSoundChanged(value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const ValueKey('settings-play-kit-hit-sounds'),
            title: const Text('Play drum sounds on kit hits'),
            subtitle: const Text(
              'When off, app stays silent for MIDI kit hits to avoid doubling',
            ),
            value: profile.playKitHitSounds,
            onChanged: saving ? null : onPlayKitHitSoundsChanged,
          ),
          const SizedBox(height: 12),
          ListTile(
            key: const ValueKey('settings-audio-output-device'),
            title: const Text('Output device'),
            subtitle: const Text('System Default'),
            enabled: false,
          ),
        ],
      ),
    );
  }
}

class _DisplaySection extends StatelessWidget {
  const _DisplaySection({
    required this.settings,
    required this.saving,
    required this.onPreferredViewChanged,
    required this.onThemeChanged,
    required this.onReduceMotionChanged,
    required this.onHighContrastChanged,
  });

  final ProfileSettings settings;
  final bool saving;
  final ValueChanged<SettingsPracticeView> onPreferredViewChanged;
  final ValueChanged<ThemePreference> onThemeChanged;
  final ValueChanged<bool> onReduceMotionChanged;
  final ValueChanged<bool> onHighContrastChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      title: 'Display',
      child: Column(
        children: [
          DropdownButtonFormField<SettingsPracticeView>(
            key: const ValueKey('settings-preferred-view'),
            isExpanded: true,
            initialValue: settings.preferredView,
            decoration: const InputDecoration(labelText: 'Preferred view'),
            items: [
              for (final view in SettingsPracticeView.values)
                DropdownMenuItem(value: view, child: Text(view.label)),
            ],
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) {
                      onPreferredViewChanged(value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ThemePreference>(
            key: const ValueKey('settings-theme'),
            isExpanded: true,
            initialValue: settings.theme,
            decoration: const InputDecoration(labelText: 'Theme'),
            items: [
              for (final theme in ThemePreference.values)
                DropdownMenuItem(value: theme, child: Text(theme.label)),
            ],
            onChanged: saving
                ? null
                : (value) {
                    if (value != null) {
                      onThemeChanged(value);
                    }
                  },
          ),
          SwitchListTile(
            key: const ValueKey('settings-reduce-motion'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce motion'),
            value: settings.reduceMotion,
            onChanged: saving ? null : onReduceMotionChanged,
          ),
          SwitchListTile(
            key: const ValueKey('settings-high-contrast'),
            contentPadding: EdgeInsets.zero,
            title: const Text('High contrast'),
            value: settings.highContrast,
            onChanged: saving ? null : onHighContrastChanged,
          ),
        ],
      ),
    );
  }
}

class _PracticePreferencesSection extends StatelessWidget {
  const _PracticePreferencesSection({
    required this.settings,
    required this.saving,
    required this.onAutoPauseChanged,
    required this.onAutoPauseTimeoutChanged,
    required this.onRecordPracticeChanged,
    required this.onDailyGoalChanged,
  });

  final ProfileSettings settings;
  final bool saving;
  final ValueChanged<bool> onAutoPauseChanged;
  final ValueChanged<double> onAutoPauseTimeoutChanged;
  final ValueChanged<bool> onRecordPracticeChanged;
  final ValueChanged<double> onDailyGoalChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      title: 'Practice',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: const ValueKey('settings-auto-pause'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-pause'),
            subtitle: const Text(
              'Off by default. Used by Practice Mode later.',
            ),
            value: settings.autoPauseEnabled,
            onChanged: saving ? null : onAutoPauseChanged,
          ),
          Text('Auto-pause timeout: ${settings.autoPauseTimeoutMs} ms'),
          Slider(
            key: const ValueKey('settings-auto-pause-timeout'),
            min: 1000,
            max: 10000,
            divisions: 9,
            value: settings.autoPauseTimeoutMs
                .toDouble()
                .clamp(1000.0, 10000.0)
                .toDouble(),
            onChanged: saving ? null : onAutoPauseTimeoutChanged,
          ),
          SwitchListTile(
            key: const ValueKey('settings-record-practice-attempts'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Save Practice Mode attempts'),
            value: settings.recordPracticeModeAttempts,
            onChanged: saving ? null : onRecordPracticeChanged,
          ),
          const SizedBox(height: 8),
          Text('Daily goal: ${settings.dailyGoalMinutes} min'),
          Slider(
            key: const ValueKey('settings-daily-goal-minutes'),
            min: 1,
            max: 120,
            divisions: 119,
            value: settings.dailyGoalMinutes
                .toDouble()
                .clamp(1.0, 120.0)
                .toDouble(),
            label: '${settings.dailyGoalMinutes} min',
            onChanged: saving ? null : onDailyGoalChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.child});

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
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}

DeviceProfileSettings? _activeDevice(
  SettingsSnapshot? snapshot,
  List<DeviceProfileSettings> devices,
) {
  final activeId = snapshot?.profile.activeDeviceProfileId;
  if (activeId == null) {
    return null;
  }
  for (final device in devices) {
    if (device.id == activeId) {
      return device;
    }
  }
  return null;
}

List<DeviceProfileSettings> _replaceDevice(
  List<DeviceProfileSettings> devices,
  DeviceProfileSettings updated,
) {
  return [
    for (final device in devices)
      if (device.id == updated.id) updated else device,
  ];
}

extension on DeviceVelocityCurve {
  DeviceVelocityCurve? get editableDropdownValue {
    switch (this) {
      case DeviceVelocityCurve.linear:
      case DeviceVelocityCurve.soft:
      case DeviceVelocityCurve.hard:
        return this;
      case DeviceVelocityCurve.custom:
        return null;
    }
  }

  DeviceVelocityCurve get editableOrLinear {
    switch (this) {
      case DeviceVelocityCurve.linear:
      case DeviceVelocityCurve.soft:
      case DeviceVelocityCurve.hard:
        return this;
      case DeviceVelocityCurve.custom:
        return DeviceVelocityCurve.linear;
    }
  }
}

extension on SettingsClickSoundPreset {
  audio.ClickSoundPreset toAudioPreset() {
    switch (this) {
      case SettingsClickSoundPreset.classic:
        return audio.ClickSoundPreset.classic;
      case SettingsClickSoundPreset.woodblock:
        return audio.ClickSoundPreset.woodblock;
      case SettingsClickSoundPreset.hiHat:
        return audio.ClickSoundPreset.hihat;
    }
  }
}
