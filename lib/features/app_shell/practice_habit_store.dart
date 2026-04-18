import 'dart:convert';

import 'package:taal/src/rust/api/practice_habits.dart' as rust_habits;

abstract class PracticeHabitStore {
  PracticeHabitSnapshot loadPracticeHabitSnapshot({
    required String playerId,
    required String todayLocalDayKey,
  });
}

class RustPracticeHabitStore implements PracticeHabitStore {
  const RustPracticeHabitStore(this.databasePath);

  final String databasePath;

  @override
  PracticeHabitSnapshot loadPracticeHabitSnapshot({
    required String playerId,
    required String todayLocalDayKey,
  }) {
    final result = rust_habits.loadPracticeHabitSnapshot(
      databasePath: databasePath,
      playerId: playerId,
      todayLocalDayKey: todayLocalDayKey,
    );
    final snapshotJson = result.snapshotJson;
    if (snapshotJson != null) {
      final decoded = jsonDecode(snapshotJson);
      if (decoded is Map<String, Object?>) {
        return PracticeHabitSnapshot.fromJson(decoded);
      }
    }
    throw PracticeHabitStoreException(
      result.error ?? 'Practice habit snapshot failed.',
    );
  }
}

class PracticeHabitSnapshot {
  const PracticeHabitSnapshot({
    required this.playerId,
    required this.todayLocalDayKey,
    required this.dailyGoalMinutes,
    required this.todayMinutesCompleted,
    required this.todayGoalMet,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.streakState,
    required this.streakMessage,
    required this.milestoneMessage,
    required this.lastPracticeDayKey,
    required this.today,
    required this.week,
  });

  final String playerId;
  final String todayLocalDayKey;
  final int dailyGoalMinutes;
  final int todayMinutesCompleted;
  final bool todayGoalMet;
  final int currentStreakDays;
  final int longestStreakDays;
  final PracticeStreakState streakState;
  final String? streakMessage;
  final String? milestoneMessage;
  final String? lastPracticeDayKey;
  final PracticeDaySummary today;
  final PracticeWeekSummary week;

  factory PracticeHabitSnapshot.fromJson(Map<String, Object?> json) {
    return PracticeHabitSnapshot(
      playerId: json['player_id'] as String,
      todayLocalDayKey: json['today_local_day_key'] as String,
      dailyGoalMinutes: json['daily_goal_minutes'] as int,
      todayMinutesCompleted: json['today_minutes_completed'] as int,
      todayGoalMet: json['today_goal_met'] as bool,
      currentStreakDays: json['current_streak_days'] as int,
      longestStreakDays: json['longest_streak_days'] as int,
      streakState: PracticeStreakStateX.fromJson(
        json['streak_state'] as String,
      ),
      streakMessage: json['streak_message'] as String?,
      milestoneMessage: json['milestone_message'] as String?,
      lastPracticeDayKey: json['last_practice_day_key'] as String?,
      today: PracticeDaySummary.fromJson(_map(json['today'])),
      week: PracticeWeekSummary.fromJson(_map(json['week'])),
    );
  }
}

class PracticeDaySummary {
  const PracticeDaySummary({
    required this.localDayKey,
    required this.minutesCompleted,
    required this.scoredAttemptCount,
    required this.fullLessonCompletions,
  });

  final String localDayKey;
  final int minutesCompleted;
  final int scoredAttemptCount;
  final int fullLessonCompletions;

  factory PracticeDaySummary.fromJson(Map<String, Object?> json) {
    return PracticeDaySummary(
      localDayKey: json['local_day_key'] as String,
      minutesCompleted: json['minutes_completed'] as int,
      scoredAttemptCount: json['scored_attempt_count'] as int,
      fullLessonCompletions: json['full_lesson_completions'] as int,
    );
  }
}

class PracticeWeekSummary {
  const PracticeWeekSummary({
    required this.startLocalDayKey,
    required this.endLocalDayKey,
    required this.daysPracticed,
    required this.totalMinutesCompleted,
    required this.scoredAttemptCount,
    required this.fullLessonCompletions,
  });

  final String startLocalDayKey;
  final String endLocalDayKey;
  final int daysPracticed;
  final int totalMinutesCompleted;
  final int scoredAttemptCount;
  final int fullLessonCompletions;

  factory PracticeWeekSummary.fromJson(Map<String, Object?> json) {
    return PracticeWeekSummary(
      startLocalDayKey: json['start_local_day_key'] as String,
      endLocalDayKey: json['end_local_day_key'] as String,
      daysPracticed: json['days_practiced'] as int,
      totalMinutesCompleted: json['total_minutes_completed'] as int,
      scoredAttemptCount: json['scored_attempt_count'] as int,
      fullLessonCompletions: json['full_lesson_completions'] as int,
    );
  }
}

enum PracticeStreakState { active, atRisk, reset }

extension PracticeStreakStateX on PracticeStreakState {
  static PracticeStreakState fromJson(String value) {
    switch (value) {
      case 'active':
        return PracticeStreakState.active;
      case 'at_risk':
        return PracticeStreakState.atRisk;
      case 'reset':
        return PracticeStreakState.reset;
    }
    throw PracticeHabitStoreException('Unknown streak state: $value');
  }
}

class PracticeHabitStoreException implements Exception {
  PracticeHabitStoreException(this.message);

  final String message;

  @override
  String toString() => message;
}

String localDayKey(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

Map<String, Object?> _map(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  throw PracticeHabitStoreException('Expected JSON object.');
}
