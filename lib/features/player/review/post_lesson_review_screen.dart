import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:taal/design/colors.dart';
import 'package:taal/features/player/layout_compatibility/layout_compatibility.dart';

class PostLessonReviewScreen extends StatelessWidget {
  const PostLessonReviewScreen({
    super.key,
    required this.summary,
    this.courseProgressLabel,
    this.onRetry,
    this.onNextLesson,
    this.onBackToLibrary,
    this.layoutCompatibility,
  });

  final PostLessonAttemptSummary summary;
  final String? courseProgressLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onNextLesson;
  final VoidCallback? onBackToLibrary;
  final LayoutCompatibilitySnapshot? layoutCompatibility;

  @override
  Widget build(BuildContext context) {
    final suggestions = summary.improvementSuggestions();
    final compatibility = layoutCompatibility;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ScoreHeader(summary: summary),
              const SizedBox(height: 18),
              if (courseProgressLabel case final label?) ...[
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 18),
              ],
              Text(
                summary.bestStatText(),
                key: const ValueKey('best-stat'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              if (compatibility != null && compatibility.hasExcludedLanes) ...[
                _CompatibilityReviewPanel(compatibility: compatibility),
                const SizedBox(height: 18),
              ],
              TimingHistogram(summary: summary),
              const SizedBox(height: 22),
              _LaneBreakdown(summary: summary),
              const SizedBox(height: 22),
              Text(
                'Try this next',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final suggestion in suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    suggestion,
                    key: ValueKey('suggestion-$suggestion'),
                  ),
                ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                  OutlinedButton(
                    onPressed: onNextLesson,
                    child: const Text('Next Lesson'),
                  ),
                  TextButton(
                    onPressed: onBackToLibrary,
                    child: const Text('Back to Library'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompatibilityReviewPanel extends StatelessWidget {
  const _CompatibilityReviewPanel({required this.compatibility});

  final LayoutCompatibilitySnapshot compatibility;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('review-layout-compatibility'),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              compatibility.reviewAdjustmentText,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (compatibility.isPartialPlayResult) ...[
              const SizedBox(height: 6),
              Text(compatibility.personalBestText),
            ],
          ],
        ),
      ),
    );
  }
}

class PostLessonAttemptSummary {
  const PostLessonAttemptSummary({
    required this.lessonTitle,
    required this.scoreTotal,
    required this.accuracyPct,
    required this.hitRatePct,
    required this.perfectPct,
    required this.earlyPct,
    required this.latePct,
    required this.missPct,
    required this.maxStreak,
    required this.meanDeltaMs,
    required this.stdDeltaMs,
    required this.laneStats,
    this.bpm = 120,
    this.durationMs = 0,
    this.medianDeltaMs,
    this.p90AbsDeltaMs,
  });

  final String lessonTitle;
  final double scoreTotal;
  final double accuracyPct;
  final double hitRatePct;
  final double perfectPct;
  final double earlyPct;
  final double latePct;
  final double missPct;
  final int maxStreak;
  final double meanDeltaMs;
  final double stdDeltaMs;
  final double? medianDeltaMs;
  final double? p90AbsDeltaMs;
  final double bpm;
  final int durationMs;
  final Map<String, PostLessonLaneStats> laneStats;

  String bestStatText() {
    if (perfectPct >= 70) {
      return 'Best stat: ${_pct(perfectPct)} perfect hits.';
    }
    final bestLane = sortedLaneEntries().firstOrNull;
    if (bestLane != null) {
      return 'Best stat: ${_laneLabel(bestLane.key)} held ${_pct(bestLane.value.hitRatePct)} hit rate.';
    }
    return 'Best stat: ${_pct(hitRatePct)} hit rate.';
  }

