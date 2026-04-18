import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:taal/design/colors.dart';
import 'package:taal/features/player/layout_compatibility/layout_compatibility.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';
import 'package:taal/features/player/practice_mode/practice_mode_screen.dart';
import 'package:taal/platform/audio/metronome_audio.dart';
import 'package:taal/src/rust/api/practice_runtime.dart' as rust;

abstract class PracticeRuntimeEngine {
  int clockNs();

  PracticeRuntimeStart startSession({
    required String lessonJson,
    required String layoutJson,
    required String scoringProfileJson,
    required String? deviceProfileJson,
    required PracticeRuntimeMode mode,
    required double bpm,
    required int startTimeNs,
    required int lookaheadMs,
  });

  List<PracticeRuntimeEvent> submitTouchHit({
    required int sessionId,
    required String laneId,
    required int velocity,
    required int timestampNs,
  });

  List<PracticeRuntimeEvent> submitMidiNoteOn({
    required int sessionId,
    required int channel,
    required int note,
    required int velocity,
    required int timestampNs,
  });

  List<PracticeRuntimeEvent> submitMidiControlChange({
    required int sessionId,
    required int channel,
    required int controller,
    required int value,
    required int timestampNs,
  });

  List<PracticeRuntimeEvent> tick({required int sessionId, required int nowNs});

  List<PracticeRuntimeEvent> drainEvents(int sessionId);

  List<PracticeRuntimeEvent> pause(int sessionId);

  List<PracticeRuntimeEvent> resume(int sessionId);

  PracticeRuntimeStop stop(int sessionId);

  void disposeSession(int sessionId);
}

class RustPracticeRuntimeEngine implements PracticeRuntimeEngine {
  @override
  int clockNs() => rust.practiceRuntimeClockNs();

  @override
  PracticeRuntimeStart startSession({
    required String lessonJson,
    required String layoutJson,
    required String scoringProfileJson,
    required String? deviceProfileJson,
    required PracticeRuntimeMode mode,
    required double bpm,
    required int startTimeNs,
    required int lookaheadMs,
  }) {
    final result = rust.startPracticeRuntimeSession(
      request: rust.PracticeRuntimeStartRequest(
        lessonJson: lessonJson,
        layoutJson: layoutJson,
        scoringProfileJson: scoringProfileJson,
        deviceProfileJson: deviceProfileJson,
        mode: mode.toRust(),
        bpm: bpm,
        startTimeNs: startTimeNs,
        lookaheadMs: lookaheadMs,
      ),
    );
    if (result.error case final error?) {
      throw PracticeRuntimeException(error);
    }
    return PracticeRuntimeStart(
      sessionId: result.sessionId!,
      timeline: PracticeRuntimeTimeline.fromJson(
        _decodeObject(result.timelineJson!),
      ),
    );
  }

  @override
  List<PracticeRuntimeEvent> submitTouchHit({
    required int sessionId,
    required String laneId,
    required int velocity,
    required int timestampNs,
  }) {
    final result = rust.practiceRuntimeSubmitTouchHit(
      sessionId: sessionId,
      laneId: laneId,
      velocity: velocity,
      timestampNs: timestampNs,
    );
    return _eventsFromOperation(result);
  }

  @override
  List<PracticeRuntimeEvent> submitMidiNoteOn({
    required int sessionId,
    required int channel,
    required int note,
    required int velocity,
    required int timestampNs,
  }) {
    final result = rust.practiceRuntimeSubmitMidiNoteOn(
      sessionId: sessionId,
      channel: channel,
      note: note,
      velocity: velocity,
      timestampNs: timestampNs,
    );
    return _eventsFromOperation(result);
  }

  @override
  List<PracticeRuntimeEvent> submitMidiControlChange({
    required int sessionId,
    required int channel,
    required int controller,
    required int value,
    required int timestampNs,
  }) {
    final result = rust.practiceRuntimeSubmitMidiControlChange(
      sessionId: sessionId,
      channel: channel,
      controller: controller,
      value: value,
      timestampNs: timestampNs,
    );
    return _eventsFromOperation(result);
  }

  @override
  List<PracticeRuntimeEvent> tick({
    required int sessionId,
    required int nowNs,
  }) {
    final result = rust.practiceRuntimeTick(sessionId: sessionId, nowNs: nowNs);
    return _eventsFromOperation(result);
  }

