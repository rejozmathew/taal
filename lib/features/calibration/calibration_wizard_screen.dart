import 'dart:async';

import 'package:flutter/material.dart';
import 'package:taal/features/calibration/calibration_session.dart';
import 'package:taal/features/calibration/device_profile_calibration_store.dart';
import 'package:taal/platform/audio/metronome_audio.dart';
import 'package:taal/platform/midi/midi_adapter.dart';
import 'package:taal/src/rust/api/simple.dart';

class CalibrationWizardScreen extends StatefulWidget {
  const CalibrationWizardScreen({
    super.key,
    required this.databasePath,
    required this.playerId,
    this.midiAdapter,
    this.audioOutput,
    this.store,
    this.clockNowNs,
    this.onCalibrationComplete,
  });

  final String databasePath;
  final String playerId;
  final Phase0MidiAdapter? midiAdapter;
  final MetronomeAudioOutput? audioOutput;
  final DeviceProfileCalibrationStore? store;
  final int Function()? clockNowNs;
  final ValueChanged<DeviceProfileCalibrationTarget>? onCalibrationComplete;

  @override
  State<CalibrationWizardScreen> createState() =>
      _CalibrationWizardScreenState();
}

class _CalibrationWizardScreenState extends State<CalibrationWizardScreen> {
  late final Phase0MidiAdapter _midiAdapter;
  late final MetronomeAudioOutput _audioOutput;
  late final DeviceProfileCalibrationStore _store;
  late final int Function() _clockNowNs;

  List<DeviceProfileCalibrationTarget> _targets = [];
  List<MidiInputDevice> _devices = [];
  String? _selectedTargetId;
  int? _selectedDeviceId;
  CalibrationSession? _session;
  CalibrationResult? _result;
  StreamSubscription<MidiNoteOnEvent>? _hitSubscription;
  Timer? _visualTimer;
  String? _error;
  bool _loading = true;
  bool _running = false;
  bool _busy = false;
  int _activeBeat = -1;

  @override
  void initState() {
    super.initState();
    _midiAdapter = widget.midiAdapter ?? createPhase0MidiAdapter();
    _audioOutput = widget.audioOutput ?? PlatformMetronomeAudioOutput();
    _store =
        widget.store ??
        DeviceProfileCalibrationStore(
          databasePath: widget.databasePath,
          playerId: widget.playerId,
        );
    _clockNowNs = widget.clockNowNs ?? phase0LatencyClockNs;
    _load();
  }

