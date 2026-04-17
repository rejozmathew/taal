import 'package:flutter/material.dart';
import 'package:taal/features/profiles/local_profile_store.dart';
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

const _avatarChoices = <String>['sticks', 'snare', 'metronome', 'cymbal'];

class ProfileHomeScreen extends StatefulWidget {
  const ProfileHomeScreen({super.key});

  @override
  State<ProfileHomeScreen> createState() => _ProfileHomeScreenState();
}

class _ProfileHomeScreenState extends State<ProfileHomeScreen> {
  final _nameController = TextEditingController();

  LocalProfileStore? _store;
  rust_profiles.LocalProfileStateDto? _state;
  rust_profiles.ProfileExperienceLevelDto _experience =
      rust_profiles.ProfileExperienceLevelDto.beginner;
  String? _avatar = _avatarChoices.first;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final store = await LocalProfileStore.open();
      final state = store.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _store = store;
        _state = state;
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

  Future<void> _runProfileOperation(
    rust_profiles.LocalProfileStateDto Function(LocalProfileStore store)
    operation,
  ) async {
    final store = _store;
    if (store == null || _busy) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = operation(store);
      if (!mounted) {
        return;
      }
      setState(() {
        _state = state;
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

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final activeProfile = state == null ? null : _activeProfile(state);

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
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 880),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Who is playing?',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activeProfile == null
                              ? 'Create a local profile to keep practice history, kit mappings, and preferences separate.'
                              : 'Welcome back, ${activeProfile.name}.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          _ErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 24),
                        if (state != null && state.profiles.isNotEmpty) ...[
                          _ProfileSwitcher(
                            state: state,
                            busy: _busy,
                            onSwitch: (profileId) => _runProfileOperation(
                              (store) => store.switchProfile(profileId),
                            ),
                            onDelete: _confirmDeleteProfile,
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (activeProfile != null) ...[
                          _ActiveProfilePanel(
                            profile: activeProfile,
                            busy: _busy,
                            onPreferredViewChanged: (preferredView) {
                              _runProfileOperation(
                                (store) => store.setPreferredView(
                                  profileId: activeProfile.id,
                                  preferredView: preferredView,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                        _CreateProfilePanel(
                          nameController: _nameController,
                          avatar: _avatar,
                          experience: _experience,
                          busy: _busy,
                          onAvatarChanged: (avatar) {
                            setState(() {
                              _avatar = avatar;
                            });
                          },
                          onExperienceChanged: (experience) {
                            setState(() {
                              _experience = experience;
                            });
                          },
                          onCreate: _createProfile,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
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

  void _createProfile() {
    _runProfileOperation((store) {
      final state = store.createProfile(
        name: _nameController.text,
        avatar: _avatar,
        experienceLevel: _experience,
      );
      _nameController.clear();
      _avatar = _avatarChoices.first;
      _experience = rust_profiles.ProfileExperienceLevelDto.beginner;
      return state;
    });
  }

  Future<void> _confirmDeleteProfile(
    rust_profiles.PlayerProfileDto profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete ${profile.name}?'),
          content: const Text(
            'This removes this player and all data owned by that profile.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _runProfileOperation((store) => store.deleteProfile(profile.id));
  }
}

class _ProfileSwitcher extends StatelessWidget {
  const _ProfileSwitcher({
    required this.state,
    required this.busy,
    required this.onSwitch,
    required this.onDelete,
  });

  final rust_profiles.LocalProfileStateDto state;
  final bool busy;
  final ValueChanged<String> onSwitch;
  final ValueChanged<rust_profiles.PlayerProfileDto> onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Switch profile', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final profile in state.profiles)
              InputChip(
                selected: profile.id == state.activeProfileId,
                label: Text(profile.name),
                avatar: CircleAvatar(
                  child: Text(_avatarInitial(profile.avatar ?? profile.name)),
                ),
                onPressed: busy ? null : () => onSwitch(profile.id),
                onDeleted: busy ? null : () => onDelete(profile),
                deleteIcon: const Icon(Icons.close),
                deleteButtonTooltipMessage: 'Delete ${profile.name}',
              ),
          ],
        ),
      ],
    );
  }
}

class _ActiveProfilePanel extends StatelessWidget {
  const _ActiveProfilePanel({
    required this.profile,
    required this.busy,
    required this.onPreferredViewChanged,
  });

  final rust_profiles.PlayerProfileDto profile;
  final bool busy;
  final ValueChanged<rust_profiles.ProfilePracticeViewDto>
  onPreferredViewChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active profile',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              profile.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(_experienceLabel(profile.experienceLevel)),
            const SizedBox(height: 16),
            Text(
              'Preferred practice view',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<rust_profiles.ProfilePracticeViewDto>(
              segments: const [
                ButtonSegment(
                  value: rust_profiles.ProfilePracticeViewDto.noteHighway,
                  label: Text('Note highway'),
                ),
                ButtonSegment(
                  value: rust_profiles.ProfilePracticeViewDto.notation,
                  label: Text('Notation'),
                ),
              ],
              selected: {profile.preferredView},
              onSelectionChanged: busy
                  ? null
                  : (selection) => onPreferredViewChanged(selection.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateProfilePanel extends StatelessWidget {
  const _CreateProfilePanel({
    required this.nameController,
    required this.avatar,
    required this.experience,
    required this.busy,
    required this.onAvatarChanged,
    required this.onExperienceChanged,
    required this.onCreate,
  });

  final TextEditingController nameController;
  final String? avatar;
  final rust_profiles.ProfileExperienceLevelDto experience;
  final bool busy;
  final ValueChanged<String?> onAvatarChanged;
  final ValueChanged<rust_profiles.ProfileExperienceLevelDto>
  onExperienceChanged;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add player', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Player name',
              ),
              onSubmitted: (_) {
                if (!busy) {
                  onCreate();
                }
              },
            ),
            const SizedBox(height: 16),
            Text('Avatar', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in _avatarChoices)
                  ChoiceChip(
                    selected: avatar == choice,
                    label: Text(_avatarLabel(choice)),
                    onSelected: busy
                        ? null
                        : (selected) =>
                              onAvatarChanged(selected ? choice : null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Experience', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<rust_profiles.ProfileExperienceLevelDto>(
              segments: const [
                ButtonSegment(
                  value: rust_profiles.ProfileExperienceLevelDto.beginner,
                  label: Text('Just starting'),
                ),
                ButtonSegment(
                  value: rust_profiles.ProfileExperienceLevelDto.intermediate,
                  label: Text('Playing regularly'),
                ),
                ButtonSegment(
                  value: rust_profiles.ProfileExperienceLevelDto.teacher,
                  label: Text('Teaching'),
                ),
              ],
              selected: {experience},
              onSelectionChanged: busy
                  ? null
                  : (selection) => onExperienceChanged(selection.first),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : onCreate,
              child: Text(busy ? 'Saving...' : 'Create profile'),
            ),
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

String _avatarInitial(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '?';
  }
  return trimmed.characters.first.toUpperCase();
}

String _avatarLabel(String avatar) {
  switch (avatar) {
    case 'sticks':
      return 'Sticks';
    case 'snare':
      return 'Snare';
    case 'metronome':
      return 'Metronome';
    case 'cymbal':
      return 'Cymbal';
    default:
      return avatar;
  }
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