  List<String> improvementSuggestions() {
    final suggestions = <String>[];

    if (missPct > 10) {
      suggestions.add(
        'Loop the section with the most misses before the next run.',
      );
    } else if (meanDeltaMs > 8) {
      suggestions.add(
        'You are landing late on average; slow the tempo and settle into the click.',
      );
    } else if (meanDeltaMs < -8) {
      suggestions.add(
        'You are ahead of the beat; relax your lead hand before the backbeat.',
      );
    } else if (stdDeltaMs > 25) {
      suggestions.add(
        'Keep the tempo steady and aim for smaller timing swings.',
      );
    } else {
      suggestions.add('Repeat once to lock in the same timing feel.');
    }

    final weakestLane = laneStats.entries.toList()
      ..sort((left, right) {
        final missCompare = right.value.missPct.compareTo(left.value.missPct);
        if (missCompare != 0) {
          return missCompare;
        }
        return right.value.meanDeltaMs.abs().compareTo(
          left.value.meanDeltaMs.abs(),
        );
      });
    if (weakestLane.isNotEmpty) {
      final lane = weakestLane.first;
      suggestions.add(
        'Focus ${_laneLabel(lane.key)}: ${_signedMs(lane.value.meanDeltaMs)} average timing.',
      );
    }

    return suggestions.take(2).toList(growable: false);
  }

  List<MapEntry<String, PostLessonLaneStats>> sortedLaneEntries() {
    final entries = laneStats.entries.toList();
    entries.sort(
      (left, right) => right.value.hitRatePct.compareTo(left.value.hitRatePct),
    );
    return entries;
  }
}

class PostLessonLaneStats {
  const PostLessonLaneStats({
    required this.hitRatePct,
    required this.missPct,
    required this.meanDeltaMs,
    required this.stdDeltaMs,
  });

  final double hitRatePct;
  final double missPct;
  final double meanDeltaMs;
  final double stdDeltaMs;
}

class TimingHistogram extends StatelessWidget {
  const TimingHistogram({super.key, required this.summary});

  final PostLessonAttemptSummary summary;

  @override
  Widget build(BuildContext context) {
    final bars = [
      _TimingBar(label: 'Early', value: summary.earlyPct),
      _TimingBar(label: 'Perfect', value: summary.perfectPct),
      _TimingBar(label: 'Late', value: summary.latePct),
      _TimingBar(label: 'Miss', value: summary.missPct),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timing distribution',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bar in bars)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _TimingBarWidget(bar: bar),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Average timing: ${_signedMs(summary.meanDeltaMs)}. Spread: ${summary.stdDeltaMs.toStringAsFixed(1)} ms.',
        ),
      ],
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.summary});

  final PostLessonAttemptSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(summary.lessonTitle, style: textTheme.headlineSmall),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: summary.scoreTotal),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Text(
              value.round().toString(),
              key: const ValueKey('score-total'),
              style: textTheme.displayLarge,
            );
          },
        ),
        Text('${_pct(summary.accuracyPct)} accuracy'),
        const SizedBox(height: 6),
        Text(
          '${_pct(summary.hitRatePct)} hit rate · ${summary.maxStreak} max streak · ${summary.bpm.round()} BPM',
        ),
      ],
    );
  }
}

class _LaneBreakdown extends StatelessWidget {
  const _LaneBreakdown({required this.summary});

  final PostLessonAttemptSummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = summary.sortedLaneEntries();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lane breakdown', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LaneRow(laneId: entry.key, stats: entry.value),
          ),
      ],
    );
  }
}

class _LaneRow extends StatelessWidget {
  const _LaneRow({required this.laneId, required this.stats});

  final String laneId;
  final PostLessonLaneStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(_laneLabel(laneId))),
            Text(
              '${_pct(stats.hitRatePct)} hit · ${_signedMs(stats.meanDeltaMs)}',
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: (stats.hitRatePct / 100).clamp(0, 1)),
      ],
    );
  }
}

class _TimingBar {
  const _TimingBar({required this.label, required this.value});

  final String label;
  final double value;
}

class _TimingBarWidget extends StatelessWidget {
  const _TimingBarWidget({required this.bar});

  final _TimingBar bar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = math.max(6.0, bar.value.clamp(0, 100).toDouble());
    final color = switch (bar.label) {
      'Early' => TaalColors.gradeEarly,
      'Perfect' => TaalColors.gradePerfect,
      'Late' => TaalColors.gradeLate,
      _ => scheme.outline,
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: height / 100,
              widthFactor: 0.72,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(bar.label, maxLines: 1),
        Text(_pct(bar.value)),
      ],
    );
  }
}

String _pct(double value) => '${value.round()}%';

String _signedMs(double value) {
  final sign = value >= 0 ? '+' : '';
  return '$sign${value.toStringAsFixed(1)} ms';
}

String _laneLabel(String laneId) {
  return laneId
      .split('_')
      .map(
        (part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}',
      )
      .join(' ');
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