  @override
  List<PracticeRuntimeEvent> drainEvents(int sessionId) {
    return _eventsFromOperation(
      rust.practiceRuntimeDrainEvents(sessionId: sessionId),
    );
  }

  @override
  List<PracticeRuntimeEvent> pause(int sessionId) {
    return _eventsFromOperation(
      rust.practiceRuntimePause(sessionId: sessionId),
    );
  }

  @override
  List<PracticeRuntimeEvent> resume(int sessionId) {
    return _eventsFromOperation(
      rust.practiceRuntimeResume(sessionId: sessionId),
    );
  }

  @override
  PracticeRuntimeStop stop(int sessionId) {
    final result = rust.practiceRuntimeStop(sessionId: sessionId);
    if (result.error case final error?) {
      throw PracticeRuntimeException(error);
    }
    return PracticeRuntimeStop(
      summaryJson: result.summaryJson!,
      events: PracticeRuntimeEvent.listFromJson(result.eventsJson!),
    );
  }

  @override
  void disposeSession(int sessionId) {
    final result = rust.practiceRuntimeDispose(sessionId: sessionId);
    if (result.error case final error?) {
      throw PracticeRuntimeException(error);
    }
  }
}

class PracticeModeRuntimeAdapter extends ChangeNotifier {
  PracticeModeRuntimeAdapter({
    required this.controller,
    required this.engine,
    this.audioOutput,
  });

  final PracticeModeController controller;
  final PracticeRuntimeEngine engine;
  final MetronomeAudioOutput? audioOutput;

  int? _sessionId;
  int? _sessionStartTimeNs;
  PracticeRuntimeTimeline? _timeline;
  PracticeRuntimeMode? _mode;
  double? _autoPauseFirstMissMs;
  double? _autoPauseLastMissMs;
  bool _playKitHitSounds = false;
  final List<PracticeFeedbackMarker> _feedback = [];

  int? get sessionId => _sessionId;

  PracticeRuntimeTimeline? get timeline => _timeline;

  List<PracticeFeedbackMarker> get feedback => List.unmodifiable(_feedback);

  bool get hasSession => _sessionId != null;

  PracticeRuntimeTimeline start({
    required String lessonJson,
    required String layoutJson,
    required String scoringProfileJson,
    String? deviceProfileJson,
    PracticeRuntimeMode mode = PracticeRuntimeMode.practice,
    required double bpm,
    int? startTimeNs,
    int lookaheadMs = 250,
    bool playKitHitSounds = false,
  }) {
    final effectiveStartTimeNs = startTimeNs ?? engine.clockNs();
    final start = engine.startSession(
      lessonJson: lessonJson,
      layoutJson: layoutJson,
      scoringProfileJson: scoringProfileJson,
      deviceProfileJson: deviceProfileJson,
      mode: mode,
      bpm: bpm,
      startTimeNs: effectiveStartTimeNs,
      lookaheadMs: lookaheadMs,
    );
    _sessionId = start.sessionId;
    _sessionStartTimeNs = effectiveStartTimeNs;
    _timeline = start.timeline;
    _mode = mode;
    _playKitHitSounds = playKitHitSounds;
    _resetAutoPauseMissWindow();
    _feedback.clear();
    controller.seekTo(0);
    notifyListeners();
    return start.timeline;
  }

  void submitTouchHit({
    required String laneId,
    int velocity = 96,
    int? timestampNs,
  }) {
    final id = _requireSession();
    _resumeFromAutoPauseIfNeeded(id);
    _applyEvents(
      engine.submitTouchHit(
        sessionId: id,
        laneId: laneId,
        velocity: velocity,
        timestampNs: timestampNs ?? engine.clockNs(),
      ),
    );
  }

  void submitMidiNoteOn({
    required int channel,
    required int note,
    required int velocity,
    int? timestampNs,
  }) {
    final id = _requireSession();
    _resumeFromAutoPauseIfNeeded(id);
    _applyEvents(
      engine.submitMidiNoteOn(
        sessionId: id,
        channel: channel,
        note: note,
        velocity: velocity,
        timestampNs: timestampNs ?? engine.clockNs(),
      ),
    );
  }

