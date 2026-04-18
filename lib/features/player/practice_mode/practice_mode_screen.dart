import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:taal/design/colors.dart';
import 'package:taal/design/daily_goal_ring.dart';
import 'package:taal/design/motion.dart';
import 'package:taal/features/player/drum_kit/drum_kit.dart';
import 'package:taal/features/player/layout_compatibility/layout_compatibility.dart';
import 'package:taal/features/player/notation/notation_view.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';
import 'package:taal/features/player/tap_pads/tap_pad_surface.dart';
import 'package:taal/platform/audio/metronome_audio.dart';
import 'package:taal/platform/midi/midi_device_monitor.dart';
import 'package:taal/src/rust/api/simple.dart';

class PracticeModeScreen extends StatefulWidget {
  const PracticeModeScreen({
    super.key,
    required this.controller,
    required this.lanes,
    required this.notes,
    this.feedback = const [],
    this.kitPads = standardFivePieceDrumKitPads,
    this.tapPadInput,
    this.dailyGoalProgress,
    this.listenPlayback,
    this.layoutCompatibility,
    this.midiConnectionState,
    this.onRescanMidi,
  });

  final PracticeModeController controller;
  final List<NoteHighwayLane> lanes;
  final List<PracticeTimelineNote> notes;
  final List<PracticeFeedbackMarker> feedback;
  final List<VisualDrumKitPad> kitPads;
  final PracticeTapPadInput? tapPadInput;
  final DailyGoalProgress? dailyGoalProgress;
  final PracticeListenPlayback? listenPlayback;
  final LayoutCompatibilitySnapshot? layoutCompatibility;
  final MidiConnectionState? midiConnectionState;
  final VoidCallback? onRescanMidi;

  @override
  State<PracticeModeScreen> createState() => _PracticeModeScreenState();
}

class _PracticeModeScreenState extends State<PracticeModeScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _lastTickElapsed;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    widget.controller.addListener(_onControllerChanged);
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant PracticeModeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _syncTicker();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _ticker.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      _syncTicker();
      setState(() {});
    }
  }

  void _syncTicker() {
    final shouldTick = widget.controller.isTimelineAdvancing;
    if (shouldTick && !_ticker.isActive) {
      _lastTickElapsed = null;
      _ticker.start();
    } else if (!shouldTick && _ticker.isActive) {
      _ticker.stop();
      _lastTickElapsed = null;
    }
  }

  void _onTick(Duration elapsed) {
    final previous = _lastTickElapsed;
    _lastTickElapsed = elapsed;
    if (previous == null) {
      return;
    }
    widget.controller.advanceBy(elapsed - previous);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final tapPadInput = widget.tapPadInput;
    final compatibility = widget.layoutCompatibility;

    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 120),
          child: SingleChildScrollView(
            child: _PracticeTransportBar(
              controller: controller,
              dailyGoalProgress: widget.dailyGoalProgress,
              listenPlayback:
                  widget.listenPlayback ?? const PracticeListenPlayback(),
              notes: widget.notes,
              layoutCompatibility: compatibility,
              midiConnectionState: widget.midiConnectionState,
              onRescanMidi: widget.onRescanMidi,
            ),
          ),
        ),
        if (compatibility != null && compatibility.hasExcludedLanes)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: LayoutCompatibilityBanner(
              compatibility: compatibility,
              mode: LayoutCompatibilityBannerMode.practice,
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: _PracticeViewSurface(
                  controller: controller,
                  lanes: widget.lanes,
                  notes: widget.notes,
                  feedback: widget.feedback,
                  kitPads: widget.kitPads,
                ),
              ),
              _GradeFlashOverlay(
                key: const ValueKey('practice-grade-flash'),
                grade: controller.lastGrade,
              ),
            ],
          ),
        ),
        if (tapPadInput != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: SizedBox(
              height: 240,
              child: TapPadSurface(
                pads: tapPadInput.pads,
                enabledLaneIds: tapPadInput.enabledLaneIds,
                velocity: tapPadInput.velocity,
                onPadHit: tapPadInput.onPadHit,
              ),
            ),
          ),
        _PracticeLoopControls(controller: controller),
      ],
    );
  }
}

enum PracticeTransportState { stopped, running, paused, listening, countIn }

enum PracticeDisplayView { noteHighway, notation, drumKit }

enum PracticeListenScope { wholeLesson, selectedRange }

class PracticeAutoPauseConfig {
  const PracticeAutoPauseConfig({
    this.enabled = false,
    this.timeoutMs = 3000,
    this.activeMissGapToleranceMs = 1000,
  }) : assert(timeoutMs > 0, 'timeoutMs must be positive'),
       assert(
         activeMissGapToleranceMs > 0,
         'activeMissGapToleranceMs must be positive',
       );

