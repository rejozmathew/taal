import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/player/drum_kit/drum_kit.dart';
import 'package:taal/features/player/layout_compatibility/layout_compatibility.dart';
import 'package:taal/features/player/notation/notation_view.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';
import 'package:taal/features/player/play_mode/play_mode_screen.dart';
import 'package:taal/features/player/practice_mode/practice_mode_screen.dart';
import 'package:taal/features/player/review/post_lesson_review_screen.dart';

void main() {
  test('play controller count-in leads into a fixed-tempo full run', () {
    final controller = _controller(countInBeats: 2);

    controller.start();

    expect(controller.state, PlayModeState.countIn);
    expect(controller.lessonBpm, 120);
    expect(controller.countInRemainingBeats, 2);

    controller.advanceBy(const Duration(milliseconds: 500));

    expect(controller.state, PlayModeState.countIn);
    expect(controller.countInRemainingBeats, 1);

    controller.advanceBy(const Duration(milliseconds: 500));

    expect(controller.state, PlayModeState.running);
    expect(controller.currentTimeMs, 0);

    controller.advanceBy(const Duration(milliseconds: 1000));

    expect(controller.currentTimeMs, 1000);

    controller.advanceBy(const Duration(milliseconds: 3000));

    expect(controller.currentTimeMs, 4000);
    expect(controller.state, PlayModeState.awaitingSummary);
  });

  test('completed play run records the attempt and exposes review summary', () {
    final recorder = _FakeAttemptRecorder();
    final controller = _controller(countInBeats: 0, recorder: recorder);

    controller
      ..start()
      ..advanceBy(const Duration(milliseconds: 4000))
      ..completeRun(
        _summary,
        persistencePayload: const PlayModePersistencePayload(
          summaryJson: '{"score_total":91}',
          contextJson: '{"player_id":"player-1"}',
        ),
      );

    expect(controller.state, PlayModeState.completed);
    expect(controller.reviewSummary, _summary);
    expect(controller.storedAttemptJson, '{"id":"attempt-1"}');
    expect(controller.persistenceError, isNull);
    expect(recorder.summaryJson, '{"score_total":91}');
    expect(recorder.contextJson, '{"player_id":"player-1"}');
  });

  testWidgets('play screen has locked assessment controls and review handoff', (
    tester,
  ) async {
    final controller = _controller();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
            feedback: _feedback,
            courseProgressLabel: 'Lesson 3 of 5',
          ),
        ),
      ),
    );

    expect(find.text('Start Play Mode'), findsOneWidget);
    expect(find.text('120 BPM'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Loop'), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(_findPainter<NoteHighwayPainter>(), findsOneWidget);

    await tester.tap(find.text('Start Play Mode'));
    await tester.pump();

    expect(controller.state, PlayModeState.countIn);
    expect(find.text('Count-in'), findsWidgets);
    expect(find.byKey(const ValueKey('count-in-beats')), findsOneWidget);

    controller
      ..advanceBy(const Duration(milliseconds: 2000))
      ..completeRun(_summary);
    await tester.pumpAndSettle();

    expect(find.byType(PostLessonReviewScreen), findsOneWidget);
    expect(find.text('Play Check'), findsOneWidget);
    expect(find.text('91'), findsOneWidget);
    expect(find.text('Lesson 3 of 5'), findsOneWidget);
  });

  testWidgets('play screen switches views without changing run state', (
    tester,
  ) async {
    final controller = _controller(countInBeats: 0)..start();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
            feedback: _feedback,
          ),
        ),
      ),
    );

    expect(_findPainter<NoteHighwayPainter>(), findsOneWidget);
    expect(controller.state, PlayModeState.running);

    controller.selectView(PracticeDisplayView.notation);
    await tester.pump();

    expect(_findPainter<NotationViewPainter>(), findsOneWidget);
    expect(controller.state, PlayModeState.running);

    controller.selectView(PracticeDisplayView.drumKit);
    await tester.pump();

    expect(_findPainter<VisualDrumKitPainter>(), findsOneWidget);
    expect(controller.state, PlayModeState.running);
  });

  testWidgets('play screen flags partial compatibility through review', (
    tester,
  ) async {
    final controller = _controller(countInBeats: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlayModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
            feedback: _feedback,
            layoutCompatibility: _requiredMissingCompatibility,
          ),
        ),
      ),
    );

    expect(find.text('Partial compatibility'), findsOneWidget);
    expect(
      find.text('Partial compatibility: 1 lane unavailable.'),
      findsOneWidget,
    );

    controller
      ..start()
      ..advanceBy(const Duration(milliseconds: 4000))
      ..completeRun(_summary);
    await tester.pumpAndSettle();

    expect(find.byType(PostLessonReviewScreen), findsOneWidget);
    expect(
      find.text('Scoring adjusted: 1 lane unavailable on current kit (Snare).'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Partial compatibility results do not qualify as personal bests.',
      ),
      findsOneWidget,
    );
  });
}

