import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';

void main() {
  test('note geometry moves future notes toward the hit line', () {
    const geometry = NoteHighwayGeometry(size: Size(400, 500), laneCount: 4);
    final future = geometry.noteCenter(
      laneIndex: 1,
      eventTimeMs: 1000,
      currentTimeMs: 0,
      pixelsPerSecond: 250,
    );
    final onBeat = geometry.noteCenter(
      laneIndex: 1,
      eventTimeMs: 1000,
      currentTimeMs: 1000,
      pixelsPerSecond: 250,
    );

    expect(future.dy, lessThan(geometry.hitLineY));
    expect(onBeat.dy, geometry.hitLineY);
  });

  test('feedback geometry places early left and late right', () {
    const geometry = NoteHighwayGeometry(size: Size(400, 500), laneCount: 4);
    final laneCenter = geometry.laneRect(2).center.dx;

    final early = geometry.feedbackCenter(laneIndex: 2, deltaMs: -60);
    final perfect = geometry.feedbackCenter(laneIndex: 2, deltaMs: 0);
    final late = geometry.feedbackCenter(laneIndex: 2, deltaMs: 60);

    expect(early.dx, lessThan(laneCenter));
    expect(perfect.dx, laneCenter);
    expect(late.dx, greaterThan(laneCenter));
  });

  test('grade colors use distinct timing hues', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);

    expect(
      gradeColor(NoteHighwayGrade.perfect, scheme),
      isNot(gradeColor(NoteHighwayGrade.early, scheme)),
    );
    expect(
      gradeColor(NoteHighwayGrade.early, scheme),
      isNot(gradeColor(NoteHighwayGrade.late, scheme)),
    );
    expect(
      gradeColor(NoteHighwayGrade.miss, scheme),
      isNot(gradeColor(NoteHighwayGrade.perfect, scheme)),
    );
  });

  testWidgets('note highway renders as a stable custom paint surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 640,
          height: 420,
          child: NoteHighwayWidget(
            currentTimeMs: 500,
            lanes: const [
              NoteHighwayLane(
                laneId: 'kick',
                label: 'Kick',
                color: Color(0xFF16A085),
              ),
              NoteHighwayLane(
                laneId: 'snare',
                label: 'Snare',
                color: Color(0xFFE0B44C),
              ),
            ],
            notes: const [
              NoteHighwayNote(expectedId: 'kick-1', laneId: 'kick', tMs: 500),
              NoteHighwayNote(expectedId: 'snare-1', laneId: 'snare', tMs: 900),
            ],
            feedback: const [
              NoteHighwayFeedback(
                expectedId: 'kick-1',
                laneId: 'kick',
                tMs: 500,
                deltaMs: 0,
                grade: NoteHighwayGrade.perfect,
              ),
            ],
          ),
        ),
      ),
    );

    final highwayPaint = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is NoteHighwayPainter,
    );
    expect(highwayPaint, findsOneWidget);
    final customPaint = tester.widget<CustomPaint>(highwayPaint);
    expect(customPaint.painter, isA<NoteHighwayPainter>());
  });
}
