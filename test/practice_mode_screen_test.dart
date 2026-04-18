import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/player/drum_kit/drum_kit.dart';
import 'package:taal/features/player/layout_compatibility/layout_compatibility.dart';
import 'package:taal/features/player/notation/notation_view.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';
import 'package:taal/features/player/practice_mode/practice_mode_screen.dart';
import 'package:taal/features/player/tap_pads/tap_pad_surface.dart';
import 'package:taal/platform/audio/metronome_audio.dart';

void main() {
  test('practice controller starts pauses and resumes transport', () {
    final controller = _controller();

    controller.play();
    expect(controller.transportState, PracticeTransportState.running);

    controller.pause();
    expect(controller.transportState, PracticeTransportState.paused);

    controller.resume();
    expect(controller.transportState, PracticeTransportState.running);
  });

  test('tempo change records the next beat and changes transport speed', () {
    final controller = _controller()..seekTo(750);

    controller.setTempoBpm(90);

    expect(controller.tempoBpm, 90);
    expect(controller.tempoChangeEffectiveAtMs, 1000);

    controller.play();
    controller.advanceBy(const Duration(milliseconds: 1000));

    expect(controller.currentTimeMs, 1500);
  });

  test('enabled loop wraps playback inside the selected section', () {
    final controller = _controller()
      ..selectLoopSection('main')
      ..setLoopEnabled(true)
      ..seekTo(3900)
      ..play();

    controller.advanceBy(const Duration(milliseconds: 300));

    expect(controller.currentTimeMs, 2200);
  });

  test(
    'daily goal progress composes persisted minutes with session elapsed',
    () {
      final controller = _controller()..play();
      const goal = DailyGoalProgress(
        persistedTodayMinutesCompleted: 8,
        dailyGoalMinutes: 10,
      );

      controller.advanceBy(const Duration(seconds: 30));

      expect(controller.activeSessionElapsedMs, 30000);
      expect(
        goal.completedMinutesWithSession(controller.activeSessionElapsedMs),
        8.5,
      );
      expect(goal.progressWithSession(controller.activeSessionElapsedMs), 0.85);
    },
  );

  test('listen mode advances the timeline without scoring session time', () {
    final controller = _controller();

    controller.beginListening(startMs: 2000, endMs: 4000);
    controller.advanceBy(const Duration(milliseconds: 500));

    expect(controller.transportState, PracticeTransportState.listening);
    expect(controller.currentTimeMs, 2500);
    expect(controller.activeSessionElapsedMs, 0);

    controller.advanceBy(const Duration(seconds: 2));

    expect(controller.transportState, PracticeTransportState.stopped);
    expect(controller.currentTimeMs, 4000);
  });

  test('listen scheduling uses the selected range and adjusted tempo', () {
    final controller = _controller()
      ..selectLoopSection('main')
      ..setListenScope(PracticeListenScope.selectedRange)
      ..setTempoBpm(60);

    final hits = PracticeListenPlayback.scheduledHitsFor(
      notes: const [
        PracticeTimelineNote(expectedId: 'before', laneId: 'kick', tMs: 1500),
        PracticeTimelineNote(expectedId: 'kick-2', laneId: 'kick', tMs: 2000),
        PracticeTimelineNote(
          expectedId: 'snare-2',
          laneId: 'snare',
          tMs: 2500,
          articulation: 'rim',
        ),
        PracticeTimelineNote(expectedId: 'after', laneId: 'crash', tMs: 4500),
      ],
      range: controller.listenRange,
      baseBpm: controller.baseBpm,
      tempoBpm: controller.tempoBpm,
    );

    expect(hits.map((hit) => hit.tMs), [0, 1000]);
    expect(hits.map((hit) => hit.laneId), ['kick', 'snare']);
    expect(hits.last.articulation, 'rim');
  });

  test('auto-pause is disabled by default and clears on resume', () {
    final controller = _controller()..play();

    expect(controller.triggerAutoPause(), isFalse);
    expect(controller.transportState, PracticeTransportState.running);

    controller.setAutoPauseConfig(
      const PracticeAutoPauseConfig(enabled: true, timeoutMs: 3000),
    );

    expect(controller.triggerAutoPause(), isTrue);
    expect(controller.transportState, PracticeTransportState.paused);
    expect(controller.autoPauseTriggered, isTrue);

    controller.resume();

    expect(controller.transportState, PracticeTransportState.running);
    expect(controller.autoPauseTriggered, isFalse);
  });

  testWidgets('practice screen switches all three views without reset', (
    tester,
  ) async {
    final controller = _controller()..play();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
            feedback: _feedback,
          ),
        ),
      ),
    );

    expect(_findPainter<NoteHighwayPainter>(), findsOneWidget);
    expect(controller.transportState, PracticeTransportState.running);

    controller.selectView(PracticeDisplayView.notation);
    await tester.pump();

    expect(_findPainter<NotationViewPainter>(), findsOneWidget);
    expect(controller.transportState, PracticeTransportState.running);

    controller.selectView(PracticeDisplayView.drumKit);
    await tester.pump();

    expect(_findPainter<VisualDrumKitPainter>(), findsOneWidget);
    expect(controller.transportState, PracticeTransportState.running);
  });

  testWidgets('transport controls update controller state', (tester) async {
    final controller = _controller();
    final audio = _FakeMetronomeAudioOutput();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
            listenPlayback: PracticeListenPlayback(
              audioOutput: audio,
              clockNowNs: () => 123,
            ),
            dailyGoalProgress: const DailyGoalProgress(
              persistedTodayMinutesCompleted: 8,
              dailyGoalMinutes: 10,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Play'));
    await tester.pump();

    expect(controller.transportState, PracticeTransportState.running);
    expect(find.text('Pause'), findsOneWidget);

    controller.advanceBy(const Duration(seconds: 30));
    await tester.pump();

    expect(find.text('Daily goal 8.5 / 10 min'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();

    expect(controller.transportState, PracticeTransportState.paused);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('listen button schedules playback and toggles stop listening', (
    tester,
  ) async {
    final controller = _controller()..setTempoBpm(60);
    final audio = _FakeMetronomeAudioOutput();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
            listenPlayback: PracticeListenPlayback(
              audioOutput: audio,
              clockNowNs: () => 987,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('practice-listen-button')));
    await tester.pump();

    expect(controller.transportState, PracticeTransportState.listening);
    expect(audio.sessionStartTimeNs, 987);
    expect(audio.scheduledDrumHits.map((hit) => hit.tMs), [2000, 3000]);
    expect(find.text('Stop Listening'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('practice-listen-button')));
    await tester.pump();

    expect(controller.transportState, PracticeTransportState.stopped);
    expect(audio.stopCount, 2);
    expect(find.text('Listen'), findsOneWidget);
  });

  testWidgets('auto-pause message appears while waiting for a resume hit', (
    tester,
  ) async {
    final controller = _controller()
      ..setAutoPauseConfig(const PracticeAutoPauseConfig(enabled: true))
      ..play();
    controller.triggerAutoPause();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('practice-auto-pause-message')),
      findsOneWidget,
    );
    expect(find.text('Paused - tap any pad to resume'), findsOneWidget);
  });

  testWidgets('practice screen can show tap pads as an input surface', (
    tester,
  ) async {
    final controller = _controller();
    final hits = <TapPadHit>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
            tapPadInput: PracticeTapPadInput(
              enabledLaneIds: const {'kick', 'snare'},
              onPadHit: hits.add,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('tap-pad-kick')));
    await tester.pump();

    expect(hits.single.laneId, 'kick');
    expect(find.byKey(const ValueKey('tap-pad-ride')), findsNothing);
  });

  testWidgets('practice screen warns when lesson lanes are unavailable', (
    tester,
  ) async {
    final controller = _controller();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
            layoutCompatibility: _optionalMissingCompatibility,
          ),
        ),
      ),
    );

    expect(find.text('Optional lanes missing'), findsOneWidget);
    expect(
      find.text(
        'Missing lanes on this kit: Cowbell. They stay visible but are not scored.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('layout-compatibility-banner')),
      findsOneWidget,
    );
  });

  test('pauseForMidiDisconnect pauses running session and sets flag', () {
    final controller = _controller()..play();
    expect(controller.isRunning, isTrue);

    final paused = controller.pauseForMidiDisconnect();
    expect(paused, isTrue);
    expect(controller.isPaused, isTrue);
    expect(controller.midiDisconnected, isTrue);
  });

  test('pauseForMidiDisconnect sets flag even when not running', () {
    final controller = _controller();
    expect(controller.transportState, PracticeTransportState.stopped);

    final paused = controller.pauseForMidiDisconnect();
    expect(paused, isFalse);
    expect(controller.midiDisconnected, isTrue);
  });

  test('resumeFromMidiReconnect resumes paused session and clears flag', () {
    final controller = _controller()..play();
    controller.pauseForMidiDisconnect();
    expect(controller.isPaused, isTrue);
    expect(controller.midiDisconnected, isTrue);

    controller.resumeFromMidiReconnect();
    expect(controller.isRunning, isTrue);
    expect(controller.midiDisconnected, isFalse);
  });

  test(
    'resumeFromMidiReconnect clears flag without starting stopped session',
    () {
      final controller = _controller();
      controller.pauseForMidiDisconnect();

      controller.resumeFromMidiReconnect();
      expect(controller.midiDisconnected, isFalse);
      expect(controller.transportState, PracticeTransportState.stopped);
    },
  );

  test('count-in delays running state by configured bars', () {
    final controller = PracticeModeController(
      baseBpm: 120,
      totalDurationMs: 8000,
      countInBars: 2,
    );

    controller.play();
    expect(controller.transportState, PracticeTransportState.countIn);
    expect(controller.isCountingIn, isTrue);
    expect(controller.countInRemainingBeats, greaterThan(0));

    // At 120 BPM, 2 bars = 8 beats = 4000ms. Advance 3000ms.
    controller.advanceBy(const Duration(milliseconds: 3000));
    expect(controller.transportState, PracticeTransportState.countIn);

    // Advance past the remaining 1000ms.
    controller.advanceBy(const Duration(milliseconds: 1100));
    expect(controller.transportState, PracticeTransportState.running);
    expect(controller.isCountingIn, isFalse);
  });

  test('count-in of zero bars starts running immediately', () {
    final controller = PracticeModeController(
      baseBpm: 120,
      totalDurationMs: 8000,
      countInBars: 0,
    );

    controller.play();
    expect(controller.transportState, PracticeTransportState.running);
  });

  test('setCountInBars rejects values outside 0-4', () {
    final controller = _controller();
    expect(() => controller.setCountInBars(-1), throwsArgumentError);
    expect(() => controller.setCountInBars(5), throwsArgumentError);
  });

  test('togglePlayPause cancels count-in', () {
    final controller = PracticeModeController(
      baseBpm: 120,
      totalDurationMs: 8000,
      countInBars: 1,
    );

    controller.play();
    expect(controller.isCountingIn, isTrue);

    controller.togglePlayPause();
    expect(controller.transportState, PracticeTransportState.stopped);
    expect(controller.countInRemainingMs, 0);
  });

  test('stop clears count-in state', () {
    final controller = PracticeModeController(
      baseBpm: 120,
      totalDurationMs: 8000,
      countInBars: 1,
    );

    controller.play();
    expect(controller.isCountingIn, isTrue);

    controller.stop();
    expect(controller.transportState, PracticeTransportState.stopped);
    expect(controller.countInRemainingMs, 0);
  });

  testWidgets('stop button appears during playback and stops transport', (
    tester,
  ) async {
    final controller = _controller()..play();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('practice-stop-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('practice-stop-button')));
    await tester.pump();

    expect(controller.transportState, PracticeTransportState.stopped);
  });

  test('setRuntimeFeedback accepts lastGrade and updates controller', () {
    final controller = _controller();

    controller.setRuntimeFeedback(
      combo: 5,
      lastGrade: NoteHighwayGrade.perfect,
    );

    expect(controller.combo, 5);
    expect(controller.lastGrade, NoteHighwayGrade.perfect);
  });

  test('setRuntimeFeedback preserves lastGrade when not supplied', () {
    final controller = _controller();

    controller.setRuntimeFeedback(combo: 3, lastGrade: NoteHighwayGrade.good);
    controller.setRuntimeFeedback(combo: 4);

    expect(controller.lastGrade, NoteHighwayGrade.good);
    expect(controller.combo, 4);
  });

  testWidgets('animated combo counter renders and updates on combo change', (
    tester,
  ) async {
    final controller = _controller();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
          ),
        ),
      ),
    );

    expect(find.text('Combo 0'), findsOneWidget);

    controller.setRuntimeFeedback(combo: 8);
    await tester.pump();

    expect(find.text('Combo 8'), findsOneWidget);

    // Let animation complete.
    await tester.pumpAndSettle();

    expect(find.text('Combo 8'), findsOneWidget);
  });

  testWidgets('encouragement text slides in when set', (tester) async {
    final controller = _controller();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
          ),
        ),
      ),
    );

    expect(find.text('Great streak!'), findsNothing);

    controller.setRuntimeFeedback(encouragementText: 'Great streak!');
    await tester.pump();

    expect(find.text('Great streak!'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Great streak!'), findsOneWidget);
  });

  testWidgets('grade flash overlay is present in the widget tree', (
    tester,
  ) async {
    final controller = _controller();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('practice-grade-flash')), findsOneWidget);

    controller.setRuntimeFeedback(lastGrade: NoteHighwayGrade.perfect);
    await tester.pump();
    await tester.pumpAndSettle();

    // Flash overlay still in the tree (animation completed).
    expect(find.byKey(const ValueKey('practice-grade-flash')), findsOneWidget);
  });

  testWidgets('combo reset to zero triggers shake animation', (tester) async {
    final controller = _controller();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PracticeModeScreen(
            controller: controller,
            lanes: _lanes,
            notes: _notes,
          ),
        ),
      ),
    );

    controller.setRuntimeFeedback(combo: 10);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Combo 10'), findsOneWidget);

    controller.setRuntimeFeedback(combo: 0, lastGrade: NoteHighwayGrade.miss);
    await tester.pump();

    expect(find.text('Combo 0'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Combo 0'), findsOneWidget);
  });
}

