import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/player/drum_kit/drum_kit.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';
import 'package:taal/features/player/tap_pads/tap_pad_surface.dart';

void main() {
  testWidgets('tap pad surface emits semantic lane hits', (tester) async {
    final hits = <TapPadHit>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: TapPadSurface(onPadHit: hits.add),
          ),
        ),
      ),
    );

    expect(find.text('Connect your kit for the best experience.'), findsOne);

    final snare = find.byKey(const ValueKey('tap-pad-snare'));
    expect(snare, findsOneWidget);
    expect(tester.getSize(snare).width, greaterThanOrEqualTo(48));
    expect(tester.getSize(snare).height, greaterThanOrEqualTo(48));

    await tester.tap(snare);
    await tester.pump();

    expect(hits, hasLength(1));
    expect(hits.single.laneId, 'snare');
    expect(hits.single.velocity, 96);
  });

  testWidgets('tap pad surface can limit pads to lesson lanes', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: TapPadSurface(
              enabledLaneIds: const {'kick', 'snare'},
              onPadHit: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('tap-pad-kick')), findsOneWidget);
    expect(find.byKey(const ValueKey('tap-pad-snare')), findsOneWidget);
    expect(find.byKey(const ValueKey('tap-pad-ride')), findsNothing);
  });

  testWidgets('guidance banner is dismissible when callback provided', (
    tester,
  ) async {
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: TapPadSurface(
              onPadHit: (_) {},
              onDismissGuidance: () => dismissed = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Connect your kit for the best experience.'), findsOne);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(dismissed, isTrue);
    expect(
      find.text('Connect your kit for the best experience.'),
      findsNothing,
    );
  });

  testWidgets('guidance banner has no dismiss button without callback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: TapPadSurface(onPadHit: (_) {}),
          ),
        ),
      ),
    );

    expect(find.text('Connect your kit for the best experience.'), findsOne);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('kick pad uses circular shape', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: TapPadSurface(
              enabledLaneIds: const {'kick'},
              onPadHit: (_) {},
            ),
          ),
        ),
      ),
    );

    final kickPad = find.byKey(const ValueKey('tap-pad-kick'));
    expect(kickPad, findsOneWidget);

    // The kick pad should exist and be tappable.
    final material = tester.widget<Material>(
      find.descendant(of: kickPad, matching: find.byType(Material)),
    );
    expect(material.shape, isA<CircleBorder>());
  });

  testWidgets('cymbal pad uses stadium shape', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: TapPadSurface(
              enabledLaneIds: const {'crash'},
              onPadHit: (_) {},
            ),
          ),
        ),
      ),
    );

    final crashPad = find.byKey(const ValueKey('tap-pad-crash'));
    expect(crashPad, findsOneWidget);

    final material = tester.widget<Material>(
      find.descendant(of: crashPad, matching: find.byType(Material)),
    );
    expect(material.shape, isA<StadiumBorder>());
  });

  testWidgets('drum pad uses rounded rectangle shape', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: TapPadSurface(
              enabledLaneIds: const {'snare'},
              onPadHit: (_) {},
            ),
          ),
        ),
      ),
    );

    final snarePad = find.byKey(const ValueKey('tap-pad-snare'));
    expect(snarePad, findsOneWidget);

    final material = tester.widget<Material>(
      find.descendant(of: snarePad, matching: find.byType(Material)),
    );
    expect(material.shape, isA<RoundedRectangleBorder>());
  });

  testWidgets('tap pad accepts recentHits for grade feedback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: TapPadSurface(
              onPadHit: (_) {},
              recentHits: const [
                VisualDrumKitHit(
                  laneId: 'snare',
                  grade: NoteHighwayGrade.perfect,
                  progress: 0.3,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Pad should render without errors when grade hits are provided.
    expect(find.byKey(const ValueKey('tap-pad-snare')), findsOneWidget);
  });

  testWidgets('all standard pads are accessible with semantic labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 640,
            height: 360,
            child: TapPadSurface(onPadHit: (_) {}),
          ),
        ),
      ),
    );

    // Verify all standard pads render and have their label text visible.
    for (final pad in standardFivePieceDrumKitPads) {
      expect(
        find.byKey(ValueKey('tap-pad-${pad.laneId}')),
        findsOneWidget,
        reason: '${pad.label} pad should be present',
      );
      expect(
        find.text(pad.label),
        findsWidgets,
        reason: '${pad.label} label text should be visible',
      );
    }
  });
}
