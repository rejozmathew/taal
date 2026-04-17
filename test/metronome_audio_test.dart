import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/platform/audio/metronome_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('taal/metronome_audio');

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('configure serializes volume and preset', () async {
    final output = PlatformMetronomeAudioOutput(channel: channel);

    await output.configure(
      const MetronomeAudioSettings(
        volume: 0.35,
        preset: ClickSoundPreset.woodblock,
      ),
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'configure');
    expect(calls.single.arguments, {'volume': 0.35, 'preset': 'woodblock'});
  });

  test('scheduleClicks serializes session origin and click list', () async {
    final output = PlatformMetronomeAudioOutput(channel: channel);

    await output.scheduleClicks(
      sessionStartTimeNs: 123456789,
      clicks: const [
        ScheduledMetronomeClick(tMs: 0, accent: true),
        ScheduledMetronomeClick(tMs: 500, accent: false),
      ],
    );

    expect(calls, hasLength(1));
    expect(calls.single.method, 'scheduleClicks');
    expect(calls.single.arguments, {
      'session_start_time_ns': 123456789,
      'clicks': [
        {'t_ms': 0, 'accent': true},
        {'t_ms': 500, 'accent': false},
      ],
    });
  });

  test('configure rejects volume outside 0 to 1', () async {
    final output = PlatformMetronomeAudioOutput(channel: channel);

    expect(
      () => output.configure(
        const MetronomeAudioSettings(
          volume: 1.25,
          preset: ClickSoundPreset.classic,
        ),
      ),
      throwsRangeError,
    );
    expect(calls, isEmpty);
  });
}
