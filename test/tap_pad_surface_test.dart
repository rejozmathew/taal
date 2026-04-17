import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
