import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/player/layout_compatibility/layout_compatibility.dart';
import 'package:taal/features/player/review/post_lesson_review_screen.dart';

void main() {
  test('review helpers preserve summary metrics and suggestions', () {
    const summary = _summary;

    expect(summary.bestStatText(), 'Best stat: Snare held 96% hit rate.');
    expect(
      summary.improvementSuggestions(),
      contains(
        'You are landing late on average; slow the tempo and settle into the click.',
      ),
    );
    expect(
      summary.improvementSuggestions(),
      contains('Focus Kick: +24.0 ms average timing.'),
    );
  });

  testWidgets('review screen displays attempt summary values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PostLessonReviewScreen(
          summary: _summary,
          courseProgressLabel: 'Lesson 2 of 5',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backbeat Timing'), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('92% accuracy'), findsOneWidget);
    expect(find.text('Lesson 2 of 5'), findsOneWidget);
    expect(find.textContaining('+14.0 ms'), findsOneWidget);
    expect(find.text('Snare'), findsOneWidget);
    expect(find.text('96% hit · +6.0 ms'), findsOneWidget);
  });

  testWidgets('best stat appears before improvement suggestions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PostLessonReviewScreen(summary: _summary)),
    );
    await tester.pumpAndSettle();

    final bestStatTop = tester
        .getTopLeft(find.byKey(const ValueKey('best-stat')))
        .dy;
    final suggestionTop = tester
        .getTopLeft(
          find.byKey(
            const ValueKey(
              'suggestion-You are landing late on average; slow the tempo and settle into the click.',
            ),
          ),
        )
        .dy;

    expect(bestStatTop, lessThan(suggestionTop));
  });

  testWidgets('timing histogram shows early and late distribution', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PostLessonReviewScreen(summary: _summary)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TimingHistogram), findsOneWidget);
    expect(find.text('Early'), findsOneWidget);
    expect(find.text('Late'), findsOneWidget);
    expect(find.text('18%'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
  });

  testWidgets('review screen names excluded lanes and personal best rule', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PostLessonReviewScreen(
          summary: _summary,
          layoutCompatibility: _requiredMissingCompatibility,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Scoring adjusted: 1 lane unavailable on current kit (Snare).'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Partial compatibility results do not qualify as personal bests.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('review-layout-compatibility')),
      findsOneWidget,
    );
  });

  testWidgets('optional missing lanes do not show personal best warning', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PostLessonReviewScreen(
          summary: _summary,
          layoutCompatibility: _optionalMissingCompatibility,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Scoring adjusted: 1 lane unavailable on current kit (Cowbell).',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Partial compatibility results do not qualify as personal bests.',
      ),
      findsNothing,
    );
  });

  testWidgets('review actions call navigation callbacks', (tester) async {
    var retried = false;
    var next = false;
    var back = false;

    await tester.pumpWidget(
      MaterialApp(
        home: PostLessonReviewScreen(
          summary: _summary,
          onRetry: () => retried = true,
          onNextLesson: () => next = true,
          onBackToLibrary: () => back = true,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.tap(find.text('Next Lesson'));
    await tester.tap(find.text('Back to Library'));

    expect(retried, isTrue);
    expect(next, isTrue);
    expect(back, isTrue);
  });
}

const _summary = PostLessonAttemptSummary(
  lessonTitle: 'Backbeat Timing',
  scoreTotal: 88,
  accuracyPct: 92,
  hitRatePct: 94,
  perfectPct: 62,
  earlyPct: 18,
  latePct: 10,
  missPct: 4,
  maxStreak: 32,
  meanDeltaMs: 14,
  stdDeltaMs: 18,
  medianDeltaMs: 12,
  p90AbsDeltaMs: 34,
  bpm: 105,
  durationMs: 64000,
  laneStats: {
    'snare': PostLessonLaneStats(
      hitRatePct: 96,
      missPct: 2,
      meanDeltaMs: 6,
      stdDeltaMs: 12,
    ),
    'kick': PostLessonLaneStats(
      hitRatePct: 89,
      missPct: 6,
      meanDeltaMs: 24,
      stdDeltaMs: 20,
    ),
  },
);

const _requiredMissingCompatibility = LayoutCompatibilitySnapshot(
  status: LayoutCompatibilityStatus.requiredMissing,
  lessonLanes: ['kick', 'snare'],
  requiredLanes: ['kick', 'snare'],
  optionalLanes: [],
  mappedLanes: ['kick'],
  missingRequiredLanes: ['snare'],
  missingOptionalLanes: [],
  excludedLanes: ['snare'],
);

const _optionalMissingCompatibility = LayoutCompatibilitySnapshot(
  status: LayoutCompatibilityStatus.optionalMissing,
  lessonLanes: ['kick', 'snare', 'cowbell'],
  requiredLanes: ['kick', 'snare'],
  optionalLanes: ['cowbell'],
  mappedLanes: ['kick', 'snare'],
  missingRequiredLanes: [],
  missingOptionalLanes: ['cowbell'],
  excludedLanes: ['cowbell'],
);