  void submitMidiControlChange({
    required int channel,
    required int controllerNumber,
    required int value,
    int? timestampNs,
  }) {
    final id = _requireSession();
    _applyEvents(
      engine.submitMidiControlChange(
        sessionId: id,
        channel: channel,
        controller: controllerNumber,
        value: value,
        timestampNs: timestampNs ?? engine.clockNs(),
      ),
    );
  }

  void tick({int? nowNs}) {
    final id = _requireSession();
    _applyEvents(engine.tick(sessionId: id, nowNs: nowNs ?? engine.clockNs()));
  }

  void drainEvents() {
    final id = _requireSession();
    _applyEvents(engine.drainEvents(id));
  }

  void pause() {
    final id = _requireSession();
    _resetAutoPauseMissWindow();
    _applyEvents(engine.pause(id));
    controller.pause();
  }

  void resume() {
    final id = _requireSession();
    _resetAutoPauseMissWindow();
    _applyEvents(engine.resume(id));
    controller.resume();
  }

  PracticeRuntimeStop stop() {
    final id = _requireSession();
    _resetAutoPauseMissWindow();
    final result = engine.stop(id);
    _applyEvents(result.events);
    return result;
  }

  void disposeRuntimeSession() {
    final id = _sessionId;
    if (id != null) {
      engine.disposeSession(id);
      _sessionId = null;
      _sessionStartTimeNs = null;
      _mode = null;
      _playKitHitSounds = false;
      _resetAutoPauseMissWindow();
      notifyListeners();
    }
  }

  int _requireSession() {
    final id = _sessionId;
    if (id == null) {
      throw PracticeRuntimeException(
        'Practice runtime session is not started.',
      );
    }
    return id;
  }

  void _applyEvents(
    List<PracticeRuntimeEvent> events, {
    bool allowAutoPause = true,
  }) {
    var changed = false;
    var shouldAutoPause = false;
    for (final event in events) {
      switch (event.type) {
        case PracticeRuntimeEventType.hitGraded:
          _resetAutoPauseMissWindow();
          _feedback.add(
            PracticeFeedbackMarker(
              expectedId: event.expectedId!,
              laneId: event.laneId!,
              tMs: _timeline?.noteTimeMs(event.expectedId!) ?? 0,
              deltaMs: event.deltaMs ?? 0,
              grade: event.grade!.toNoteHighwayGrade(),
            ),
          );
          controller.setRuntimeFeedback(combo: event.combo);
          changed = true;
        case PracticeRuntimeEventType.missed:
          _feedback.add(
            PracticeFeedbackMarker(
              expectedId: event.expectedId!,
              laneId: event.laneId!,
              tMs: _timeline?.noteTimeMs(event.expectedId!) ?? 0,
              deltaMs: 0,
              grade: NoteHighwayGrade.miss,
            ),
          );
          if (allowAutoPause && _shouldAutoPauseAfterMiss(event)) {
            shouldAutoPause = true;
          }
          changed = true;
        case PracticeRuntimeEventType.encouragement:
          controller.setRuntimeFeedback(encouragementText: event.text);
          changed = true;
        case PracticeRuntimeEventType.expectedPulse:
        case PracticeRuntimeEventType.comboMilestone:
        case PracticeRuntimeEventType.sectionBoundary:
        case PracticeRuntimeEventType.warning:
          break;
        case PracticeRuntimeEventType.metronomeClick:
          if (controller.metronomeEnabled) {
            _scheduleMetronomeClick(event);
          }
          break;
      }
    }
    if (changed) {
      notifyListeners();
    }
    if (shouldAutoPause) {
      _triggerAutoPause();
    }
  }

  bool _shouldAutoPauseAfterMiss(PracticeRuntimeEvent event) {
    final config = controller.autoPauseConfig;
    if (!config.enabled ||
        _mode != PracticeRuntimeMode.practice ||
        !controller.isRunning) {
      return false;
    }

    final expectedId = event.expectedId;
    final missMs = expectedId == null
        ? event.tExpectedMs
        : _timeline?.noteTimeMs(expectedId) ?? event.tExpectedMs;
    if (missMs == null) {
      return false;
    }

    final lastMissMs = _autoPauseLastMissMs;
    if (lastMissMs == null ||
        missMs < lastMissMs ||
        missMs - lastMissMs > config.activeMissGapToleranceMs) {
      _autoPauseFirstMissMs = missMs;
    }
    _autoPauseLastMissMs = missMs;

    final firstMissMs = _autoPauseFirstMissMs ?? missMs;
    return missMs - firstMissMs >= config.timeoutMs;
  }

