import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taal/src/rust/api/practice_attempts.dart';
import 'package:taal/src/rust/api/practice_habits.dart';
import 'package:taal/src/rust/api/profiles.dart';
import 'package:taal/src/rust/api/settings.dart';
import 'package:taal/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dart loads the derived practice habit snapshot through Rust', () async {
    await RustLib.init();

    final tempDir = await Directory.systemTemp.createTemp(
      'taal_practice_habit_bridge_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
    final databasePath = [
      tempDir.path,
      'practice_habits.sqlite',
    ].join(Platform.pathSeparator);

    final player = createLocalProfile(
      databasePath: databasePath,
      name: 'Rejo',
      avatar: null,
      experienceLevel: ProfileExperienceLevelDto.beginner,
    ).state!.activeProfileId!;
    final otherPlayer = createLocalProfile(
      databasePath: databasePath,
      name: 'Anya',
      avatar: null,
      experienceLevel: ProfileExperienceLevelDto.beginner,
    ).state!.activeProfileId!;

    final settings = updateProfileSettings(
      databasePath: databasePath,
      playerId: player,
      settingsUpdateJson: jsonEncode({
        'preferred_view': 'note_highway',
        'theme': 'system',
        'reduce_motion': false,
        'high_contrast': false,
        'metronome_volume': 0.8,
        'metronome_click_sound': 'classic',
        'auto_pause_enabled': false,
        'auto_pause_timeout_ms': 3000,
        'record_practice_mode_attempts': true,
        'daily_goal_minutes': 15,
        'play_kit_hit_sounds': false,
        'active_device_profile_id': null,
      }),
    );
    expect(settings.error, isNull);

    _record(
      databasePath: databasePath,
      playerId: player,
      startedAtUtc: '2026-04-17T23:30:00Z',
      localDayKey: '2026-04-16',
      durationMs: 300000,
      sectionId: null,
    );
    _record(
      databasePath: databasePath,
      playerId: player,
      startedAtUtc: '2026-04-18T00:30:00Z',
      localDayKey: '2026-04-17',
      durationMs: 300000,
      sectionId: 'main',
    );
    _record(
      databasePath: databasePath,
      playerId: otherPlayer,
      startedAtUtc: '2026-04-18T10:00:00Z',
      localDayKey: '2026-04-18',
      durationMs: 1200000,
      sectionId: null,
    );

    final result = loadPracticeHabitSnapshot(
      databasePath: databasePath,
      playerId: player,
      todayLocalDayKey: '2026-04-18',
    );
    expect(result.error, isNull);
    final snapshot = jsonDecode(result.snapshotJson!) as Map<String, Object?>;

    expect(snapshot['daily_goal_minutes'], 15);
    expect(snapshot['today_minutes_completed'], 0);
    expect(snapshot['current_streak_days'], 2);
    expect(snapshot['streak_state'], 'at_risk');
    expect((snapshot['week'] as Map<String, Object?>)['days_practiced'], 2);
    expect(
      (snapshot['week'] as Map<String, Object?>)['total_minutes_completed'],
      10,
    );
    expect(
      (snapshot['week'] as Map<String, Object?>)['full_lesson_completions'],
      1,
    );
  });
}

void _record({
  required String databasePath,
  required String playerId,
  required String startedAtUtc,
  required String localDayKey,
  required int durationMs,
  required String? sectionId,
}) {
  final result = recordPracticeAttempt(
    databasePath: databasePath,
    summaryJson: jsonEncode(_summary(durationMs)),
    contextJson: jsonEncode(
      _context(
        playerId: playerId,
        startedAtUtc: startedAtUtc,
        localDayKey: localDayKey,
        sectionId: sectionId,
      ),
    ),
  );
  expect(result.error, isNull);
}

const _lessonId = '550e8400-e29b-41d4-a716-446655440501';

Map<String, Object?> _summary(int durationMs) {
  return {
    'lesson_id': _lessonId,
    'mode': 'play',
    'bpm': 120.0,
    'duration_ms': durationMs,
    'score_total': 90.0,
    'accuracy_pct': 90.0,
    'hit_rate_pct': 90.0,
    'perfect_pct': 60.0,
    'early_pct': 10.0,
    'late_pct': 10.0,
    'miss_pct': 20.0,
    'max_streak': 24,
    'mean_delta_ms': 1.5,
    'std_delta_ms': 7.25,
    'median_delta_ms': 0.5,
    'p90_abs_delta_ms': 18.0,
    'lane_stats': {},
  };
}

Map<String, Object?> _context({
  required String playerId,
  required String startedAtUtc,
  required String localDayKey,
  required String? sectionId,
}) {
  return {
    'player_id': playerId,
    'course_id': null,
    'course_node_id': null,
    'section_id': sectionId,
    'time_sig_num': 4,
    'time_sig_den': 4,
    'device_profile_id': null,
    'instrument_family': 'drums',
    'lesson_title': 'Eight Beat Check',
    'lesson_difficulty': 'beginner',
    'lesson_tags': ['rock', 'timing'],
    'lesson_skills': ['timing.onbeat'],
    'started_at_utc': startedAtUtc,
    'local_day_key': localDayKey,
    'local_hour': 20,
    'local_dow': 5,
  };
}