  final bool enabled;
  final int timeoutMs;
  final double activeMissGapToleranceMs;
}

class PracticeTapPadInput {
  const PracticeTapPadInput({
    required this.onPadHit,
    this.pads = standardFivePieceDrumKitPads,
    this.enabledLaneIds,
    this.velocity = 96,
  });

  final List<VisualDrumKitPad> pads;
  final Set<String>? enabledLaneIds;
  final int velocity;
  final ValueChanged<TapPadHit> onPadHit;
}

class PracticeListenRange {
  const PracticeListenRange({required this.startMs, required this.endMs})
    : assert(startMs >= 0, 'listen range start must be non-negative'),
      assert(endMs > startMs, 'listen range end must be after start');

  final double startMs;
  final double endMs;
}

class PracticeListenPlayback {
  const PracticeListenPlayback({
    MetronomeAudioOutput? audioOutput,
    int Function()? clockNowNs,
  }) : _audioOutput = audioOutput,
       _clockNowNs = clockNowNs;

  final MetronomeAudioOutput? _audioOutput;
  final int Function()? _clockNowNs;

  Future<void> toggle({
    required PracticeModeController controller,
    required List<PracticeTimelineNote> notes,
  }) async {
    if (controller.isListening) {
      await stop(controller);
      return;
    }
    await start(controller: controller, notes: notes);
  }

  Future<void> start({
    required PracticeModeController controller,
    required List<PracticeTimelineNote> notes,
  }) async {
    final output = _audioOutput ?? PlatformMetronomeAudioOutput();
    final range = controller.listenRange;
    final startTimeNs = (_clockNowNs ?? phase0LatencyClockNs)();
    await output.stop();
    await output.scheduleDrumHits(
      sessionStartTimeNs: startTimeNs,
      hits: scheduledHitsFor(
        notes: notes,
        range: range,
        baseBpm: controller.baseBpm,
        tempoBpm: controller.tempoBpm,
      ),
    );
    controller.beginListening(startMs: range.startMs, endMs: range.endMs);
  }

  Future<void> stop(PracticeModeController controller) async {
    final output = _audioOutput ?? PlatformMetronomeAudioOutput();
    await output.stop();
    controller.stopListening();
  }

  static List<ScheduledDrumHit> scheduledHitsFor({
    required List<PracticeTimelineNote> notes,
    required PracticeListenRange range,
    required double baseBpm,
    required double tempoBpm,
  }) {
    if (baseBpm <= 0 || tempoBpm <= 0) {
      throw ArgumentError('baseBpm and tempoBpm must be positive');
    }
    final tempoScale = baseBpm / tempoBpm;
    return notes
        .where((note) => note.tMs >= range.startMs && note.tMs < range.endMs)
        .map(
          (note) => ScheduledDrumHit(
            tMs: ((note.tMs - range.startMs) * tempoScale).round(),
            laneId: note.laneId,
            velocity: 96,
            articulation: note.articulation,
          ),
        )
        .toList(growable: false);
  }
}

class DailyGoalProgress {
  const DailyGoalProgress({
    required this.persistedTodayMinutesCompleted,
    required this.dailyGoalMinutes,
  }) : assert(dailyGoalMinutes > 0, 'dailyGoalMinutes must be positive');

  final double persistedTodayMinutesCompleted;
  final int dailyGoalMinutes;

  double completedMinutesWithSession(double currentSessionElapsedMs) {
    return persistedTodayMinutesCompleted + currentSessionElapsedMs / 60000.0;
  }

  double progressWithSession(double currentSessionElapsedMs) {
    return (completedMinutesWithSession(currentSessionElapsedMs) /
            dailyGoalMinutes)
        .clamp(0.0, 1.0)
        .toDouble();
  }
}

class PracticeTimelineNote {
  const PracticeTimelineNote({
    required this.expectedId,
    required this.laneId,
    required this.tMs,
    this.articulation = 'normal',
  });

  final String expectedId;
  final String laneId;
  final double tMs;
  final String articulation;
}

class PracticeFeedbackMarker {
  const PracticeFeedbackMarker({
    required this.expectedId,
    required this.laneId,
    required this.tMs,
    required this.deltaMs,
    required this.grade,
  });

  final String expectedId;
  final String laneId;
  final double tMs;
  final double deltaMs;
  final NoteHighwayGrade grade;
}

class PracticeSection {
  const PracticeSection({
    required this.sectionId,
    required this.label,
    required this.startMs,
    required this.endMs,
    this.loopable = true,
  }) : assert(endMs > startMs, 'section end must be after start');

  final String sectionId;
  final String label;
  final double startMs;
  final double endMs;
  final bool loopable;
}