  void _triggerAutoPause() {
    final id = _sessionId;
    final config = controller.autoPauseConfig;
    if (id == null || !config.enabled || !controller.isRunning) {
      return;
    }

    final pauseEvents = engine.pause(id);
    if (controller.triggerAutoPause()) {
      _resetAutoPauseMissWindow();
      _applyEvents(pauseEvents, allowAutoPause: false);
    }
  }

  void _resumeFromAutoPauseIfNeeded(int sessionId) {
    if (!controller.autoPauseTriggered) {
      return;
    }
    final resumeEvents = engine.resume(sessionId);
    controller.resume();
    _resetAutoPauseMissWindow();
    _applyEvents(resumeEvents, allowAutoPause: false);
  }

  void _resetAutoPauseMissWindow() {
    _autoPauseFirstMissMs = null;
    _autoPauseLastMissMs = null;
  }

  void _scheduleMetronomeClick(PracticeRuntimeEvent event) {
    final output = audioOutput;
    final startNs = _sessionStartTimeNs;
    if (output == null || startNs == null) {
      return;
    }
    final tMs = event.tMs;
    if (tMs == null) {
      return;
    }
    output.scheduleClicks(
      sessionStartTimeNs: startNs,
      clicks: [
        ScheduledMetronomeClick(
          tMs: tMs.round(),
          accent: event.accent ?? false,
        ),
      ],
    );
  }

  void scheduleDrumHitSound({
    required String laneId,
    required int velocity,
    String articulation = 'normal',
  }) {
    final output = audioOutput;
    final startNs = _sessionStartTimeNs;
    if (output == null || startNs == null) {
      return;
    }
    final nowNs = engine.clockNs();
    final offsetMs = ((nowNs - startNs) / 1000000).round();
    output.scheduleDrumHits(
      sessionStartTimeNs: startNs,
      hits: [
        ScheduledDrumHit(
          tMs: offsetMs < 0 ? 0 : offsetMs,
          laneId: laneId,
          velocity: velocity,
          articulation: articulation,
        ),
      ],
    );
  }

  bool get playKitHitSounds => _playKitHitSounds;
}

enum PracticeRuntimeMode { practice, play, courseGate }

extension PracticeRuntimeModeX on PracticeRuntimeMode {
  rust.PracticeRuntimeModeDto toRust() {
    switch (this) {
      case PracticeRuntimeMode.practice:
        return rust.PracticeRuntimeModeDto.practice;
      case PracticeRuntimeMode.play:
        return rust.PracticeRuntimeModeDto.play;
      case PracticeRuntimeMode.courseGate:
        return rust.PracticeRuntimeModeDto.courseGate;
    }
  }
}

class PracticeRuntimeStart {
  const PracticeRuntimeStart({required this.sessionId, required this.timeline});

  final int sessionId;
  final PracticeRuntimeTimeline timeline;
}

class PracticeRuntimeStop {
  const PracticeRuntimeStop({required this.summaryJson, required this.events});

  final String summaryJson;
  final List<PracticeRuntimeEvent> events;
}

class PracticeRuntimeTimeline {
  const PracticeRuntimeTimeline({
    required this.lessonId,
    required this.mode,
    required this.bpm,
    required this.totalDurationMs,
    required this.lanes,
    required this.notes,
    required this.sections,
    this.layoutCompatibility = const LayoutCompatibilitySnapshot(
      status: LayoutCompatibilityStatus.full,
      lessonLanes: [],
      requiredLanes: [],
      optionalLanes: [],
      mappedLanes: [],
      missingRequiredLanes: [],
      missingOptionalLanes: [],
      excludedLanes: [],
    ),
  });

  final String lessonId;
  final String mode;
  final double bpm;
  final double totalDurationMs;
  final List<PracticeRuntimeLane> lanes;
  final List<PracticeRuntimeNote> notes;
  final List<PracticeRuntimeSection> sections;
  final LayoutCompatibilitySnapshot layoutCompatibility;

