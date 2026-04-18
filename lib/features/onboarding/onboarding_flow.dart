import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taal/design/colors.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';
import 'package:taal/features/player/practice_mode/practice_mode_screen.dart';
import 'package:taal/features/player/practice_runtime/practice_runtime.dart';
import 'package:taal/features/player/tap_pads/tap_pad_surface.dart';
import 'package:taal/platform/midi/midi_adapter.dart';
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

typedef OnboardingCreateProfile =
    FutureOr<rust_profiles.LocalProfileStateDto> Function({
      required String name,
      required String? avatar,
      required rust_profiles.ProfileExperienceLevelDto experienceLevel,
    });

typedef OnboardingContentLoader =
    Future<OnboardingLessonContent> Function(OnboardingStarterLesson lesson);

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.onCreateProfile,
    required this.onComplete,
    this.midiAdapter,
    this.runtimeEngine,
    this.contentLoader = loadDefaultOnboardingLessonContent,
  });

  final OnboardingCreateProfile onCreateProfile;
  final ValueChanged<rust_profiles.LocalProfileStateDto> onComplete;
  final Phase0MidiAdapter? midiAdapter;
  final PracticeRuntimeEngine? runtimeEngine;
  final OnboardingContentLoader contentLoader;

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
          selectedDevice: _selectedDevice(),
          midiAdapter: _midiAdapter,
          runtimeEngine: widget.runtimeEngine,
          contentLoader: widget.contentLoader,
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
    required this.assetPath,
    required this.bpm,
    required this.totalDurationMs,
    required this.lanes,
    required this.notes,
    required this.sections,
  });

  final String title;
  final String detail;
  final String assetPath;
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

class OnboardingLessonContent {
  const OnboardingLessonContent({
    required this.lessonJson,
    required this.layoutJson,
    required this.scoringProfileJson,
  });

  final String lessonJson;
  final String layoutJson;
  final String scoringProfileJson;
}

