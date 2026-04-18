import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/design/motion.dart';
import 'package:taal/design/theme.dart';

void main() {
  group('TaalMotion constants', () {
    test('durations are positive and ordered', () {
      expect(
        TaalMotion.durationFast.inMilliseconds,
        lessThan(TaalMotion.durationMedium.inMilliseconds),
      );
      expect(
        TaalMotion.durationMedium.inMilliseconds,
        lessThan(TaalMotion.durationSlow.inMilliseconds),
      );
    });

    test('pressScale is between 0 and 1', () {
      expect(TaalMotion.pressScale, greaterThan(0.0));
      expect(TaalMotion.pressScale, lessThan(1.0));
    });

    test('hoverElevationBoost is positive', () {
      expect(TaalMotion.hoverElevationBoost, greaterThan(0.0));
    });

    test('staggerInterval is positive', () {
      expect(TaalMotion.staggerInterval.inMilliseconds, greaterThan(0));
    });
  });

  group('SectionTransition', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SectionTransition(child: Text('Hello'))),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('cross-fades when child key changes', (tester) async {
      Widget buildApp(String text) {
        return MaterialApp(
          home: Scaffold(
            body: SectionTransition(
              child: KeyedSubtree(key: ValueKey(text), child: Text(text)),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp('Page A'));
      expect(find.text('Page A'), findsOneWidget);

      await tester.pumpWidget(buildApp('Page B'));
      // During animation both may be present.
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Page B'), findsOneWidget);

      // After full duration only new child remains.
      await tester.pumpAndSettle();
      expect(find.text('Page A'), findsNothing);
      expect(find.text('Page B'), findsOneWidget);
    });
  });

  group('PressableScale', () {
    testWidgets('renders child and fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableScale(
              onTap: () => tapped = true,
              child: const Text('Press me'),
            ),
          ),
        ),
      );
      expect(find.text('Press me'), findsOneWidget);
      await tester.tap(find.text('Press me'));
      expect(tapped, isTrue);
    });

    testWidgets('scales on press', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressableScale(
                child: SizedBox(width: 100, height: 50, child: Text('btn')),
              ),
            ),
          ),
        ),
      );

      final scaleFinder = find.descendant(
        of: find.byType(PressableScale),
        matching: find.byType(ScaleTransition),
      );

      // Before press, scale is 1.0.
      final before = tester.widget<ScaleTransition>(scaleFinder.first);
      expect(before.scale.value, closeTo(1.0, 0.001));

      // Press and hold — advance past the animation duration.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('btn')),
      );
      await tester.pump();
      await tester.pump(
        TaalMotion.durationFast + const Duration(milliseconds: 50),
      );

      // The ScaleTransition should have reached pressScale.
      final during = tester.widget<ScaleTransition>(scaleFinder.first);
      expect(
        during.scale.value,
        lessThanOrEqualTo(TaalMotion.pressScale + 0.01),
      );

      await gesture.up();
      await tester.pumpAndSettle();

      // After release, scale should return to 1.0.
      final after = tester.widget<ScaleTransition>(scaleFinder.first);
      expect(after.scale.value, closeTo(1.0, 0.001));
    });
  });

  group('InteractiveCard', () {
    testWidgets('renders child', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveCard(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Card content'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Card content'), findsOneWidget);
    });

    testWidgets('fires onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InteractiveCard(
              onTap: () => tapped = true,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Tap me'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tap me'));
      expect(tapped, isTrue);
    });

    testWidgets('contains Material with elevation', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveCard(
              elevation: 2.0,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Elevated'),
              ),
            ),
          ),
        ),
      );
      final material = tester.widget<Material>(find.byType(Material).last);
      expect(material.elevation, 2.0);
    });
  });

  group('StaggeredFadeIn', () {
    testWidgets('renders child after delay', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StaggeredFadeIn(index: 0, child: Text('Item 0')),
                StaggeredFadeIn(index: 1, child: Text('Item 1')),
                StaggeredFadeIn(index: 2, child: Text('Item 2')),
              ],
            ),
          ),
        ),
      );

      // Items exist in tree immediately (opacity starts at 0).
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);

      // After settling, all are fully visible.
      await tester.pumpAndSettle();
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });
  });

  group('TaalTheme page transitions', () {
    test('dark theme has custom page transitions for Windows', () {
      final builders = TaalTheme.dark.pageTransitionsTheme.builders;
      expect(builders[TargetPlatform.windows], isNotNull);
    });

    test('light theme has custom page transitions for Windows', () {
      final builders = TaalTheme.light.pageTransitionsTheme.builders;
      expect(builders[TargetPlatform.windows], isNotNull);
    });

    test('button themes use fast animation duration', () {
      final darkFilled = TaalTheme.dark.filledButtonTheme.style;
      expect(darkFilled?.animationDuration, TaalMotion.durationFast);
    });
  });
}