class PracticeModeController extends ChangeNotifier {
  PracticeModeController({
    required this.baseBpm,
    required this.totalDurationMs,
    List<PracticeSection> sections = const [],
    double? initialTempoBpm,
    double minTempoBpm = 40,
    double maxTempoBpm = 240,
    PracticeAutoPauseConfig autoPauseConfig = const PracticeAutoPauseConfig(),
    int countInBars = 0,
  }) : assert(baseBpm > 0, 'baseBpm must be positive'),
       assert(totalDurationMs > 0, 'totalDurationMs must be positive'),
       assert(countInBars >= 0 && countInBars <= 4, 'countInBars must be 0-4'),
       _sections = List.unmodifiable(sections),
       _tempoBpm = initialTempoBpm ?? baseBpm,
       _minTempoBpm = minTempoBpm,
       _maxTempoBpm = maxTempoBpm,
       _autoPauseConfig = autoPauseConfig,
       _countInBars = countInBars {
    final firstSection = _sections
        .where((section) => section.loopable)
        .firstOrNull;
    _loopStartMs = firstSection?.startMs ?? 0;
    _loopEndMs = firstSection?.endMs ?? totalDurationMs;
    _selectedSectionId = firstSection?.sectionId;
  }

  final double baseBpm;
  final double totalDurationMs;
  final List<PracticeSection> _sections;
  final double _minTempoBpm;
  final double _maxTempoBpm;

  PracticeTransportState _transportState = PracticeTransportState.stopped;
  PracticeDisplayView _displayView = PracticeDisplayView.noteHighway;
  double _currentTimeMs = 0;
  double _tempoBpm;
  double? _tempoChangeEffectiveAtMs;
  bool _metronomeEnabled = true;
  bool _loopEnabled = false;
  PracticeListenScope _listenScope = PracticeListenScope.wholeLesson;
  String? _selectedSectionId;
  late double _loopStartMs;
  late double _loopEndMs;
  double _listenStartMs = 0;
  double _listenEndMs = 0;
  PracticeAutoPauseConfig _autoPauseConfig;
  bool _autoPauseTriggered = false;
  bool _midiDisconnected = false;
  int _combo = 0;
  String? _encouragementText;
  double _activeSessionElapsedMs = 0;
  int _countInBars;
  double _countInRemainingMs = 0;
  NoteHighwayGrade? _lastGrade;

  PracticeTransportState get transportState => _transportState;

  PracticeDisplayView get displayView => _displayView;

  double get currentTimeMs => _currentTimeMs;

  double get tempoBpm => _tempoBpm;

  double get minTempoBpm => _minTempoBpm;

  double get maxTempoBpm => _maxTempoBpm;

  double? get tempoChangeEffectiveAtMs => _tempoChangeEffectiveAtMs;

  bool get metronomeEnabled => _metronomeEnabled;

  bool get loopEnabled => _loopEnabled;

  PracticeListenScope get listenScope => _listenScope;

  String? get selectedSectionId => _selectedSectionId;

  double get loopStartMs => _loopStartMs;

  double get loopEndMs => _loopEndMs;

  double get listenStartMs => _listenStartMs;

  double get listenEndMs => _listenEndMs;

  PracticeAutoPauseConfig get autoPauseConfig => _autoPauseConfig;

  bool get autoPauseTriggered => _autoPauseTriggered;

  bool get midiDisconnected => _midiDisconnected;

  int get combo => _combo;

  String? get encouragementText => _encouragementText;

  NoteHighwayGrade? get lastGrade => _lastGrade;

  List<PracticeSection> get sections => _sections;

  double get activeSessionElapsedMs => _activeSessionElapsedMs;

  int get countInBars => _countInBars;

  double get countInRemainingMs => _countInRemainingMs;

  int get countInRemainingBeats {
    if (_transportState != PracticeTransportState.countIn) return 0;
    final beatMs = 60000.0 / _tempoBpm;
    return (_countInRemainingMs / beatMs).ceil().clamp(1, _countInBars * 4);
  }

  bool get isCountingIn => _transportState == PracticeTransportState.countIn;

  bool get isRunning => _transportState == PracticeTransportState.running;

  bool get isPaused => _transportState == PracticeTransportState.paused;

  bool get isListening => _transportState == PracticeTransportState.listening;

  bool get isTimelineAdvancing => isRunning || isListening || isCountingIn;

  PracticeListenRange get listenRange {
    switch (_listenScope) {
      case PracticeListenScope.wholeLesson:
        return PracticeListenRange(startMs: 0, endMs: totalDurationMs);
      case PracticeListenScope.selectedRange:
        return PracticeListenRange(startMs: _loopStartMs, endMs: _loopEndMs);
    }
  }

