import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:taal/src/rust/api/practice_attempts.dart';
import 'package:taal/src/rust/api/profiles.dart';
import 'package:taal/src/rust/frb_generated.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Dart records and queries practice attempts through the Rust bridge',
    () async {
      await RustLib.init();

      final tempDir = await Directory.systemTemp.createTemp(
        'taal_practice_attempt_bridge_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final databasePath = [
        tempDir.path,
        'practice_attempts.sqlite',
      ].join(Platform.pathSeparator);

      final player = createLocalProfile(
        databasePath: databasePath,
        name: 'Rejo',
        avatar: null,
        experienceLevel: ProfileExperienceLevelDto.beginner,
      ).state!.activeProfileId!;

      final saved = recordPracticeAttempt(
        databasePath: databasePath,
        summaryJson: jsonEncode(_summary(scoreTotal: 91.5)),
        contextJson: jsonEncode(_context(player)),
      );
      expect(saved.error, isNull);

      final attempt = jsonDecode(saved.attemptJson!) as Map<String, Object?>;
      expect(attempt['player_id'], player);
      expect(attempt['lesson_id'], _lessonId);
      expect(attempt['course_id'], _courseId);
      expect(attempt['mode'], 'play');
      expect(attempt['score_total'], 91.5);
      expect(attempt['lesson_title'], 'Eight Beat Check');
      expect(
        (attempt['lane_stats'] as Map<String, Object?>),
        contains('snare'),
      );

      final listed = listPracticeAttempts(
        databasePath: databasePath,
        playerId: player,
        lessonId: _lessonId,
        courseId: _courseId,
        startedAtUtcFrom: '2026-04-17T00:00:00Z',
        startedAtUtcTo: '2026-04-17T23:59:59Z',
      );
      expect(listed.error, isNull);
      expect(listed.attemptsJson, hasLength(1));
      expect(jsonDecode(listed.attemptsJson.single)['id'], attempt['id']);
    },
  );
}

const _lessonId = '550e8400-e29b-41d4-a716-446655440301';
const _courseId = '550e8400-e29b-41d4-a716-446655440401';

Map<String, Object?> _summary({required double scoreTotal}) {
  return {
    'lesson_id': _lessonId,
    'mode': 'play',
    'bpm': 120.0,
    'duration_ms': 64000,
    'score_total': scoreTotal,
    'accuracy_pct': scoreTotal,
    'hit_rate_pct': 92.0,
    'perfect_pct': 60.0,
    'early_pct': 12.0,
    'late_pct': 8.0,
    'miss_pct': 20.0,
    'max_streak': 24,
    'mean_delta_ms': 1.5,
    'std_delta_ms': 7.25,
    'median_delta_ms': 0.5,
    'p90_abs_delta_ms': 18.0,
    'lane_stats': {
      'snare': {
        'hit_rate_pct': 100.0,
        'miss_pct': 0.0,
        'mean_delta_ms': -2.0,
        'std_delta_ms': 5.0,
      },
    },
  };
}

Map<String, Object?> _context(String playerId) {
  return {
    'player_id': playerId,
    'course_id': _courseId,
    'course_node_id': 'node-1',
    'section_id': 'full',
    'time_sig_num': 4,
    'time_sig_den': 4,
    'device_profile_id': null,
    'instrument_family': 'drums',
    'lesson_title': 'Eight Beat Check',
    'lesson_difficulty': 'beginner',
    'lesson_tags': ['rock', 'timing'],
    'lesson_skills': ['timing.onbeat'],
    'started_at_utc': '2026-04-17T14:00:00Z',
    'local_hour': 9,
    'local_dow': 5,
  };
}