Future<OnboardingLessonContent> loadDefaultOnboardingLessonContent(
  OnboardingStarterLesson lesson,
) async {
  final values = await Future.wait([
    rootBundle.loadString(lesson.assetPath),
    rootBundle.loadString(_standardLayoutAssetPath),
    rootBundle.loadString(_standardScoringAssetPath),
  ]);
  return OnboardingLessonContent(
    lessonJson: values[0],
    layoutJson: values[1],
    scoringProfileJson: values[2],
  );
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
            RadioGroup<int>(
              groupValue: selectedDeviceId,
              onChanged: (value) {
                if (value != null) {
                  onDeviceSelected(value);
                }
              },
              child: Column(
                children: [
                  for (final device in devices)
                    RadioListTile<int>(
                      key: ValueKey('onboarding-midi-device-${device.id}'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(device.name),
                      subtitle: Text(device.productName ?? 'USB MIDI'),
                      value: device.id,
                    ),
                ],
              ),
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

class _FirstLessonStep extends StatefulWidget {
  const _FirstLessonStep({
    required this.lesson,
    required this.demoMode,
    required this.selectedDevice,
    required this.midiAdapter,
    required this.runtimeEngine,
    required this.contentLoader,
    required this.onComplete,
  });

  final OnboardingStarterLesson lesson;
  final bool demoMode;
  final MidiInputDevice? selectedDevice;
  final Phase0MidiAdapter midiAdapter;
  final PracticeRuntimeEngine? runtimeEngine;
  final OnboardingContentLoader contentLoader;
  final VoidCallback? onComplete;

  @override
  State<_FirstLessonStep> createState() => _FirstLessonStepState();
}

class _FirstLessonStepState extends State<_FirstLessonStep> {
  PracticeModeController? _controller;
  PracticeModeRuntimeAdapter? _runtimeAdapter;
  StreamSubscription<MidiNoteOnEvent>? _midiSubscription;
  String? _lastPadHit;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_startLesson());
  }

  @override
  void didUpdateWidget(covariant _FirstLessonStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    final deviceChanged =
        oldWidget.selectedDevice?.id != widget.selectedDevice?.id ||
        oldWidget.demoMode != widget.demoMode;
    if (oldWidget.lesson.assetPath != widget.lesson.assetPath ||
        deviceChanged) {
      unawaited(_startLesson());
    }
  }

  @override
  void dispose() {
    unawaited(_midiSubscription?.cancel());
    _runtimeAdapter?.removeListener(_onRuntimeChanged);
    _runtimeAdapter?.disposeRuntimeSession();
    _controller?.dispose();
    if (!widget.demoMode) {
      unawaited(widget.midiAdapter.closeDevice());
    }
    super.dispose();
  }

  Future<void> _startLesson() async {
    await _midiSubscription?.cancel();
    _midiSubscription = null;
    _runtimeAdapter?.removeListener(_onRuntimeChanged);
    _runtimeAdapter?.disposeRuntimeSession();
    _runtimeAdapter = null;
    _controller?.dispose();
    _controller = null;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _lastPadHit = null;
      });
    }

    try {
      final content = await widget.contentLoader(widget.lesson);
      final controller = PracticeModeController(
        baseBpm: widget.lesson.bpm,
        totalDurationMs: widget.lesson.totalDurationMs,
        sections: widget.lesson.sections,
      );
      final adapter = PracticeModeRuntimeAdapter(
        controller: controller,
        engine: widget.runtimeEngine ?? RustPracticeRuntimeEngine(),
      )..addListener(_onRuntimeChanged);

      adapter.start(
        lessonJson: content.lessonJson,
        layoutJson: content.layoutJson,
        scoringProfileJson: content.scoringProfileJson,
        deviceProfileJson: widget.demoMode
            ? null
            : _defaultOnboardingDeviceProfileJson(
                widget.selectedDevice,
                widget.midiAdapter.platformName,
              ),
        bpm: widget.lesson.bpm,
      );

      if (!widget.demoMode && widget.selectedDevice != null) {
        await widget.midiAdapter.openDevice(widget.selectedDevice!.id);
        _midiSubscription = widget.midiAdapter.noteOnEvents.listen(
          _submitMidiHit,
          onError: (Object error) {
            if (mounted) {
              setState(() {
                _error = error.toString();
              });
            }
          },
        );
      }

      if (!mounted) {
        adapter.disposeRuntimeSession();
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _runtimeAdapter = adapter;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  void _onRuntimeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _submitMidiHit(MidiNoteOnEvent event) {
    if (widget.demoMode || event.deviceId != widget.selectedDevice?.id) {
      return;
    }
    try {
      _runtimeAdapter?.submitMidiNoteOn(
        channel: event.channel,
        note: event.note,
        velocity: event.velocity,
        timestampNs: event.timestampNs,
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  void _submitTapPadHit(TapPadHit hit) {
    setState(() {
      _lastPadHit = hit.laneId;
    });
    try {
      _runtimeAdapter?.submitTouchHit(
        laneId: hit.laneId,
        velocity: hit.velocity,
      );
    } on Object catch (error) {
      setState(() {
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final adapter = _runtimeAdapter;
    final timeline = adapter?.timeline;
    final lanes = timeline?.toNoteHighwayLanes() ?? widget.lesson.lanes;
    final notes = timeline?.toPracticeTimelineNotes() ?? widget.lesson.notes;
    return _OnboardingPanel(
      key: const ValueKey('onboarding-step-first-lesson'),
      title: 'First lesson',
      subtitle: widget.lesson.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.lesson.detail),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _OnboardingBanner(message: _error!),
          ],
          if (widget.demoMode) ...[
            const SizedBox(height: 8),
            const Text('Demo mode with tap pads is on.'),
          ] else if (widget.selectedDevice != null) ...[
            const SizedBox(height: 8),
            Text('Listening to ${widget.selectedDevice!.name}.'),
          ],
          if (_lastPadHit != null) ...[
            const SizedBox(height: 8),
            Text('Last pad: $_lastPadHit'),
          ],
          const SizedBox(height: 16),
          if (_loading || controller == null)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              height: 620,
              child: PracticeModeScreen(
                controller: controller,
                lanes: lanes,
                notes: notes,
                feedback: adapter?.feedback ?? const [],
                layoutCompatibility: timeline?.layoutCompatibility,
                tapPadInput: PracticeTapPadInput(
                  enabledLaneIds: lanes.map((lane) => lane.laneId).toSet(),
                  onPadHit: _submitTapPadHit,
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('onboarding-finish'),
            onPressed: widget.onComplete,
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
const _standardLayoutAssetPath = 'assets/content/layouts/std-5pc-v1.json';
const _standardScoringAssetPath =
    'assets/content/scoring/score-standard-v1.json';

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

String? _defaultOnboardingDeviceProfileJson(
  MidiInputDevice? device,
  String platformName,
) {
  if (device == null) {
    return null;
  }
  final now = DateTime.now().toUtc().toIso8601String();
  return jsonEncode({
    'id': '550e8400-e29b-41d4-a716-44665544f117',
    'name': '${device.name} onboarding map',
    'instrument_family': 'drums',
    'layout_id': 'std-5pc-v1',
    'device_fingerprint': {
      'vendor_name': device.manufacturerName,
      'model_name': device.productName ?? device.name,
      'platform_id': '$platformName:${device.id}',
    },
    'transport': 'usb',
    'midi_channel': null,
    'note_map': [
      _noteMap(35, 'kick', 'normal'),
      _noteMap(36, 'kick', 'normal'),
      _noteMap(37, 'snare', 'rim'),
      _noteMap(38, 'snare', 'normal'),
      _noteMap(40, 'snare', 'rim'),
      _noteMap(42, 'hihat', 'closed'),
      _noteMap(44, 'hihat', 'pedal'),
      _noteMap(46, 'hihat', 'open'),
      _noteMap(49, 'crash', 'normal'),
      _noteMap(55, 'crash', 'normal'),
      _noteMap(57, 'crash', 'normal'),
    ],
    'hihat_model': {
      'source_cc': 4,
      'invert': false,
      'thresholds': [
        {'max_cc_value': 31, 'state': 'closed'},
        {'max_cc_value': 95, 'state': 'semi_open'},
        {'max_cc_value': 127, 'state': 'open'},
      ],
      'auto_articulation_notes': [42, 46],
    },
    'input_offset_ms': 0.0,
    'dedupe_window_ms': 8.0,
    'velocity_curve': 'linear',
    'preset_origin': 'onboarding-gm-5pc',
    'created_at': now,
    'updated_at': now,
  });
}

Map<String, Object?> _noteMap(
  int midiNote,
  String laneId,
  String articulation,
) {
  return {
    'midi_note': midiNote,
    'lane_id': laneId,
    'articulation': articulation,
    'min_velocity': 1,
    'max_velocity': 127,
  };
}

const _starterLanes = [
  NoteHighwayLane(laneId: 'kick', label: 'Kick', color: TaalColors.primary),
  NoteHighwayLane(laneId: 'snare', label: 'Snare', color: TaalColors.secondary),
  NoteHighwayLane(laneId: 'hihat', label: 'Hi-Hat', color: TaalColors.tertiary),
  NoteHighwayLane(laneId: 'crash', label: 'Crash', color: TaalColors.lanePurple),
];

const _beginnerLesson = OnboardingStarterLesson(
  title: 'Basic Rock Beat',
  detail: 'Kick on 1 and 3, snare on 2 and 4, steady hi-hats.',
  assetPath: 'assets/content/lessons/starter/beginner-basic-rock.json',
  bpm: 92,
  totalDurationMs: 5220,
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
  title: 'Syncopated Kick Push',
  detail: 'A short kick variation against steady hi-hats.',
  assetPath: 'assets/content/lessons/starter/intermediate-syncopated-kick.json',
  bpm: 98,
  totalDurationMs: 4900,
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
  title: 'Pocket Funk Groove',
  detail: 'A compact groove for demonstrating timing and feel.',
  assetPath: 'assets/content/lessons/starter/variety-funk-groove.json',
  bpm: 88,
  totalDurationMs: 2730,
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
