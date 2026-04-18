import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';
import 'package:taal/features/player/practice_mode/practice_mode_screen.dart';
import 'package:taal/features/player/practice_runtime/practice_runtime.dart';

void main() {
  test('runtime adapter maps touch and MIDI engine events into feedback', () {
    final controller = PracticeModeController(
      baseBpm: 120,
      totalDurationMs: 2000,
    );
    final engine = _FakePracticeRuntimeEngine();
    final adapter = PracticeModeRuntimeAdapter(
      controller: controller,
      engine: engine,
    );

    adapter.start(
      lessonJson: '{}',
      layoutJson: '{}',
      scoringProfileJson: '{}',
      deviceProfileJson: '{}',
      bpm: 120,
      startTimeNs: 10,
    );

    adapter.submitTouchHit(laneId: 'kick', timestampNs: 15);
    expect(engine.touchHits.single.laneId, 'kick');
    expect(adapter.feedback.single.expectedId, 'kick-1');
    expect(adapter.feedback.single.tMs, 0);
    expect(adapter.feedback.single.grade, NoteHighwayGrade.perfect);
    expect(controller.combo, 1);

    adapter.submitMidiNoteOn(
      channel: 9,
      note: 38,
      velocity: 100,
      timestampNs: 505000010,
    );

    expect(engine.midiNotes.single.note, 38);
    expect(adapter.feedback, hasLength(2));
    expect(adapter.feedback.last.expectedId, 'snare-1');
    expect(adapter.feedback.last.tMs, 500);
    expect(adapter.feedback.last.grade, NoteHighwayGrade.early);
    expect(controller.combo, 2);
    expect(controller.encouragementText, 'Keep it steady');
  });

  test('runtime adapter records misses from the same event stream', () {
    final controller = PracticeModeController(
      baseBpm: 120,
      totalDurationMs: 2000,
    );
    final engine = _FakePracticeRuntimeEngine();
    final adapter = PracticeModeRuntimeAdapter(
      controller: controller,
      engine: engine,
    );

    adapter.start(
      lessonJson: '{}',
      layoutJson: '{}',
      scoringProfileJson: '{}',
      bpm: 120,
      startTimeNs: 10,
    );

    adapter.tick(nowNs: 700000010);

    expect(adapter.feedback.single.expectedId, 'snare-1');
    expect(adapter.feedback.single.grade, NoteHighwayGrade.miss);
  });

  test(
    'runtime adapter auto-pauses dense missed passages and resumes on hit',
    () {
      final controller = PracticeModeController(
        baseBpm: 120,
        totalDurationMs: 3000,
        autoPauseConfig: const PracticeAutoPauseConfig(
          enabled: true,
          timeoutMs: 1000,
          activeMissGapToleranceMs: 600,
        ),
      );
      final engine = _FakePracticeRuntimeEngine()
        ..tickResponses.addAll([
          const [
            PracticeRuntimeEvent(
              type: PracticeRuntimeEventType.missed,
              expectedId: 'kick-1',
              laneId: 'kick',
            ),
          ],
          const [
            PracticeRuntimeEvent(
              type: PracticeRuntimeEventType.missed,
              expectedId: 'snare-1',
              laneId: 'snare',
            ),
          ],
          const [
            PracticeRuntimeEvent(
              type: PracticeRuntimeEventType.missed,
              expectedId: 'snare-2',
              laneId: 'snare',
            ),
          ],
        ]);
      final adapter = PracticeModeRuntimeAdapter(
        controller: controller,
        engine: engine,
      );

      adapter.start(
        lessonJson: '{}',
        layoutJson: '{}',
        scoringProfileJson: '{}',
        bpm: 120,
        startTimeNs: 10,
      );
      controller.play();

      adapter.tick(nowNs: 10);
      adapter.tick(nowNs: 500000010);
      expect(controller.transportState, PracticeTransportState.running);

      adapter.tick(nowNs: 1000000010);

      expect(engine.pauseCount, 1);
      expect(controller.transportState, PracticeTransportState.paused);
      expect(controller.autoPauseTriggered, isTrue);

      adapter.submitTouchHit(laneId: 'kick', timestampNs: 1000000020);

      expect(engine.resumeCount, 1);
      expect(controller.transportState, PracticeTransportState.running);
      expect(controller.autoPauseTriggered, isFalse);
      expect(engine.touchHits.single.laneId, 'kick');
    },
  );

  test('runtime adapter does not auto-pause across intentional rests', () {
    final controller = PracticeModeController(
      baseBpm: 120,
      totalDurationMs: 4000,
      autoPauseConfig: const PracticeAutoPauseConfig(
        enabled: true,
        timeoutMs: 1000,
        activeMissGapToleranceMs: 600,
      ),
    );
    final engine = _FakePracticeRuntimeEngine()
      ..tickResponses.addAll([
        const [
          PracticeRuntimeEvent(
            type: PracticeRuntimeEventType.missed,
            expectedId: 'kick-1',
            laneId: 'kick',
          ),
        ],
        const [
          PracticeRuntimeEvent(
            type: PracticeRuntimeEventType.missed,
            expectedId: 'crash-1',
            laneId: 'crash',
          ),
        ],
      ]);
    final adapter = PracticeModeRuntimeAdapter(
      controller: controller,
      engine: engine,
    );

    adapter.start(
      lessonJson: '{}',
      layoutJson: '{}',
      scoringProfileJson: '{}',
      bpm: 120,
      startTimeNs: 10,
    );
    controller.play();

    adapter.tick(nowNs: 10);
    adapter.tick(nowNs: 2500000010);

    expect(engine.pauseCount, 0);
    expect(controller.transportState, PracticeTransportState.running);
    expect(controller.autoPauseTriggered, isFalse);
  });

  test('runtime adapter keeps auto-pause scoped to Practice Mode', () {
    final controller = PracticeModeController(
      baseBpm: 120,
      totalDurationMs: 3000,
      autoPauseConfig: const PracticeAutoPauseConfig(
        enabled: true,
        timeoutMs: 1000,
        activeMissGapToleranceMs: 600,
      ),
    );
    final engine = _FakePracticeRuntimeEngine()
      ..tickResponses.addAll([
        const [
          PracticeRuntimeEvent(
            type: PracticeRuntimeEventType.missed,
            expectedId: 'kick-1',
            laneId: 'kick',
          ),
        ],
        const [
          PracticeRuntimeEvent(
            type: PracticeRuntimeEventType.missed,
            expectedId: 'snare-1',
            laneId: 'snare',
          ),
        ],
        const [
          PracticeRuntimeEvent(
            type: PracticeRuntimeEventType.missed,
            expectedId: 'snare-2',
            laneId: 'snare',
          ),
        ],
      ]);
    final adapter = PracticeModeRuntimeAdapter(
      controller: controller,
      engine: engine,
    );

    adapter.start(
      lessonJson: '{}',
      layoutJson: '{}',
      scoringProfileJson: '{}',
      mode: PracticeRuntimeMode.play,
      bpm: 120,
      startTimeNs: 10,
    );
    controller.play();

    adapter.tick(nowNs: 10);
    adapter.tick(nowNs: 500000010);
    adapter.tick(nowNs: 1000000010);

    expect(engine.pauseCount, 0);
    expect(controller.transportState, PracticeTransportState.running);
  });
}

