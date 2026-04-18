import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';
import 'package:taal/features/player/practice_mode/practice_mode_screen.dart';
import 'package:taal/features/player/tap_pads/tap_pad_surface.dart';
import 'package:taal/platform/midi/midi_adapter.dart';
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

typedef OnboardingCreateProfile =
    FutureOr<rust_profiles.LocalProfileStateDto> Function({
      required String name,
      required String? avatar,
      required rust_profiles.ProfileExperienceLevelDto experienceLevel,
    });

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onCreateProfile,
    required this.onComplete,
    this.midiAdapter,
  });

  final OnboardingCreateProfile onCreateProfile;
  final ValueChanged<rust_profiles.LocalProfileStateDto> onComplete;
  final Phase0MidiAdapter? midiAdapter;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _nameController = TextEditingController();
  late final Phase0MidiAdapter _midiAdapter;

  _OnboardingStep _step = _OnboardingStep.welcome;
  rust_profiles.ProfileExperienceLevelDto _experience =
      rust_profiles.ProfileExperienceLevelDto.beginner;
  rust_profiles.LocalProfileStateDto? _profileState;
  List<MidiInputDevice> _devices = const [];
  int? _selectedDeviceId;
  bool _loadingDevices = true;
  bool _busy = false;
  bool _demoMode = true;
  String? _avatar = 'sticks';
  String? _error;
  String? _lastPadHit;

  @override
  void initState() {
    super.initState();
    _midiAdapter = widget.midiAdapter ?? createPhase0MidiAdapter();
    _loadDevices();
  }

  @override
  void dispose() {
    _nameController.dispose();
    unawaited(_midiAdapter.closeDevice());
    super.dispose();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await _midiAdapter.listDevices();
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = devices;
        _selectedDeviceId = devices.isEmpty ? null : devices.first.id;
        _demoMode = devices.isEmpty;
        _loadingDevices = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _devices = const [];
        _selectedDeviceId = null;
        _demoMode = true;
        _loadingDevices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('onboarding-flow'),
      appBar: AppBar(title: const Text('Taal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Step ${_step.index + 1} of ${_OnboardingStep.values.length}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_error != null) ...[
                      _OnboardingBanner(message: _error!),
                      const SizedBox(height: 16),
                    ],
                    _buildStep(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context) {
    switch (_step) {
      case _OnboardingStep.welcome:
        return _WelcomeStep(
          onNext: () => _goTo(_OnboardingStep.profile),
          onSkip: () => _goTo(_OnboardingStep.profile),
        );
      case _OnboardingStep.profile:
        return _ProfileStep(
          nameController: _nameController,
          avatar: _avatar,
          busy: _busy,
          onAvatarChanged: (avatar) => setState(() {
            _avatar = avatar;
          }),
          onNext: () => _goTo(_OnboardingStep.experience),
          onSkip: () {
            if (_nameController.text.trim().isEmpty) {
              _nameController.text = 'Guest';
            }
            _goTo(_OnboardingStep.experience);
          },
        );
      case _OnboardingStep.experience:
        return _ExperienceStep(
          experience: _experience,
          busy: _busy,
          onExperienceChanged: (value) => setState(() {
            _experience = value;
          }),
          onNext: _createProfileAndContinue,
          onSkip: () {
            _experience = rust_profiles.ProfileExperienceLevelDto.beginner;
            _createProfileAndContinue();
          },
        );
      case _OnboardingStep.connectKit:
        return _ConnectKitStep(
          loading: _loadingDevices,
          devices: _devices,
          selectedDeviceId: _selectedDeviceId,
          demoMode: _demoMode,
          onDeviceSelected: (deviceId) => setState(() {
            _selectedDeviceId = deviceId;
            _demoMode = false;
          }),
          onUseSelectedKit: _selectedDeviceId == null
              ? null
              : () {
                  setState(() {
                    _demoMode = false;
                  });
                  _goTo(_OnboardingStep.calibrate);
                },
          onUseTapPads: () {
            setState(() {
              _demoMode = true;
            });
            _goTo(_OnboardingStep.calibrate);
          },
          onSkip: () {
            setState(() {
              _demoMode = true;
            });
            _goTo(_OnboardingStep.calibrate);
          },
        );
      case _OnboardingStep.calibrate:
        return _CalibrateStep(
          demoMode: _demoMode,
          selectedDevice: _selectedDevice(),
          onNext: () => _goTo(_OnboardingStep.firstLesson),
          onSkip: () => _goTo(_OnboardingStep.firstLesson),
        );
      case _OnboardingStep.firstLesson:
        return _FirstLessonStep(
          lesson: starterLessonForExperience(_experience),
          demoMode: _demoMode,
          lastPadHit: _lastPadHit,
          onPadHit: (hit) => setState(() {
            _lastPadHit = hit.laneId;
          }),
          onComplete: _profileState == null
              ? null
              : () => widget.onComplete(_profileState!),
        );
    }
  }

  Future<void> _createProfileAndContinue() async {
    if (_busy) {
      return;
    }
    final name = _nameController.text.trim().isEmpty
        ? 'Guest'
        : _nameController.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final state = await Future.value(
        widget.onCreateProfile(
          name: name,
          avatar: _avatar,
          experienceLevel: _experience,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _profileState = state;
        _busy = false;
        _step = _OnboardingStep.connectKit;
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

  void _goTo(_OnboardingStep step) {
    setState(() {
      _step = step;
      _error = null;
    });
  }

  MidiInputDevice? _selectedDevice() {
    final id = _selectedDeviceId;
    if (id == null) {
      return null;
    }
    for (final device in _devices) {
      if (device.id == id) {
        return device;
      }
    }
    return null;
  }
}

enum _OnboardingStep {
  welcome,
  profile,
  experience,
  connectKit,
  calibrate,
  firstLesson,
}

class OnboardingStarterLesson {
  const OnboardingStarterLesson({
    required this.title,
    required this.detail,
    required this.bpm,
    required this.totalDurationMs,
    required this.lanes,
    required this.notes,
    required this.sections,
  });

  final String title;
  final String detail;
  final double bpm;
  final double totalDurationMs;
  final List<NoteHighwayLane> lanes;
  final List<PracticeTimelineNote> notes;
  final List<PracticeSection> sections;
}

OnboardingStarterLesson starterLessonForExperience(
  rust_profiles.ProfileExperienceLevelDto experience,
) {
  switch (experience) {
    case rust_profiles.ProfileExperienceLevelDto.beginner:
      return _beginnerLesson;
    case rust_profiles.ProfileExperienceLevelDto.intermediate:
      return _intermediateLesson;
    case rust_profiles.ProfileExperienceLevelDto.teacher:
      return _teacherLesson;
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onNext, required this.onSkip});

  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPanel(
      key: const ValueKey('onboarding-step-welcome'),
      title: 'Welcome to Taal',
      subtitle: 'Free drum practice with real-time feedback.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a local profile, connect a kit when one is available, and start a short starter lesson.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('onboarding-get-started'),
                onPressed: onNext,
                child: const Text('Get started'),
              ),
              TextButton(onPressed: onSkip, child: const Text('Skip intro')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.nameController,
    required this.avatar,
    required this.busy,
    required this.onAvatarChanged,
    required this.onNext,
    required this.onSkip,
  });

  final TextEditingController nameController;
  final String? avatar;
  final bool busy;
  final ValueChanged<String?> onAvatarChanged;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPanel(
      key: const ValueKey('onboarding-step-profile'),
      title: 'Who is playing?',
      subtitle: 'Practice history, settings, and kit mappings stay local.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const ValueKey('onboarding-profile-name'),
            controller: nameController,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Player name',
            ),
          ),
          const SizedBox(height: 16),
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
                      : (selected) => onAvatarChanged(selected ? choice : null),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('onboarding-profile-next'),
                onPressed: busy ? null : onNext,
                child: const Text('Continue'),
              ),
              TextButton(
                onPressed: busy ? null : onSkip,
                child: const Text('Skip profile setup'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExperienceStep extends StatelessWidget {
  const _ExperienceStep({
    required this.experience,
    required this.busy,
    required this.onExperienceChanged,
    required this.onNext,
    required this.onSkip,
  });

  final rust_profiles.ProfileExperienceLevelDto experience;
  final bool busy;
  final ValueChanged<rust_profiles.ProfileExperienceLevelDto>
  onExperienceChanged;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPanel(
      key: const ValueKey('onboarding-step-experience'),
      title: 'What is your experience?',
      subtitle: 'This picks the first starter lesson.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                : (selection) => onExperienceChanged(selection.single),
          ),
          const SizedBox(height: 16),
          Text('First lesson: ${starterLessonForExperience(experience).title}'),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('onboarding-experience-next'),
                onPressed: busy ? null : onNext,
                child: Text(busy ? 'Saving...' : 'Continue'),
              ),
              TextButton(
                onPressed: busy ? null : onSkip,
                child: const Text('Skip experience'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectKitStep extends StatelessWidget {
  const _ConnectKitStep({
    required this.loading,
    required this.devices,
    required this.selectedDeviceId,
    required this.demoMode,
    required this.onDeviceSelected,
    required this.onUseSelectedKit,
    required this.onUseTapPads,
    required this.onSkip,
  });

  final bool loading;
  final List<MidiInputDevice> devices;
  final int? selectedDeviceId;
  final bool demoMode;
  final ValueChanged<int> onDeviceSelected;
  final VoidCallback? onUseSelectedKit;
  final VoidCallback onUseTapPads;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return _OnboardingPanel(
      key: const ValueKey('onboarding-step-connect-kit'),
      title: 'Connect your kit',
      subtitle: 'USB MIDI is best. Tap pads are ready when no kit is nearby.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (loading)
            const LinearProgressIndicator()
          else if (devices.isEmpty)
            const Text(
              'No MIDI device found. Demo mode with tap pads is ready.',
            )
          else ...[
            Text('${devices.length} MIDI device found.'),
            const SizedBox(height: 8),
            for (final device in devices)
              RadioListTile<int>(
                key: ValueKey('onboarding-midi-device-${device.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(device.name),
                subtitle: Text(device.productName ?? 'USB MIDI'),
                value: device.id,
                groupValue: selectedDeviceId,
                onChanged: (value) {
                  if (value != null) {
                    onDeviceSelected(value);
                  }
                },
              ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('onboarding-use-selected-kit'),
                onPressed: loading ? null : onUseSelectedKit,
                child: const Text('Use selected kit'),
              ),
              OutlinedButton(
                key: const ValueKey('onboarding-use-tap-pads'),
                onPressed: loading ? null : onUseTapPads,
                child: Text(
                  demoMode ? 'Continue with tap pads' : 'Use tap pads',
                ),
              ),
              TextButton(
                onPressed: loading ? null : onSkip,
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalibrateStep extends StatelessWidget {
  const _CalibrateStep({
    required this.demoMode,
    required this.selectedDevice,
    required this.onNext,
    required this.onSkip,
  });

  final bool demoMode;
  final MidiInputDevice? selectedDevice;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final device = selectedDevice;
    return _OnboardingPanel(
      key: const ValueKey('onboarding-step-calibrate'),
      title: 'Quick calibration',
      subtitle: demoMode
          ? 'Tap pads do not need calibration.'
          : 'Calibration is available when your kit profile is ready.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            demoMode
                ? 'Start in demo mode now. Connect your kit later for the best experience.'
                : '${device?.name ?? 'Your kit'} can be calibrated from Settings after mapping is saved.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('onboarding-calibration-next'),
                onPressed: onNext,
                child: const Text('Continue to first lesson'),
              ),
              TextButton(
                onPressed: onSkip,
                child: const Text('Skip calibration'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FirstLessonStep extends StatelessWidget {
  const _FirstLessonStep({
    required this.lesson,
    required this.demoMode,
    required this.lastPadHit,
    required this.onPadHit,
    required this.onComplete,
  });

  final OnboardingStarterLesson lesson;
  final bool demoMode;
  final String? lastPadHit;
  final ValueChanged<TapPadHit> onPadHit;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final controller = PracticeModeController(
      baseBpm: lesson.bpm,
      totalDurationMs: lesson.totalDurationMs,
      sections: lesson.sections,
    );
    return _OnboardingPanel(
      key: const ValueKey('onboarding-step-first-lesson'),
      title: 'First lesson',
      subtitle: lesson.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lesson.detail),
          if (demoMode) ...[
            const SizedBox(height: 8),
            const Text('Demo mode with tap pads is on.'),
          ],
          if (lastPadHit != null) ...[
            const SizedBox(height: 8),
            Text('Last pad: $lastPadHit'),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 620,
            child: PracticeModeScreen(
              controller: controller,
              lanes: lesson.lanes,
              notes: lesson.notes,
              tapPadInput: PracticeTapPadInput(
                enabledLaneIds: lesson.lanes.map((lane) => lane.laneId).toSet(),
                onPadHit: onPadHit,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('onboarding-finish'),
            onPressed: onComplete,
            child: const Text('Finish onboarding'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPanel extends StatelessWidget {
  const _OnboardingPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _OnboardingBanner extends StatelessWidget {
  const _OnboardingBanner({required this.message});

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

const _avatarChoices = <String>['sticks', 'snare', 'metronome', 'cymbal'];

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

const _starterLanes = [
  NoteHighwayLane(laneId: 'kick', label: 'Kick', color: Color(0xFF16A085)),
  NoteHighwayLane(laneId: 'snare', label: 'Snare', color: Color(0xFFE0B44C)),
  NoteHighwayLane(laneId: 'hihat', label: 'Hi-Hat', color: Color(0xFF5DADE2)),
  NoteHighwayLane(laneId: 'crash', label: 'Crash', color: Color(0xFFD78AD7)),
];

const _beginnerLesson = OnboardingStarterLesson(
  title: 'Basic Rock Beat 1',
  detail: 'Kick on 1 and 3, snare on 2 and 4, steady hi-hats.',
  bpm: 90,
  totalDurationMs: 8000,
  lanes: _starterLanes,
  notes: [
    PracticeTimelineNote(expectedId: 'hh-1', laneId: 'hihat', tMs: 0),
    PracticeTimelineNote(expectedId: 'kick-1', laneId: 'kick', tMs: 0),
    PracticeTimelineNote(expectedId: 'hh-2', laneId: 'hihat', tMs: 667),
    PracticeTimelineNote(expectedId: 'snare-1', laneId: 'snare', tMs: 1333),
    PracticeTimelineNote(expectedId: 'hh-3', laneId: 'hihat', tMs: 1333),
    PracticeTimelineNote(expectedId: 'hh-4', laneId: 'hihat', tMs: 2000),
    PracticeTimelineNote(expectedId: 'kick-2', laneId: 'kick', tMs: 2667),
    PracticeTimelineNote(expectedId: 'hh-5', laneId: 'hihat', tMs: 2667),
    PracticeTimelineNote(expectedId: 'snare-2', laneId: 'snare', tMs: 4000),
    PracticeTimelineNote(expectedId: 'crash-1', laneId: 'crash', tMs: 5333),
  ],
  sections: [
    PracticeSection(
      sectionId: 'main',
      label: 'Main groove',
      startMs: 0,
      endMs: 8000,
    ),
  ],
);

const _intermediateLesson = OnboardingStarterLesson(
  title: 'Syncopated 16ths',
  detail: 'A short kick variation with tighter hi-hat spacing.',
  bpm: 105,
  totalDurationMs: 8000,
  lanes: _starterLanes,
  notes: [
    PracticeTimelineNote(expectedId: 'hh-1', laneId: 'hihat', tMs: 0),
    PracticeTimelineNote(expectedId: 'kick-1', laneId: 'kick', tMs: 0),
    PracticeTimelineNote(expectedId: 'hh-2', laneId: 'hihat', tMs: 286),
    PracticeTimelineNote(expectedId: 'kick-2', laneId: 'kick', tMs: 857),
    PracticeTimelineNote(expectedId: 'snare-1', laneId: 'snare', tMs: 1143),
    PracticeTimelineNote(expectedId: 'hh-3', laneId: 'hihat', tMs: 1143),
    PracticeTimelineNote(expectedId: 'hh-4', laneId: 'hihat', tMs: 1714),
    PracticeTimelineNote(expectedId: 'kick-3', laneId: 'kick', tMs: 2000),
    PracticeTimelineNote(expectedId: 'snare-2', laneId: 'snare', tMs: 3429),
    PracticeTimelineNote(expectedId: 'crash-1', laneId: 'crash', tMs: 4571),
  ],
  sections: [
    PracticeSection(
      sectionId: 'main',
      label: 'Syncopated groove',
      startMs: 0,
      endMs: 8000,
    ),
  ],
);

const _teacherLesson = OnboardingStarterLesson(
  title: 'Teacher Demo Groove',
  detail: 'A compact groove for demonstrating the player views.',
  bpm: 100,
  totalDurationMs: 8000,
  lanes: _starterLanes,
  notes: [
    PracticeTimelineNote(expectedId: 'crash-1', laneId: 'crash', tMs: 0),
    PracticeTimelineNote(expectedId: 'kick-1', laneId: 'kick', tMs: 0),
    PracticeTimelineNote(expectedId: 'hh-1', laneId: 'hihat', tMs: 600),
    PracticeTimelineNote(expectedId: 'snare-1', laneId: 'snare', tMs: 1200),
    PracticeTimelineNote(expectedId: 'kick-2', laneId: 'kick', tMs: 1800),
    PracticeTimelineNote(expectedId: 'hh-2', laneId: 'hihat', tMs: 2400),
    PracticeTimelineNote(expectedId: 'snare-2', laneId: 'snare', tMs: 3000),
    PracticeTimelineNote(expectedId: 'kick-3', laneId: 'kick', tMs: 3600),
    PracticeTimelineNote(expectedId: 'crash-2', laneId: 'crash', tMs: 4800),
  ],
  sections: [
    PracticeSection(
      sectionId: 'main',
      label: 'Demo groove',
      startMs: 0,
      endMs: 8000,
    ),
  ],
);