  void play() {
    if (_transportState == PracticeTransportState.running) {
      return;
    }
    if (_transportState == PracticeTransportState.listening) {
      return;
    }
    if (_transportState == PracticeTransportState.countIn) {
      return;
    }
    _autoPauseTriggered = false;
    if (_countInBars > 0) {
      _countInRemainingMs = _countInBars * 4 * 60000.0 / _tempoBpm;
      _transportState = PracticeTransportState.countIn;
    } else {
      _transportState = PracticeTransportState.running;
    }
    notifyListeners();
  }

  void pause() {
    if (_transportState != PracticeTransportState.running) {
      return;
    }
    _transportState = PracticeTransportState.paused;
    notifyListeners();
  }

  void resume() {
    if (_transportState != PracticeTransportState.paused) {
      return;
    }
    _autoPauseTriggered = false;
    _transportState = PracticeTransportState.running;
    notifyListeners();
  }

  void stop() {
    _transportState = PracticeTransportState.stopped;
    _currentTimeMs = _loopEnabled ? _loopStartMs : 0;
    _combo = 0;
    _encouragementText = null;
    _autoPauseTriggered = false;
    _countInRemainingMs = 0;
    notifyListeners();
  }

  void togglePlayPause() {
    switch (_transportState) {
      case PracticeTransportState.stopped:
        play();
      case PracticeTransportState.paused:
        resume();
      case PracticeTransportState.running:
        pause();
      case PracticeTransportState.listening:
        return;
      case PracticeTransportState.countIn:
        // Cancel count-in and stop.
        _transportState = PracticeTransportState.stopped;
        _countInRemainingMs = 0;
        notifyListeners();
    }
  }

  void setCountInBars(int bars) {
    if (bars < 0 || bars > 4) {
      throw ArgumentError.value(bars, 'bars', 'must be 0-4');
    }
    _countInBars = bars;
    notifyListeners();
  }

  void selectView(PracticeDisplayView view) {
    if (_displayView == view) {
      return;
    }
    _displayView = view;
    notifyListeners();
  }

  void setTempoBpm(double bpm) {
    final clamped = bpm.clamp(_minTempoBpm, _maxTempoBpm).toDouble();
    _tempoChangeEffectiveAtMs = nextBeatBoundaryMs(_currentTimeMs);
    _tempoBpm = clamped;
    notifyListeners();
  }

  void setMetronomeEnabled(bool enabled) {
    if (_metronomeEnabled == enabled) {
      return;
    }
    _metronomeEnabled = enabled;
    notifyListeners();
  }

  void setLoopEnabled(bool enabled) {
    if (_loopEnabled == enabled) {
      return;
    }
    _loopEnabled = enabled;
    if (_loopEnabled && _currentTimeMs < _loopStartMs) {
      _currentTimeMs = _loopStartMs;
    }
    notifyListeners();
  }

  void setListenScope(PracticeListenScope scope) {
    if (_listenScope == scope) {
      return;
    }
    _listenScope = scope;
    notifyListeners();
  }

  void setAutoPauseConfig(PracticeAutoPauseConfig config) {
    _autoPauseConfig = config;
    if (!config.enabled) {
      _autoPauseTriggered = false;
    }
    notifyListeners();
  }

  void selectLoopSection(String sectionId) {
    final section = _sections.firstWhere(
      (section) => section.sectionId == sectionId,
      orElse: () => throw ArgumentError.value(sectionId, 'sectionId'),
    );
    if (!section.loopable) {
      throw ArgumentError.value(
        sectionId,
        'sectionId',
        'section is not loopable',
      );
    }
    _selectedSectionId = section.sectionId;
    _loopStartMs = section.startMs;
    _loopEndMs = section.endMs;
    notifyListeners();
  }

  void setManualLoopRange(double startMs, double endMs) {
    if (startMs < 0 || endMs > totalDurationMs || endMs <= startMs) {
      throw RangeError('loop range must be inside the lesson and non-empty');
    }
    _selectedSectionId = null;
    _loopStartMs = startMs;
    _loopEndMs = endMs;
    notifyListeners();
  }

  void setRuntimeFeedback({
    int? combo,
    String? encouragementText,
    NoteHighwayGrade? lastGrade,
  }) {
    _combo = combo ?? _combo;
    _encouragementText = encouragementText;
    _lastGrade = lastGrade ?? _lastGrade;
    notifyListeners();
  }

  void seekTo(double timeMs) {
    _currentTimeMs = timeMs.clamp(0, totalDurationMs).toDouble();
    notifyListeners();
  }

  void beginListening({required double startMs, required double endMs}) {
    if (startMs < 0 || endMs > totalDurationMs || endMs <= startMs) {
      throw RangeError('listen range must be inside the lesson and non-empty');
    }
    _listenStartMs = startMs;
    _listenEndMs = endMs;
    _currentTimeMs = startMs;
    _autoPauseTriggered = false;
    _transportState = PracticeTransportState.listening;
    notifyListeners();
  }