  factory PracticeRuntimeTimeline.fromJson(Map<String, Object?> json) {
    final compatibilityJson = json['layout_compatibility'];
    return PracticeRuntimeTimeline(
      lessonId: json['lesson_id'] as String,
      mode: json['mode'] as String,
      bpm: (json['bpm'] as num).toDouble(),
      totalDurationMs: (json['total_duration_ms'] as num).toDouble(),
      lanes: _list(json['lanes'])
          .map((lane) => PracticeRuntimeLane.fromJson(_map(lane)))
          .toList(growable: false),
      notes: _list(json['notes'])
          .map((note) => PracticeRuntimeNote.fromJson(_map(note)))
          .toList(growable: false),
      sections: _list(json['sections'])
          .map((section) => PracticeRuntimeSection.fromJson(_map(section)))
          .toList(growable: false),
      layoutCompatibility: compatibilityJson == null
          ? LayoutCompatibilitySnapshot.full()
          : LayoutCompatibilitySnapshot.fromJson(_map(compatibilityJson)),
    );
  }

  List<NoteHighwayLane> toNoteHighwayLanes() {
    return [
      for (var index = 0; index < lanes.length; index += 1)
        NoteHighwayLane(
          laneId: lanes[index].laneId,
          label: lanes[index].label,
          color: _lanePalette[index % _lanePalette.length],
        ),
    ];
  }

  List<PracticeTimelineNote> toPracticeTimelineNotes() {
    return notes
        .map(
          (note) => PracticeTimelineNote(
            expectedId: note.expectedId,
            laneId: note.laneId,
            tMs: note.tMs,
            articulation: note.articulation,
          ),
        )
        .toList(growable: false);
  }

  List<PracticeSection> toPracticeSections() {
    return sections
        .map(
          (section) => PracticeSection(
            sectionId: section.sectionId,
            label: section.label,
            startMs: section.startMs,
            endMs: section.endMs,
            loopable: section.loopable,
          ),
        )
        .toList(growable: false);
  }

  double? noteTimeMs(String expectedId) {
    for (final note in notes) {
      if (note.expectedId == expectedId) {
        return note.tMs;
      }
    }
    return null;
  }
}

class PracticeRuntimeLane {
  const PracticeRuntimeLane({
    required this.laneId,
    required this.label,
    required this.slotId,
  });

  final String laneId;
  final String label;
  final String slotId;

  factory PracticeRuntimeLane.fromJson(Map<String, Object?> json) {
    return PracticeRuntimeLane(
      laneId: json['lane_id'] as String,
      label: json['label'] as String,
      slotId: json['slot_id'] as String,
    );
  }
}

class PracticeRuntimeNote {
  const PracticeRuntimeNote({
    required this.expectedId,
    required this.laneId,
    required this.tMs,
    required this.articulation,
  });

  final String expectedId;
  final String laneId;
  final double tMs;
  final String articulation;

  factory PracticeRuntimeNote.fromJson(Map<String, Object?> json) {
    return PracticeRuntimeNote(
      expectedId: json['expected_id'] as String,
      laneId: json['lane_id'] as String,
      tMs: (json['t_ms'] as num).toDouble(),
      articulation: json['articulation'] as String,
    );
  }
}

class PracticeRuntimeSection {
  const PracticeRuntimeSection({
    required this.sectionId,
    required this.label,
    required this.startMs,
    required this.endMs,
    required this.loopable,
  });

  final String sectionId;
  final String label;
  final double startMs;
  final double endMs;
  final bool loopable;

  factory PracticeRuntimeSection.fromJson(Map<String, Object?> json) {
    return PracticeRuntimeSection(
      sectionId: json['section_id'] as String,
      label: json['label'] as String,
      startMs: (json['start_ms'] as num).toDouble(),
      endMs: (json['end_ms'] as num).toDouble(),
      loopable: json['loopable'] as bool,
    );
  }
}

enum PracticeRuntimeEventType {
  expectedPulse,
  hitGraded,
  missed,
  comboMilestone,
  encouragement,
  sectionBoundary,
  metronomeClick,
  warning,
}

enum PracticeRuntimeGrade { perfect, good, early, late, miss }

extension PracticeRuntimeGradeX on PracticeRuntimeGrade {
  NoteHighwayGrade toNoteHighwayGrade() {
    switch (this) {
      case PracticeRuntimeGrade.perfect:
        return NoteHighwayGrade.perfect;
      case PracticeRuntimeGrade.good:
        return NoteHighwayGrade.good;
      case PracticeRuntimeGrade.early:
        return NoteHighwayGrade.early;
      case PracticeRuntimeGrade.late:
        return NoteHighwayGrade.late;
      case PracticeRuntimeGrade.miss:
        return NoteHighwayGrade.miss;
    }
  }
}