class _FakeAttemptRecorder implements PlayModeAttemptRecorder {
  String? summaryJson;
  String? contextJson;

  @override
  PlayModeAttemptRecordResult recordAttempt({
    required String summaryJson,
    required String contextJson,
  }) {
    this.summaryJson = summaryJson;
    this.contextJson = contextJson;
    return const PlayModeAttemptRecordResult(attemptJson: '{"id":"attempt-1"}');
  }
}

PlayModeController _controller({
  int countInBeats = 4,
  PlayModeAttemptRecorder? recorder,
}) {
  return PlayModeController(
    lessonTitle: 'Play Check',
    lessonBpm: 120,
    totalDurationMs: 4000,
    countInBeats: countInBeats,
    attemptRecorder: recorder,
  );
}

Finder _findPainter<T extends CustomPainter>() {
  return find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is T,
  );
}

const _lanes = [
  NoteHighwayLane(laneId: 'kick', label: 'Kick', color: Color(0xFF16A085)),
  NoteHighwayLane(laneId: 'snare', label: 'Snare', color: Color(0xFFE0B44C)),
];

const _notes = [
  PracticeTimelineNote(expectedId: 'kick-1', laneId: 'kick', tMs: 1000),
  PracticeTimelineNote(expectedId: 'snare-1', laneId: 'snare', tMs: 1500),
];

const _feedback = [
  PracticeFeedbackMarker(
    expectedId: 'kick-1',
    laneId: 'kick',
    tMs: 1000,
    deltaMs: 0,
    grade: NoteHighwayGrade.perfect,
  ),
];

const _summary = PostLessonAttemptSummary(
  lessonTitle: 'Play Check',
  scoreTotal: 91,
  accuracyPct: 93,
  hitRatePct: 94,
  perfectPct: 66,
  earlyPct: 12,
  latePct: 8,
  missPct: 3,
  maxStreak: 24,
  meanDeltaMs: 4,
  stdDeltaMs: 13,
  medianDeltaMs: 3,
  p90AbsDeltaMs: 28,
  bpm: 120,
  durationMs: 4000,
  laneStats: {
    'snare': PostLessonLaneStats(
      hitRatePct: 95,
      missPct: 2,
      meanDeltaMs: 3,
      stdDeltaMs: 11,
    ),
    'kick': PostLessonLaneStats(
      hitRatePct: 92,
      missPct: 4,
      meanDeltaMs: 8,
      stdDeltaMs: 15,
    ),
  },
);

const _requiredMissingCompatibility = LayoutCompatibilitySnapshot(
  status: LayoutCompatibilityStatus.requiredMissing,
  lessonLanes: ['kick', 'snare'],
  requiredLanes: ['kick', 'snare'],
  optionalLanes: [],
  mappedLanes: ['kick'],
  missingRequiredLanes: ['snare'],
  missingOptionalLanes: [],
  excludedLanes: ['snare'],
);