class _FakePracticeRuntimeEngine implements PracticeRuntimeEngine {
  final touchHits = <_TouchSubmission>[];
  final midiNotes = <_MidiNoteSubmission>[];
  final tickResponses = <List<PracticeRuntimeEvent>>[];
  int pauseCount = 0;
  int resumeCount = 0;

  @override
  int clockNs() => 10;

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
    return PracticeRuntimeStart(sessionId: 7, timeline: _timeline);
  }

  @override
  List<PracticeRuntimeEvent> submitTouchHit({
    required int sessionId,
    required String laneId,
    required int velocity,
    required int timestampNs,
  }) {
    touchHits.add(_TouchSubmission(laneId, velocity, timestampNs));
    return const [
      PracticeRuntimeEvent(
        type: PracticeRuntimeEventType.hitGraded,
        expectedId: 'kick-1',
        laneId: 'kick',
        grade: PracticeRuntimeGrade.perfect,
        deltaMs: 5,
        combo: 1,
        streak: 1,
        scoreRunning: 50,
      ),
    ];
  }

  @override
  List<PracticeRuntimeEvent> submitMidiNoteOn({
    required int sessionId,
    required int channel,
    required int note,
    required int velocity,
    required int timestampNs,
  }) {
    midiNotes.add(_MidiNoteSubmission(channel, note, velocity, timestampNs));
    return const [
      PracticeRuntimeEvent(
        type: PracticeRuntimeEventType.hitGraded,
        expectedId: 'snare-1',
        laneId: 'snare',
        grade: PracticeRuntimeGrade.early,
        deltaMs: -35,
        combo: 2,
        streak: 1,
        scoreRunning: 75,
      ),
      PracticeRuntimeEvent(
        type: PracticeRuntimeEventType.encouragement,
        messageId: 'combo-2',
        text: 'Keep it steady',
      ),
    ];
  }

  @override
  List<PracticeRuntimeEvent> submitMidiControlChange({
    required int sessionId,
    required int channel,
    required int controller,
    required int value,
    required int timestampNs,
  }) {
    return const [];
  }

  @override
  List<PracticeRuntimeEvent> tick({
    required int sessionId,
    required int nowNs,
  }) {
    if (tickResponses.isNotEmpty) {
      return tickResponses.removeAt(0);
    }
    return const [
      PracticeRuntimeEvent(
        type: PracticeRuntimeEventType.missed,
        expectedId: 'snare-1',
        laneId: 'snare',
      ),
    ];
  }

  @override
  List<PracticeRuntimeEvent> drainEvents(int sessionId) => const [];

  @override
  List<PracticeRuntimeEvent> pause(int sessionId) {
    pauseCount += 1;
    return const [];
  }

  @override
  List<PracticeRuntimeEvent> resume(int sessionId) {
    resumeCount += 1;
    return const [];
  }

  @override
  PracticeRuntimeStop stop(int sessionId) {
    return const PracticeRuntimeStop(summaryJson: '{}', events: []);
  }

  @override
  void disposeSession(int sessionId) {}
}