  void stopListening() {
    if (_transportState != PracticeTransportState.listening) {
      return;
    }
    _transportState = PracticeTransportState.stopped;
    notifyListeners();
  }

  bool triggerAutoPause() {
    if (!_autoPauseConfig.enabled ||
        _transportState != PracticeTransportState.running) {
      return false;
    }
    _autoPauseTriggered = true;
    _transportState = PracticeTransportState.paused;
    notifyListeners();
    return true;
  }

  bool pauseForMidiDisconnect() {
    if (_transportState != PracticeTransportState.running) {
      _midiDisconnected = true;
      notifyListeners();
      return false;
    }
    _midiDisconnected = true;
    _transportState = PracticeTransportState.paused;
    notifyListeners();
    return true;
  }

  void resumeFromMidiReconnect() {
    _midiDisconnected = false;
    if (_transportState == PracticeTransportState.paused) {
      _transportState = PracticeTransportState.running;
    }
    notifyListeners();
  }

  void advanceBy(Duration elapsed) {
    if (!isTimelineAdvancing) {
      return;
    }

    // Count-in phase: tick down, then transition to running.
    if (_transportState == PracticeTransportState.countIn) {
      _countInRemainingMs -= elapsed.inMicroseconds / 1000.0;
      if (_countInRemainingMs <= 0) {
        _countInRemainingMs = 0;
        _transportState = PracticeTransportState.running;
      }
      notifyListeners();
      return;
    }

    final scaledDeltaMs =
        elapsed.inMicroseconds / 1000.0 * (_tempoBpm / baseBpm);
    if (_transportState == PracticeTransportState.running) {
      _activeSessionElapsedMs += elapsed.inMicroseconds / 1000.0;
    }
    var nextTime = _currentTimeMs + scaledDeltaMs;

    if (_transportState == PracticeTransportState.listening) {
      if (nextTime >= _listenEndMs) {
        _currentTimeMs = _listenEndMs;
        _transportState = PracticeTransportState.stopped;
      } else {
        _currentTimeMs = math.max(nextTime, _listenStartMs);
      }
      notifyListeners();
      return;
    }

    if (_loopEnabled) {
      final length = _loopEndMs - _loopStartMs;
      if (length <= 0) {
        throw StateError('loop range is invalid');
      }
      while (nextTime >= _loopEndMs) {
        nextTime = _loopStartMs + (nextTime - _loopEndMs) % length;
      }
      if (nextTime < _loopStartMs) {
        nextTime = _loopStartMs;
      }
    } else {
      nextTime = math.min(nextTime, totalDurationMs);
    }

    _currentTimeMs = nextTime;
    notifyListeners();
  }

  double nextBeatBoundaryMs(double fromTimeMs) {
    final beatMs = 60000.0 / _tempoBpm;
    return ((fromTimeMs / beatMs).floor() + 1) * beatMs;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}

String _formatMinutes(double value) {
  if ((value - value.roundToDouble()).abs() < 0.05) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

class _PracticeTransportBar extends StatelessWidget {
  const _PracticeTransportBar({
    required this.controller,
    required this.dailyGoalProgress,
    required this.listenPlayback,
    required this.notes,
    required this.layoutCompatibility,
    this.midiConnectionState,
    this.onRescanMidi,
  });

  final PracticeModeController controller;
  final DailyGoalProgress? dailyGoalProgress;
  final PracticeListenPlayback listenPlayback;
  final List<PracticeTimelineNote> notes;
  final LayoutCompatibilitySnapshot? layoutCompatibility;
  final MidiConnectionState? midiConnectionState;
  final VoidCallback? onRescanMidi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _TransportGroup(controller: controller, scheme: scheme),
            _ModeGroup(
              controller: controller,
              listenPlayback: listenPlayback,
              notes: notes,
            ),
            _ToolsGroup(controller: controller),
            _StatusGroup(
              controller: controller,
              dailyGoalProgress: dailyGoalProgress,
              layoutCompatibility: layoutCompatibility,
              midiConnectionState: midiConnectionState,
              onRescanMidi: onRescanMidi,
            ),
          ],
        ),
      ),
    );
  }
}

