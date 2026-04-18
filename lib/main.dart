import 'package:flutter/material.dart';
import 'package:taal/design/theme.dart';
import 'package:taal/features/app_shell/app_shell.dart';
import 'package:taal/features/settings/settings_store.dart';
import 'package:taal/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const TaalApp());
}

class TaalApp extends StatefulWidget {
  const TaalApp({super.key});

  /// Update the app-level [ThemeMode] from anywhere in the widget tree.
  /// No-op if called from a context without a [TaalApp] ancestor (e.g. tests).
  static void setThemeMode(BuildContext context, ThemeMode mode) {
    context.findAncestorStateOfType<_TaalAppState>()?._setThemeMode(mode);
  }

  @override
  State<TaalApp> createState() => _TaalAppState();
}

class _TaalAppState extends State<TaalApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      setState(() => _themeMode = mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taal',
      debugShowCheckedModeBanner: false,
      theme: TaalTheme.light,
      darkTheme: TaalTheme.dark,
      themeMode: _themeMode,
      home: const TaalAppShell(),
    );
  }
}

/// Convert a persisted [ThemePreference] to Flutter's [ThemeMode].
ThemeMode themeModeFromPreference(ThemePreference pref) {
  switch (pref) {
    case ThemePreference.system:
      return ThemeMode.system;
    case ThemePreference.light:
      return ThemeMode.light;
    case ThemePreference.dark:
      return ThemeMode.dark;
  }
}
