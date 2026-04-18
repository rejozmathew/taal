import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/design/colors.dart';
import 'package:taal/design/theme.dart';
import 'package:taal/design/tokens.dart';
import 'package:taal/design/typography.dart';

void main() {
  group('TaalTheme', () {
    test('dark theme uses dark brightness', () {
      expect(TaalTheme.dark.brightness, Brightness.dark);
    });

    test('light theme uses light brightness', () {
      expect(TaalTheme.light.brightness, Brightness.light);
    });

    test('dark theme colorScheme has correct primary', () {
      expect(TaalTheme.dark.colorScheme.primary, TaalColors.primary);
    });

    test('light theme colorScheme has correct primary', () {
      expect(TaalTheme.light.colorScheme.primary, TaalColors.primary);
    });

    test('dark theme colorScheme has correct secondary', () {
      expect(TaalTheme.dark.colorScheme.secondary, TaalColors.secondary);
    });

    test('light theme colorScheme has correct secondary', () {
      expect(TaalTheme.light.colorScheme.secondary, TaalColors.secondary);
    });

    test('dark theme has dark surface colors', () {
      expect(TaalTheme.dark.colorScheme.surface, TaalColors.darkSurface);
    });

    test('light theme has light surface colors', () {
      expect(TaalTheme.light.colorScheme.surface, TaalColors.lightSurface);
    });

    test('both themes use Material 3', () {
      expect(TaalTheme.dark.useMaterial3, isTrue);
      expect(TaalTheme.light.useMaterial3, isTrue);
    });

    test('both themes apply Inter text theme', () {
      expect(
        TaalTheme.dark.textTheme.bodyLarge?.fontFamily,
        'Inter',
      );
      expect(
        TaalTheme.light.textTheme.bodyLarge?.fontFamily,
        'Inter',
      );
    });

    test('dark theme scaffold background is dark', () {
      expect(
        TaalTheme.dark.scaffoldBackgroundColor,
        TaalColors.darkBackground,
      );
    });

    test('light theme scaffold background is light', () {
      expect(
        TaalTheme.light.scaffoldBackgroundColor,
        TaalColors.lightBackground,
      );
    });

    testWidgets('dark theme renders in MaterialApp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TaalTheme.dark,
          home: const Scaffold(body: Text('dark')),
        ),
      );
      expect(find.text('dark'), findsOneWidget);
    });

    testWidgets('light theme renders in MaterialApp', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TaalTheme.light,
          home: const Scaffold(body: Text('light')),
        ),
      );
      expect(find.text('light'), findsOneWidget);
    });

    testWidgets('both themes provided with themeMode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TaalTheme.light,
          darkTheme: TaalTheme.dark,
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              final scheme = Theme.of(context).colorScheme;
              return Text('${scheme.brightness}');
            },
          ),
        ),
      );
      expect(find.text('Brightness.dark'), findsOneWidget);
    });
  });

  group('TaalColors', () {
    test('grade colors are distinct', () {
      final gradeColors = {
        TaalColors.gradePerfect,
        TaalColors.gradeGood,
        TaalColors.gradeEarly,
        TaalColors.gradeLate,
        TaalColors.gradeMiss,
      };
      expect(gradeColors.length, 5);
    });

    test('lane palette has 8 entries', () {
      expect(TaalColors.lanePalette.length, 8);
    });

    test('early and late are distinct hues (color-blind safety)', () {
      expect(TaalColors.gradeEarly, isNot(equals(TaalColors.gradeLate)));
      // Blue vs Amber — different hue families
      final earlyHue = HSLColor.fromColor(TaalColors.gradeEarly).hue;
      final lateHue = HSLColor.fromColor(TaalColors.gradeLate).hue;
      expect((earlyHue - lateHue).abs() > 30, isTrue);
    });
  });

  group('TaalTokens', () {
    test('spacing scale follows 4-base progression', () {
      expect(TaalTokens.space4, 4.0);
      expect(TaalTokens.space8, 8.0);
      expect(TaalTokens.space12, 12.0);
      expect(TaalTokens.space16, 16.0);
      expect(TaalTokens.space24, 24.0);
      expect(TaalTokens.space32, 32.0);
      expect(TaalTokens.space48, 48.0);
    });

    test('minimum touch target is 48dp', () {
      expect(TaalTokens.minTouchTarget, 48.0);
    });
  });

  group('TaalTypography', () {
    test('all text styles use Inter font family', () {
      final styles = [
        TaalTypography.displayLarge,
        TaalTypography.displayMedium,
        TaalTypography.displaySmall,
        TaalTypography.headlineLarge,
        TaalTypography.headlineMedium,
        TaalTypography.headlineSmall,
        TaalTypography.titleLarge,
        TaalTypography.titleMedium,
        TaalTypography.titleSmall,
        TaalTypography.bodyLarge,
        TaalTypography.bodyMedium,
        TaalTypography.bodySmall,
        TaalTypography.labelLarge,
        TaalTypography.labelMedium,
        TaalTypography.labelSmall,
      ];
      for (final style in styles) {
        expect(style.fontFamily, 'Inter');
      }
    });

    test('textTheme has all 15 slots populated', () {
      final theme = TaalTypography.textTheme;
      expect(theme.displayLarge, isNotNull);
      expect(theme.displayMedium, isNotNull);
      expect(theme.displaySmall, isNotNull);
      expect(theme.headlineLarge, isNotNull);
      expect(theme.headlineMedium, isNotNull);
      expect(theme.headlineSmall, isNotNull);
      expect(theme.titleLarge, isNotNull);
      expect(theme.titleMedium, isNotNull);
      expect(theme.titleSmall, isNotNull);
      expect(theme.bodyLarge, isNotNull);
      expect(theme.bodyMedium, isNotNull);
      expect(theme.bodySmall, isNotNull);
      expect(theme.labelLarge, isNotNull);
      expect(theme.labelMedium, isNotNull);
      expect(theme.labelSmall, isNotNull);
    });

    test('bold weights are w700', () {
      expect(TaalTypography.headlineLarge.fontWeight, FontWeight.w700);
      expect(TaalTypography.titleLarge.fontWeight, FontWeight.w700);
      expect(TaalTypography.labelLarge.fontWeight, FontWeight.w700);
    });

    test('body weights are w400', () {
      expect(TaalTypography.bodyLarge.fontWeight, FontWeight.w400);
      expect(TaalTypography.bodyMedium.fontWeight, FontWeight.w400);
      expect(TaalTypography.bodySmall.fontWeight, FontWeight.w400);
    });
  });
}