/// Transport group: Play/Pause (large), Stop, Count-in selector.
class _TransportGroup extends StatelessWidget {
  const _TransportGroup({required this.controller, required this.scheme});
  final PracticeModeController controller;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isActive =
        controller.isRunning ||
        controller.isCountingIn ||
        controller.transportState == PracticeTransportState.paused;
    final playLabel = controller.isRunning || controller.isCountingIn
        ? 'Pause'
        : 'Play';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 48,
          child: PressableScale(
            onTap: controller.isListening ? null : controller.togglePlayPause,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(80, 48)),
              onPressed: controller.isListening
                  ? null
                  : controller.togglePlayPause,
              icon: Icon(
                controller.isRunning || controller.isCountingIn
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(playLabel),
            ),
          ),
        ),
        if (isActive) ...[
          const SizedBox(width: 6),
          IconButton(
            key: const ValueKey('practice-stop-button'),
            icon: const Icon(Icons.stop_rounded),
            onPressed: () {
              controller.stop();
            },
            tooltip: 'Stop',
            visualDensity: VisualDensity.compact,
          ),
        ],
        const SizedBox(width: 6),
        _CountInSelector(controller: controller),
        if (controller.isCountingIn)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '${controller.countInRemainingBeats}',
              key: const ValueKey('practice-countin-display'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// Count-in bars selector (0-4 bars).
class _CountInSelector extends StatelessWidget {
  const _CountInSelector({required this.controller});
  final PracticeModeController controller;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      key: const ValueKey('practice-countin-selector'),
      tooltip: 'Count-in bars',
      initialValue: controller.countInBars,
      onSelected: controller.setCountInBars,
      itemBuilder: (context) => List.generate(5, (i) {
        return PopupMenuItem(
          value: i,
          child: Text(i == 0 ? 'No count-in' : '$i bar${i > 1 ? 's' : ''}'),
        );
      }),
      child: Chip(
        avatar: const Icon(Icons.timer_outlined, size: 16),
        label: Text(
          controller.countInBars == 0
              ? 'No count-in'
              : '${controller.countInBars}bar',
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// Mode group: Listen toggle, listen scope, View selector.
class _ModeGroup extends StatelessWidget {
  const _ModeGroup({
    required this.controller,
    required this.listenPlayback,
    required this.notes,
  });
  final PracticeModeController controller;
  final PracticeListenPlayback listenPlayback;
  final List<PracticeTimelineNote> notes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.tonal(
          key: const ValueKey('practice-listen-button'),
          onPressed: controller.isRunning
              ? null
              : () =>
                    listenPlayback.toggle(controller: controller, notes: notes),
          child: Text(controller.isListening ? 'Stop Listening' : 'Listen'),
        ),
        SegmentedButton<PracticeListenScope>(
          segments: const [
            ButtonSegment(
              value: PracticeListenScope.wholeLesson,
              label: Text('Whole'),
            ),
            ButtonSegment(
              value: PracticeListenScope.selectedRange,
              label: Text('Section'),
            ),
          ],
          selected: {controller.listenScope},
          onSelectionChanged: controller.isListening
              ? null
              : (selection) => controller.setListenScope(selection.single),
        ),
        SegmentedButton<PracticeDisplayView>(
          segments: const [
            ButtonSegment(
              value: PracticeDisplayView.noteHighway,
              label: Text('Highway'),
            ),
            ButtonSegment(
              value: PracticeDisplayView.notation,
              label: Text('Notation'),
            ),
            ButtonSegment(
              value: PracticeDisplayView.drumKit,
              label: Text('Kit'),
            ),
          ],
          selected: {controller.displayView},
          onSelectionChanged: (selection) =>
              controller.selectView(selection.single),
        ),
      ],
    );
  }
}

/// Practice tools group: Metronome + BPM, Loop toggle.
class _ToolsGroup extends StatelessWidget {
  const _ToolsGroup({required this.controller});
  final PracticeModeController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: const Text('Metronome'),
          selected: controller.metronomeEnabled,
          onSelected: controller.isListening
              ? null
              : controller.setMetronomeEnabled,
        ),
        SizedBox(
          width: 260,
          child: Row(
            children: [
              Text('${controller.tempoBpm.round()} BPM'),
              Expanded(
                child: Slider(
                  value: controller.tempoBpm,
                  min: controller.minTempoBpm,
                  max: controller.maxTempoBpm,
                  onChanged: controller.isListening
                      ? null
                      : controller.setTempoBpm,
                ),
              ),
            ],
          ),
        ),
        FilterChip(
          label: const Text('Loop'),
          selected: controller.loopEnabled,
          onSelected: controller.isListening ? null : controller.setLoopEnabled,
        ),
      ],
    );
  }
}