class PracticeRuntimeEvent {
  const PracticeRuntimeEvent({
    required this.type,
    this.expectedId,
    this.laneId,
    this.tExpectedMs,
    this.grade,
    this.deltaMs,
    this.combo,
    this.streak,
    this.scoreRunning,
    this.messageId,
    this.text,
    this.sectionId,
    this.entering,
    this.tMs,
    this.accent,
    this.code,
    this.message,
  });

  final PracticeRuntimeEventType type;
  final String? expectedId;
  final String? laneId;
  final double? tExpectedMs;
  final PracticeRuntimeGrade? grade;
  final double? deltaMs;
  final int? combo;
  final int? streak;
  final double? scoreRunning;
  final String? messageId;
  final String? text;
  final String? sectionId;
  final bool? entering;
  final double? tMs;
  final bool? accent;
  final String? code;
  final String? message;

  factory PracticeRuntimeEvent.fromJson(Map<String, Object?> json) {
    final type = _eventType(json['type'] as String);
    return PracticeRuntimeEvent(
      type: type,
      expectedId: json['expected_id'] as String?,
      laneId: json['lane_id'] as String?,
      tExpectedMs: (json['t_expected_ms'] as num?)?.toDouble(),
      grade: _grade(json['grade'] as String?),
      deltaMs: (json['delta_ms'] as num?)?.toDouble(),
      combo: json['combo'] as int?,
      streak: json['streak'] as int?,
      scoreRunning: (json['score_running'] as num?)?.toDouble(),
      messageId: json['message_id'] as String?,
      text: json['text'] as String?,
      sectionId: json['section_id'] as String?,
      entering: json['entering'] as bool?,
      tMs: (json['t_ms'] as num?)?.toDouble(),
      accent: json['accent'] as bool?,
      code: json['code'] as String?,
      message: json['message'] as String?,
    );
  }

  static List<PracticeRuntimeEvent> listFromJson(String eventsJson) {
    return _list(jsonDecode(eventsJson))
        .map((event) => PracticeRuntimeEvent.fromJson(_map(event)))
        .toList(growable: false);
  }
}

class PracticeRuntimeException implements Exception {
  PracticeRuntimeException(this.message);

  final String message;

  @override
  String toString() => message;
}

List<PracticeRuntimeEvent> _eventsFromOperation(
  rust.PracticeRuntimeOperationResult result,
) {
  if (result.error case final error?) {
    throw PracticeRuntimeException(error);
  }
  return PracticeRuntimeEvent.listFromJson(result.eventsJson ?? '[]');
}

Map<String, Object?> _decodeObject(String json) {
  return _map(jsonDecode(json));
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw PracticeRuntimeException('Expected JSON object.');
}

List<Object?> _list(Object? value) {
  if (value is List<Object?>) {
    return value;
  }
  throw PracticeRuntimeException('Expected JSON list.');
}

PracticeRuntimeEventType _eventType(String value) {
  switch (value) {
    case 'expected_pulse':
      return PracticeRuntimeEventType.expectedPulse;
    case 'hit_graded':
      return PracticeRuntimeEventType.hitGraded;
    case 'missed':
      return PracticeRuntimeEventType.missed;
    case 'combo_milestone':
      return PracticeRuntimeEventType.comboMilestone;
    case 'encouragement':
      return PracticeRuntimeEventType.encouragement;
    case 'section_boundary':
      return PracticeRuntimeEventType.sectionBoundary;
    case 'metronome_click':
      return PracticeRuntimeEventType.metronomeClick;
    case 'warning':
      return PracticeRuntimeEventType.warning;
  }
  throw PracticeRuntimeException('Unknown engine event type: $value');
}

PracticeRuntimeGrade? _grade(String? value) {
  switch (value) {
    case null:
      return null;
    case 'perfect':
      return PracticeRuntimeGrade.perfect;
    case 'good':
      return PracticeRuntimeGrade.good;
    case 'early':
      return PracticeRuntimeGrade.early;
    case 'late':
      return PracticeRuntimeGrade.late;
    case 'miss':
      return PracticeRuntimeGrade.miss;
  }
  throw PracticeRuntimeException('Unknown grade: $value');
}

const _lanePalette = TaalColors.lanePalette;
