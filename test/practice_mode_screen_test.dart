import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/player/drum_kit/drum_kit.dart';
import 'package:taal/features/player/notation/notation_view.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';
import 'package:taal/features/player/practice_mode/practice_mode_screen.dart';
import 'package:taal/features/player/tap_pads/tap_pad_surface.dart';

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

    await tester.tap(find.text('Play'));
    await tester.pump();

    expect(controller.transportState, PracticeTransportState.running);
    expect(find.text('Pause'), findsOneWidget);

    await tester.tap(find.text('Pause'));
    await tester.pump();

    expect(controller.transportState, PracticeTransportState.paused);
    expect(find.text('Play'), findsOneWidget);
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
