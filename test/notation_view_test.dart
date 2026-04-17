import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/player/notation/notation_view.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';

void main() {
  test('snare sits on the third staff line and kick sits below the staff', () {
    const geometry = NotationGeometry(size: Size(720, 360));
    final snare = geometry.yForPlacement(defaultDrumPlacements['snare']!);
    final kick = geometry.yForPlacement(defaultDrumPlacements['kick']!);

    expect(snare, geometry.staffLineY(2));
    expect(kick, geometry.staffBottomY + geometry.staffLineGap / 2);
  });

  test('default placements cover the standard 5-piece layout lane ids', () {
    expect(defaultDrumPlacements, contains('kick'));
    expect(defaultDrumPlacements, contains('snare'));
    expect(defaultDrumPlacements, contains('hihat'));
    expect(defaultDrumPlacements, contains('ride'));
    expect(defaultDrumPlacements, contains('crash'));
    expect(defaultDrumPlacements, contains('tom_high'));
    expect(defaultDrumPlacements, contains('tom_low'));
    expect(defaultDrumPlacements, contains('tom_floor'));
  });

  test('notation timeline places current note at the playhead', () {
    const geometry = NotationGeometry(size: Size(720, 360));

    final current = geometry.xForTime(
      eventTimeMs: 1000,
      currentTimeMs: 1000,
      pixelsPerSecond: 180,
    );
    final future = geometry.xForTime(
      eventTimeMs: 2000,
      currentTimeMs: 1000,
      pixelsPerSecond: 180,
    );

    expect(current, geometry.playheadX);
    expect(future, greaterThan(geometry.playheadX));
  });

  test('page mode maps time across the staff instead of anchoring to now', () {
    const geometry = NotationGeometry(size: Size(720, 360));

    final pageStart = geometry.xForTime(
      eventTimeMs: 4000,
      currentTimeMs: 6000,
      pixelsPerSecond: 180,
      displayMode: NotationDisplayMode.page,
      pageStartMs: 4000,
      pageDurationMs: 8000,
    );
    final pageMiddle = geometry.xForTime(
      eventTimeMs: 8000,
      currentTimeMs: 6000,
      pixelsPerSecond: 180,
      displayMode: NotationDisplayMode.page,
      pageStartMs: 4000,
      pageDurationMs: 8000,
    );

    expect(pageStart, geometry.contentLeft);
    expect(pageMiddle, geometry.contentLeft + geometry.contentWidth / 2);
  });

  test('notation feedback uses the same early and late marker direction', () {
    const geometry = NotationGeometry(size: Size(720, 360));
    final snare = defaultDrumPlacements['snare']!;
    final onBeat = geometry.xForTime(
      eventTimeMs: 1000,
      currentTimeMs: 1000,
      pixelsPerSecond: 180,
    );

    final early = geometry.feedbackCenter(
      placement: snare,
      eventTimeMs: 1000,
      currentTimeMs: 1000,
      pixelsPerSecond: 180,
      deltaMs: -60,
      displayMode: NotationDisplayMode.scrolling,
      pageStartMs: 0,
      pageDurationMs: 8000,
    );
    final late = geometry.feedbackCenter(
      placement: snare,
      eventTimeMs: 1000,
      currentTimeMs: 1000,
      pixelsPerSecond: 180,
      deltaMs: 60,
      displayMode: NotationDisplayMode.scrolling,
      pageStartMs: 0,
      pageDurationMs: 8000,
    );

    expect(early.dx, lessThan(onBeat));
    expect(late.dx, greaterThan(onBeat));
  });

  testWidgets('notation view renders a custom paint surface with feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 720,
          height: 360,
          child: NotationViewWidget(
            currentTimeMs: 500,
            notes: const [
              NotationNote(expectedId: 'kick-1', laneId: 'kick', tMs: 500),
              NotationNote(expectedId: 'snare-1', laneId: 'snare', tMs: 1000),
            ],
            feedback: const [
              NotationFeedback(
                expectedId: 'kick-1',
                laneId: 'kick',
                tMs: 500,
                grade: NoteHighwayGrade.perfect,
                deltaMs: 0,
              ),
            ],
          ),
        ),
      ),
    );

    final notationPaint = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is NotationViewPainter,
    );
    expect(notationPaint, findsOneWidget);
  });

  testWidgets(
    'notation view can switch to page display without session state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 720,
            height: 360,
            child: NotationViewWidget(
              currentTimeMs: 1000,
              displayMode: NotationDisplayMode.page,
              pageStartMs: 0,
              pageDurationMs: 4000,
              notes: const [
                NotationNote(
                  expectedId: 'hat-1',
                  laneId: 'hihat',
                  tMs: 1000,
                  articulation: 'open',
                ),
                NotationNote(
                  expectedId: 'tom-1',
                  laneId: 'tom_high',
                  tMs: 2000,
                ),
              ],
              feedback: const [
                NotationFeedback(
                  expectedId: 'hat-1',
                  laneId: 'hihat',
                  tMs: 1000,
                  deltaMs: -20,
                  grade: NoteHighwayGrade.early,
                ),
              ],
            ),
          ),
        ),
      );

      final notationPaint = find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint && widget.painter is NotationViewPainter,
      );
      final customPaint = tester.widget<CustomPaint>(notationPaint);
      final painter = customPaint.painter! as NotationViewPainter;

      expect(painter.displayMode, NotationDisplayMode.page);
      expect(painter.notes.map((note) => note.laneId), contains('hihat'));
      expect(painter.notes.map((note) => note.laneId), contains('tom_high'));
    },
  );
}