/// Status group: Combo, encouragement, alerts, MIDI, daily goal.
class _StatusGroup extends StatelessWidget {
  const _StatusGroup({
    required this.controller,
    required this.dailyGoalProgress,
    required this.layoutCompatibility,
    required this.midiConnectionState,
    this.onRescanMidi,
  });
  final PracticeModeController controller;
  final DailyGoalProgress? dailyGoalProgress;
  final LayoutCompatibilitySnapshot? layoutCompatibility;
  final MidiConnectionState? midiConnectionState;
  final VoidCallback? onRescanMidi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedComboCounter(
              combo: controller.combo,
              key: const ValueKey('practice-combo-counter'),
            ),
            const SizedBox(width: 8),
            _MidiConnectionIndicator(
              connectionState: midiConnectionState,
              onRescan: onRescanMidi,
            ),
          ],
        ),
        if (controller.encouragementText case final message?)
          _AnimatedEncouragement(
            key: ValueKey('practice-encouragement-$message'),
            message: message,
          ),
        if (controller.autoPauseTriggered)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Paused - tap any pad to resume',
              key: const ValueKey('practice-auto-pause-message'),
              style: TextStyle(
                color: scheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (controller.midiDisconnected)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'MIDI disconnected - reconnect to resume',
              key: const ValueKey('practice-midi-disconnect-message'),
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (dailyGoalProgress case final goal?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _DailyGoalProgressChip(
              goal: goal,
              currentSessionElapsedMs: controller.activeSessionElapsedMs,
            ),
          ),
        if (layoutCompatibility case final compatibility?)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LayoutCompatibilityIndicator(compatibility: compatibility),
          ),
      ],
    );
  }
}

class _DailyGoalProgressChip extends StatelessWidget {
  const _DailyGoalProgressChip({
    required this.goal,
    required this.currentSessionElapsedMs,
  });

  final DailyGoalProgress goal;
  final double currentSessionElapsedMs;

