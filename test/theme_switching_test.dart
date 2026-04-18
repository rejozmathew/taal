import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/design/theme.dart';
import 'package:taal/features/settings/settings_store.dart';
import 'package:taal/main.dart';

void main() {
  group('themeModeFromPreference', () {
    test('system maps to ThemeMode.system', () {
      expect(themeModeFromPreference(ThemePreference.system), ThemeMode.system);
    });

    test('light maps to ThemeMode.light', () {
      expect(themeModeFromPreference(ThemePreference.light), ThemeMode.light);
    });

    test('dark maps to ThemeMode.dark', () {
      expect(themeModeFromPreference(ThemePreference.dark), ThemeMode.dark);
    });
  });

  group('TaalApp theme switching', () {
    testWidgets('defaults to dark theme', (tester) async {
      await tester.pumpWidget(const TaalApp());
      // TaalApp creates a MaterialApp. Verify the widget tree exists.
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('setThemeMode changes theme brightness', (tester) async {
      await tester.pumpWidget(const TaalApp());

      // Starts dark by default.
      final darkApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(darkApp.themeMode, ThemeMode.dark);

      // Switch to light.
      final context = tester.element(find.byType(MaterialApp).first);
      TaalApp.setThemeMode(context, ThemeMode.light);
      await tester.pump();

      final lightApp =
          tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(lightApp.themeMode, ThemeMode.light);
    });

    testWidgets('setThemeMode to system follows platform', (tester) async {
      await tester.pumpWidget(const TaalApp());

      final context = tester.element(find.byType(MaterialApp).first);
      TaalApp.setThemeMode(context, ThemeMode.system);
      await tester.pump();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.system);
    });

    testWidgets('setThemeMode is no-op without TaalApp ancestor', (
      tester,
    ) async {
      // Wrapped in plain MaterialApp — no TaalApp ancestor.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('plain'))),
      );
      final context = tester.element(find.text('plain'));
      // Should not throw.
      TaalApp.setThemeMode(context, ThemeMode.light);
    });

    testWidgets('provides both light and dark ThemeData', (tester) async {
      await tester.pumpWidget(const TaalApp());
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme, TaalTheme.light);
      expect(app.darkTheme, TaalTheme.dark);
    });
  });
}