class _TouchSubmission {
  const _TouchSubmission(this.laneId, this.velocity, this.timestampNs);

  final String laneId;
  final int velocity;
  final int timestampNs;
}

class _MidiNoteSubmission {
  const _MidiNoteSubmission(
    this.channel,
    this.note,
    this.velocity,
    this.timestampNs,
  );

  final int channel;
  final int note;
  final int velocity;
  final int timestampNs;
}

const _timeline = PracticeRuntimeTimeline(
  lessonId: '550e8400-e29b-41d4-a716-446655440231',
  mode: 'practice',
  bpm: 120,
  totalDurationMs: 2000,
  lanes: [
    PracticeRuntimeLane(laneId: 'kick', label: 'Kick', slotId: 'kick'),
    PracticeRuntimeLane(laneId: 'snare', label: 'Snare', slotId: 'snare'),
  ],
  notes: [
    PracticeRuntimeNote(
      expectedId: 'kick-1',
      laneId: 'kick',
      tMs: 0,
      articulation: 'normal',
    ),
    PracticeRuntimeNote(
      expectedId: 'snare-1',
      laneId: 'snare',
      tMs: 500,
      articulation: 'normal',
    ),
    PracticeRuntimeNote(
      expectedId: 'snare-2',
      laneId: 'snare',
      tMs: 1000,
      articulation: 'normal',
    ),
    PracticeRuntimeNote(
      expectedId: 'crash-1',
      laneId: 'crash',
      tMs: 2500,
      articulation: 'normal',
    ),
  ],
  sections: [
    PracticeRuntimeSection(
      sectionId: 'main',
      label: 'Main',
      startMs: 0,
      endMs: 2000,
      loopable: true,
    ),
  ],
);