  @override
  void dispose() {
    _visualTimer?.cancel();
    _hitSubscription?.cancel();
    unawaited(_audioOutput.stop());
    unawaited(_midiAdapter.closeDevice());
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final targets = _store.listTargets();
      final devices = await _midiAdapter.listDevices();
      if (!mounted) {
        return;
      }
      setState(() {
        _targets = targets;
        _devices = devices;
        _selectedTargetId = targets.isEmpty ? null : targets.first.id;
        _selectedDeviceId = devices.isEmpty ? null : devices.first.id;
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

  @override
  Widget build(BuildContext context) {
    final target = _selectedTarget();
    final device = _selectedDevice();
    final session = _session;

    return Scaffold(
      appBar: AppBar(title: const Text('Calibrate kit')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hit the snare with the click.',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Taal will listen for $calibrationDefaultBeatCount steady snare hits and store the timing offset on this kit profile.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          _CalibrationBanner(
                            message: _error!,
                            color: Theme.of(context).colorScheme.errorContainer,
                            textColor: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ],
                        const SizedBox(height: 24),
                        _CalibrationSelectors(
                          targets: _targets,
                          devices: _devices,
                          selectedTargetId: _selectedTargetId,
                          selectedDeviceId: _selectedDeviceId,
                          enabled: !_running && !_busy,
                          onTargetChanged: (value) {
                            setState(() {
                              _selectedTargetId = value;
                              _result = null;
                            });
                          },
                          onDeviceChanged: (value) {
                            setState(() {
                              _selectedDeviceId = value;
                              _result = null;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        _MetronomeBeatRow(
                          beatCount: calibrationDefaultBeatCount,
                          activeBeat: _activeBeat,
                          capturedBeats:
                              session?.samples
                                  .map((sample) => sample.beatIndex)
                                  .toSet() ??
                              const <int>{},
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: session == null
                              ? 0
                              : session.samples.length /
                                    calibrationDefaultBeatCount,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          session == null
                              ? 'Ready for calibration.'
                              : '${session.samples.length}/$calibrationDefaultBeatCount snare hits captured.',
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton(
                              onPressed:
                                  _running ||
                                      _busy ||
                                      target == null ||
                                      device == null
                                  ? null
                                  : _startCalibration,
                              child: Text(
                                _running ? 'Listening...' : 'Start calibration',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _busy || target == null
                                  ? null
                                  : _skipCalibration,
                              child: const Text('Skip for now'),
                            ),
                            if (_running)
                              TextButton(
                                onPressed: _cancelCalibration,
                                child: const Text('Cancel'),
                              ),
                          ],
                        ),
                        if (_result != null) ...[
                          const SizedBox(height: 24),
                          _CalibrationResultPanel(result: _result!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _startCalibration() async {
    final target = _selectedTarget();
    final device = _selectedDevice();
    if (target == null || device == null || _running || _busy) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _result = null;
      _activeBeat = -1;
    });

    try {
      await _audioOutput.configure(
        const MetronomeAudioSettings(
          volume: 0.8,
          preset: ClickSoundPreset.woodblock,
        ),
      );
      await _midiAdapter.openDevice(device.id);

      final session = CalibrationSession(snareMidiNotes: target.snareMidiNotes);
      final sessionStartTimeNs =
          _clockNowNs() + calibrationDefaultLeadInMs * 1000000;
      session.start(sessionStartTimeNs: sessionStartTimeNs);

      await _hitSubscription?.cancel();
      _hitSubscription = _midiAdapter.noteOnEvents.listen(_recordHit);
      await _audioOutput.scheduleClicks(
        sessionStartTimeNs: sessionStartTimeNs,
        clicks: session.scheduledClicks,
      );

      _visualTimer?.cancel();
      _visualTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) => _updateActiveBeat(),
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _session = session;
        _running = true;
        _busy = false;
      });
    } on Object catch (error) {
      await _stopCapture(waitForSubscription: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _running = false;
        _busy = false;
      });
    }
  }

  void _recordHit(MidiNoteOnEvent event) {
    final session = _session;
    final target = _selectedTarget();
    if (session == null || target == null || !_running) {
      return;
    }

    final sample = session.recordHit(event);
    if (sample == null || !mounted) {
      return;
    }

    setState(() {});
    if (session.isComplete) {
      unawaited(Future.microtask(() => _completeCalibration(session, target)));
    }
  }

  Future<void> _completeCalibration(
    CalibrationSession session,
    DeviceProfileCalibrationTarget target,
  ) async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
    });

    try {
      final result = session.result();
      final updatedTarget = _store.saveOffset(
        profileJson: target.profileJson,
        offsetMs: result.offsetMs,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _targets = _replaceTarget(_targets, updatedTarget);
        _selectedTargetId = updatedTarget.id;
        _result = result;
        _running = false;
        _busy = false;
        _activeBeat = -1;
      });
      widget.onCalibrationComplete?.call(updatedTarget);
      unawaited(_stopCapture(waitForSubscription: false));
    } on Object catch (error) {
      await _stopCapture();
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _running = false;
        _busy = false;
      });
    }
  }

  Future<void> _skipCalibration() async {
    final target = _selectedTarget();
    if (target == null || _busy) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final updatedTarget = _store.skip(profileJson: target.profileJson);
      if (!mounted) {
        return;
      }
      setState(() {
        _targets = _replaceTarget(_targets, updatedTarget);
        _selectedTargetId = updatedTarget.id;
        _result = const CalibrationResult(
          offsetMs: 0,
          jitterMs: 0,
          sampleCount: 0,
          quality: CalibrationQuality(
            level: CalibrationQualityLevel.excellent,
            label: 'skipped',
            message: 'Offset set to 0ms.',
          ),
        );
        _busy = false;
      });
      widget.onCalibrationComplete?.call(updatedTarget);
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

  Future<void> _cancelCalibration() async {
    await _stopCapture();
    if (!mounted) {
      return;
    }
    setState(() {
      _session = null;
      _running = false;
      _busy = false;
      _activeBeat = -1;
    });
  }

  Future<void> _stopCapture({bool waitForSubscription = true}) async {
    _visualTimer?.cancel();
    _visualTimer = null;
    final subscription = _hitSubscription;
    _hitSubscription = null;
    if (waitForSubscription) {
      await subscription?.cancel();
    } else {
      unawaited(subscription?.cancel());
    }
    await _audioOutput.stop();
    await _midiAdapter.closeDevice();
  }

  void _updateActiveBeat() {
    final session = _session;
    final sessionStartTimeNs = session?.sessionStartTimeNs;
    if (session == null || sessionStartTimeNs == null || !mounted) {
      return;
    }
    final elapsedMs = (_clockNowNs() - sessionStartTimeNs) / 1000000.0;
    final activeBeat = elapsedMs < 0
        ? -1
        : (elapsedMs / session.beatIntervalMs).floor();
    final clampedBeat = activeBeat >= calibrationDefaultBeatCount
        ? -1
        : activeBeat;
    if (clampedBeat != _activeBeat) {
      setState(() {
        _activeBeat = clampedBeat;
      });
    }
  }

  DeviceProfileCalibrationTarget? _selectedTarget() {
    final id = _selectedTargetId;
    if (id == null) {
      return null;
    }
    for (final target in _targets) {
      if (target.id == id) {
        return target;
      }
    }
    return null;
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

class _CalibrationSelectors extends StatelessWidget {
  const _CalibrationSelectors({
    required this.targets,
    required this.devices,
    required this.selectedTargetId,
    required this.selectedDeviceId,
    required this.enabled,
    required this.onTargetChanged,
    required this.onDeviceChanged,
  });

  final List<DeviceProfileCalibrationTarget> targets;
  final List<MidiInputDevice> devices;
  final String? selectedTargetId;
  final int? selectedDeviceId;
  final bool enabled;
  final ValueChanged<String?> onTargetChanged;
  final ValueChanged<int?> onDeviceChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedTargetId,
          decoration: const InputDecoration(labelText: 'Kit profile'),
          items: [
            for (final target in targets)
              DropdownMenuItem(value: target.id, child: Text(target.name)),
          ],
          onChanged: enabled ? onTargetChanged : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: selectedDeviceId,
          decoration: const InputDecoration(labelText: 'MIDI input'),
          items: [
            for (final device in devices)
              DropdownMenuItem(value: device.id, child: Text(device.name)),
          ],
          onChanged: enabled ? onDeviceChanged : null,
        ),
        if (targets.isEmpty || devices.isEmpty) ...[
          const SizedBox(height: 12),
          _CalibrationBanner(
            message: targets.isEmpty
                ? 'Create or select a kit profile before calibration.'
                : 'Connect a MIDI device before calibration.',
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            textColor: Theme.of(context).colorScheme.onSurface,
          ),
        ],
      ],
    );
  }
}