  @override
  Widget build(BuildContext context) {
    final completed = goal.completedMinutesWithSession(currentSessionElapsedMs);
    final progress = goal.progressWithSession(currentSessionElapsedMs);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DailyGoalRing(progress: progress, size: 32, strokeWidth: 3),
        const SizedBox(width: 6),
        Text(
          'Daily goal ${_formatMinutes(completed)} / ${goal.dailyGoalMinutes} min',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _MidiConnectionIndicator extends StatelessWidget {
  const _MidiConnectionIndicator({
    required this.connectionState,
    this.onRescan,
  });

  final MidiConnectionState? connectionState;
  final VoidCallback? onRescan;

  @override
  Widget build(BuildContext context) {
    final connected = connectionState == MidiConnectionState.connected;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.circle,
          size: 12,
          key: const ValueKey('practice-midi-status-icon'),
          color: connected ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          connected ? 'MIDI' : 'Tap pads',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        if (onRescan != null) ...[
          const SizedBox(width: 4),
          IconButton(
            key: const ValueKey('practice-midi-rescan'),
            icon: const Icon(Icons.refresh, size: 18),
            onPressed: onRescan,
            tooltip: 'Scan for MIDI devices',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }
}

class _PracticeViewSurface extends StatelessWidget {
  const _PracticeViewSurface({
    required this.controller,
    required this.lanes,
    required this.notes,
    required this.feedback,
    required this.kitPads,
  });

  final PracticeModeController controller;
  final List<NoteHighwayLane> lanes;
  final List<PracticeTimelineNote> notes;
  final List<PracticeFeedbackMarker> feedback;
  final List<VisualDrumKitPad> kitPads;

  @override
  Widget build(BuildContext context) {
    switch (controller.displayView) {
      case PracticeDisplayView.noteHighway:
        return NoteHighwayWidget(
          lanes: lanes,
          notes: notes
              .map(
                (note) => NoteHighwayNote(
                  expectedId: note.expectedId,
                  laneId: note.laneId,
                  tMs: note.tMs,
                ),
              )
              .toList(growable: false),
          feedback: feedback
              .map(
                (marker) => NoteHighwayFeedback(
                  expectedId: marker.expectedId,
                  laneId: marker.laneId,
                  tMs: marker.tMs,
                  deltaMs: marker.deltaMs,
                  grade: marker.grade,
                ),
              )
              .toList(growable: false),
          currentTimeMs: controller.currentTimeMs,
        );
      case PracticeDisplayView.notation:
        return NotationViewWidget(
          notes: notes
              .map(
                (note) => NotationNote(
                  expectedId: note.expectedId,
                  laneId: note.laneId,
                  tMs: note.tMs,
                  articulation: note.articulation,
                ),
              )
              .toList(growable: false),
          feedback: feedback
              .map(
                (marker) => NotationFeedback(
                  expectedId: marker.expectedId,
                  laneId: marker.laneId,
                  tMs: marker.tMs,
                  deltaMs: marker.deltaMs,
                  grade: marker.grade,
                ),
              )
              .toList(growable: false),
          currentTimeMs: controller.currentTimeMs,
        );
      case PracticeDisplayView.drumKit:
        return VisualDrumKitWidget(pads: kitPads, hits: _activeKitHits());
    }
  }

  List<VisualDrumKitHit> _activeKitHits() {
    const flashWindowMs = 260.0;
    return feedback
        .where(
          (marker) =>
              (controller.currentTimeMs - marker.tMs).abs() <= flashWindowMs,
        )
        .map(
          (marker) => VisualDrumKitHit(
            laneId: marker.laneId,
            grade: marker.grade,
            progress:
                ((controller.currentTimeMs - marker.tMs).abs() / flashWindowMs)
                    .clamp(0.0, 1.0)
                    .toDouble(),
          ),
        )
        .toList(growable: false);
  }
}

class _PracticeLoopControls extends StatelessWidget {
  const _PracticeLoopControls({required this.controller});

  final PracticeModeController controller;

  @override
  Widget build(BuildContext context) {
    final duration = controller.totalDurationMs;
    final normalizedStart = controller.loopStartMs
        .clamp(0, duration)
        .toDouble();
    final normalizedEnd = controller.loopEndMs.clamp(0, duration).toDouble();

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Loop section'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: controller.selectedSectionId,
                  hint: const Text('Manual A-B'),
                  items: controller.sections
                      .where((section) => section.loopable)
                      .map(
                        (section) => DropdownMenuItem(
                          value: section.sectionId,
                          child: Text(section.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      controller.selectLoopSection(value);
                    }
                  },
                ),
                const Spacer(),
                Text(
                  '${(controller.currentTimeMs / 1000).toStringAsFixed(1)}s',
                ),
              ],
            ),
            RangeSlider(
              values: RangeValues(normalizedStart, normalizedEnd),
              min: 0,
              max: duration,
              onChanged: (values) {
                if (values.end > values.start) {
                  controller.setManualLoopRange(values.start, values.end);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated combo counter with scale-up on increment, shake on reset,
/// and color intensification at milestones (8, 16, 32).
class _AnimatedComboCounter extends StatefulWidget {
  const _AnimatedComboCounter({super.key, required this.combo});
  final int combo;

  @override
  State<_AnimatedComboCounter> createState() => _AnimatedComboCounterState();
}

class _AnimatedComboCounterState extends State<_AnimatedComboCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _shake;
  bool _isReset = false;

  static const _milestones = {8, 16, 32};

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TaalMotion.durationMedium,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: TaalMotion.curveStandard),
    );
    _shake = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _controller, curve: TaalMotion.curveStandard),
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedComboCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.combo != oldWidget.combo) {
      _isReset = widget.combo == 0 && oldWidget.combo > 0;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _comboColor(ColorScheme scheme) {
    if (widget.combo >= 32) return TaalColors.gradePerfect;
    if (widget.combo >= 16) return TaalColors.comboActive;
    if (widget.combo >= 8) return TaalColors.gradeGood;
    return scheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMilestone = _milestones.contains(widget.combo);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double dx = _isReset
            ? math.sin(_shake.value * math.pi) * 4.0
            : 0.0;
        final double scale = _isReset ? 1.0 : _scale.value;
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.scale(
            scale: scale,
            child: Text(
              'Combo ${widget.combo}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _comboColor(scheme),
                fontWeight: isMilestone ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Slides encouragement text in from the right with a fade.
class _AnimatedEncouragement extends StatefulWidget {
  const _AnimatedEncouragement({super.key, required this.message});
  final String message;

  @override
  State<_AnimatedEncouragement> createState() => _AnimatedEncouragementState();
}

class _AnimatedEncouragementState extends State<_AnimatedEncouragement>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TaalMotion.durationMedium,
    );
    _slide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _controller, curve: TaalMotion.curveStandard),
        );
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: TaalMotion.curveStandard),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Text(
            widget.message,
            style: TextStyle(
              color: scheme.secondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Brief screen-edge color wash for Perfect (green) and Miss (gray).
class _GradeFlashOverlay extends StatefulWidget {
  const _GradeFlashOverlay({super.key, this.grade});
  final NoteHighwayGrade? grade;

  @override
  State<_GradeFlashOverlay> createState() => _GradeFlashOverlayState();
}

class _GradeFlashOverlayState extends State<_GradeFlashOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  NoteHighwayGrade? _activeGrade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: TaalMotion.durationFast,
    );
    _opacity = Tween<double>(begin: 0.25, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: TaalMotion.curveStandard),
    );
  }

  @override
  void didUpdateWidget(covariant _GradeFlashOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.grade != oldWidget.grade && widget.grade != null) {
      if (widget.grade == NoteHighwayGrade.perfect ||
          widget.grade == NoteHighwayGrade.miss) {
        _activeGrade = widget.grade;
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _flashColor() {
    return switch (_activeGrade) {
      NoteHighwayGrade.perfect => TaalColors.gradePerfect,
      NoteHighwayGrade.miss => TaalColors.gradeMiss,
      _ => Colors.transparent,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (_activeGrade == null || _opacity.value <= 0) {
          return const SizedBox.shrink();
        }
        return Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    _flashColor().withValues(alpha: _opacity.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
