import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/player/drum_kit/drum_kit.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';

void main() {
  test('standard kit pads cover the standard 5-piece layout slots', () {
    final laneIds = standardFivePieceDrumKitPads.map((pad) => pad.laneId);
    final slotIds = standardFivePieceDrumKitPads.map((pad) => pad.slotId);

    expect(
      laneIds,
      containsAll(<String>[
        'kick',
        'snare',
        'hihat',
        'ride',
        'crash',
        'tom_high',
        'tom_low',
        'tom_floor',
      ]),
    );
    expect(slotIds.toSet(), hasLength(standardFivePieceDrumKitPads.length));
  });

  test('drum kit geometry keeps pads inside the kit bounds', () {
    const geometry = VisualDrumKitGeometry(size: Size(640, 420));

    for (final pad in standardFivePieceDrumKitPads) {
      final rect = geometry.padRect(pad);
      expect(geometry.kitBounds.contains(rect.center), isTrue);
      expect(rect.width, greaterThan(0));
      expect(rect.height, greaterThan(0));
    }
  });

  test('mapped hits light the matching pad and unknown lanes stay unlit', () {
    final painter = VisualDrumKitPainter(
      pads: standardFivePieceDrumKitPads,
      hits: const [
        VisualDrumKitHit(laneId: 'snare', grade: NoteHighwayGrade.perfect),
        VisualDrumKitHit(laneId: 'cowbell', grade: NoteHighwayGrade.late),
      ],
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    );

    expect(painter.activeHitForLane('snare')?.grade, NoteHighwayGrade.perfect);
    expect(painter.activeHitForLane('cowbell'), isNull);
  });

  test('custom pad lists allow extended layouts', () {
    const customPads = [
      ...standardFivePieceDrumKitPads,
      VisualDrumKitPad(
        laneId: 'splash',
        slotId: 'splash',
        label: 'Splash',
        center: Offset(0.88, 0.18),
        size: Size(0.18, 0.08),
        kind: VisualDrumKitPadKind.cymbal,
      ),
    ];
    const geometry = VisualDrumKitGeometry(size: Size(640, 420));

    final splash = geometry.padForLane('splash', customPads);

    expect(splash, isNotNull);
    expect(splash!.slotId, 'splash');
    expect(
      geometry.kitBounds.contains(geometry.padRect(splash).center),
      isTrue,
    );
  });

  testWidgets('visual drum kit renders an immediate custom paint hit state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 640,
          height: 420,
          child: VisualDrumKitWidget(
            hits: const [
              VisualDrumKitHit(
                laneId: 'kick',
                grade: NoteHighwayGrade.good,
                progress: 0,
              ),
            ],
          ),
        ),
      ),
    );

    final kitPaint = find.byWidgetPredicate(
      (widget) =>
          widget is CustomPaint && widget.painter is VisualDrumKitPainter,
    );
    expect(kitPaint, findsOneWidget);

    final customPaint = tester.widget<CustomPaint>(kitPaint);
    final painter = customPaint.painter! as VisualDrumKitPainter;
    expect(painter.activeHitForLane('kick')?.grade, NoteHighwayGrade.good);
    expect(painter.activeHitForLane('ride'), isNull);
  });
}