class _MetronomeBeatRow extends StatelessWidget {
  const _MetronomeBeatRow({
    required this.beatCount,
    required this.activeBeat,
    required this.capturedBeats,
  });

  final int beatCount;
  final int activeBeat;
  final Set<int> capturedBeats;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < beatCount; index += 1)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _beatColor(context, index),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text('${index + 1}'),
          ),
      ],
    );
  }

  Color _beatColor(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    if (capturedBeats.contains(index)) {
      return scheme.primary;
    }
    if (index == activeBeat) {
      return scheme.secondary;
    }
    return scheme.surfaceContainerHighest;
  }
}

class _CalibrationResultPanel extends StatelessWidget {
  const _CalibrationResultPanel({required this.result});

  final CalibrationResult result;

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
              '${result.offsetLabel} - ${result.quality.label}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(result.quality.message),
            if (result.sampleCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Jitter ${result.jitterMs.toStringAsFixed(1)}ms across ${result.sampleCount} hits.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CalibrationBanner extends StatelessWidget {
  const _CalibrationBanner({
    required this.message,
    required this.color,
    required this.textColor,
  });

  final String message;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, style: TextStyle(color: textColor)),
      ),
    );
  }
}

List<DeviceProfileCalibrationTarget> _replaceTarget(
  List<DeviceProfileCalibrationTarget> targets,
  DeviceProfileCalibrationTarget replacement,
) {
  return [
    for (final target in targets)
      if (target.id == replacement.id) replacement else target,
  ];
}
