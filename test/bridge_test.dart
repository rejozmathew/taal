import 'package:flutter_test/flutter_test.dart';
import 'package:taal/src/rust/api/simple.dart';
import 'package:taal/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dart calls Rust greet through flutter_rust_bridge', () async {
    await RustLib.init();

    expect(greet(name: 'Taal'), 'Hello, Taal!');
  });
}
