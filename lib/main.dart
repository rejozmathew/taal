import 'package:flutter/material.dart';
import 'package:taal/features/app_shell/app_shell.dart';
import 'package:taal/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const TaalApp());
}

class TaalApp extends StatelessWidget {
  const TaalApp({super.key});

  @override
  Widget build(BuildContext context) {
    const radius = 8.0;

    return MaterialApp(
      title: 'Taal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF0E7C7B),
              brightness: Brightness.dark,
            ).copyWith(
              primary: const Color(0xFF16A085),
              secondary: const Color(0xFFE0B44C),
              tertiary: const Color(0xFF5DADE2),
            ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
        chipTheme: const ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radius)),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(radius)),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
        ),
      ),
      home: const TaalAppShell(),
    );
  }
}