PracticeModeController _controller() {
  return PracticeModeController(
    baseBpm: 120,
    totalDurationMs: 8000,
    sections: const [
      PracticeSection(
        sectionId: 'main',
        label: 'Main Groove',
        startMs: 2000,
        endMs: 4000,
      ),
    ],
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

const _optionalMissingCompatibility = LayoutCompatibilitySnapshot(
  status: LayoutCompatibilityStatus.optionalMissing,
  lessonLanes: ['kick', 'snare', 'cowbell'],
  requiredLanes: ['kick', 'snare'],
  optionalLanes: ['cowbell'],
  mappedLanes: ['kick', 'snare'],
  missingRequiredLanes: [],
  missingOptionalLanes: ['cowbell'],
  excludedLanes: ['cowbell'],
);

class _FakeMetronomeAudioOutput implements MetronomeAudioOutput {
  int? sessionStartTimeNs;
  List<ScheduledDrumHit> scheduledDrumHits = const [];
  int stopCount = 0;

  @override
  Future<void> configure(MetronomeAudioSettings settings) async {}

  @override
  Future<void> scheduleClicks({
    required int sessionStartTimeNs,
    required List<ScheduledMetronomeClick> clicks,
  }) async {}

  @override
  Future<void> scheduleDrumHits({
    required int sessionStartTimeNs,
    required List<ScheduledDrumHit> hits,
  }) async {
    this.sessionStartTimeNs = sessionStartTimeNs;
    scheduledDrumHits = hits;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}
