import 'package:flutter/material.dart';
import 'package:taal/design/colors.dart';

enum LayoutCompatibilityStatus { full, optionalMissing, requiredMissing }

class LayoutCompatibilitySnapshot {
  const LayoutCompatibilitySnapshot({
    required this.status,
    required this.lessonLanes,
    required this.requiredLanes,
    required this.optionalLanes,
    required this.mappedLanes,
    required this.missingRequiredLanes,
    required this.missingOptionalLanes,
    required this.excludedLanes,
  });

  factory LayoutCompatibilitySnapshot.full() {
    return const LayoutCompatibilitySnapshot(
      status: LayoutCompatibilityStatus.full,
      lessonLanes: [],
      requiredLanes: [],
      optionalLanes: [],
      mappedLanes: [],
      missingRequiredLanes: [],
      missingOptionalLanes: [],
      excludedLanes: [],
    );
  }

  factory LayoutCompatibilitySnapshot.fromJson(Map<String, Object?> json) {
    return LayoutCompatibilitySnapshot(
      status: _statusFromJson(json['status'] as String?),
      lessonLanes: _strings(json['lesson_lanes']),
      requiredLanes: _strings(json['required_lanes']),
      optionalLanes: _strings(json['optional_lanes']),
      mappedLanes: _strings(json['mapped_lanes']),
      missingRequiredLanes: _strings(json['missing_required_lanes']),
      missingOptionalLanes: _strings(json['missing_optional_lanes']),
      excludedLanes: _strings(json['excluded_lanes']),
    );
  }

  final LayoutCompatibilityStatus status;
  final List<String> lessonLanes;
  final List<String> requiredLanes;
  final List<String> optionalLanes;
  final List<String> mappedLanes;
  final List<String> missingRequiredLanes;
  final List<String> missingOptionalLanes;
  final List<String> excludedLanes;

  bool get isFull => status == LayoutCompatibilityStatus.full;

  bool get hasExcludedLanes => excludedLanes.isNotEmpty;

  bool get isPartialPlayResult =>
      status == LayoutCompatibilityStatus.requiredMissing;

  String get indicatorLabel {
    switch (status) {
      case LayoutCompatibilityStatus.full:
        return 'Kit ready';
      case LayoutCompatibilityStatus.optionalMissing:
        return 'Optional lanes missing';
      case LayoutCompatibilityStatus.requiredMissing:
        return 'Partial compatibility';
    }
  }

  String get practiceWarning {
    if (!hasExcludedLanes) {
      return 'All lesson lanes are available on this kit.';
    }
    return 'Missing lanes on this kit: ${_laneList(excludedLanes)}. They stay visible but are not scored.';
  }

  String get playWarning {
    if (!hasExcludedLanes) {
      return 'All lesson lanes are available on this kit.';
    }
    if (isPartialPlayResult) {
      return 'Partial compatibility: ${_unavailableCountLabel(excludedLanes.length)} unavailable.';
    }
    return 'Optional lanes unavailable: ${_laneList(excludedLanes)}. This run still counts as full compatibility.';
  }

  String get reviewAdjustmentText {
    return 'Scoring adjusted: ${_unavailableCountLabel(excludedLanes.length)} unavailable on current kit (${_laneList(excludedLanes)}).';
  }

  String get personalBestText {
    if (!isPartialPlayResult) {
      return '';
    }
    return 'Partial compatibility results do not qualify as personal bests.';
  }
}

class LayoutCompatibilityIndicator extends StatelessWidget {
  const LayoutCompatibilityIndicator({super.key, required this.compatibility});

  final LayoutCompatibilitySnapshot compatibility;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Chip(
      key: const ValueKey('layout-compatibility-indicator'),
      label: Text(compatibility.indicatorLabel),
      backgroundColor: _statusColor(scheme, compatibility.status),
    );
  }
}

class LayoutCompatibilityBanner extends StatelessWidget {
  const LayoutCompatibilityBanner({
    super.key,
    required this.compatibility,
    required this.mode,
  });

  final LayoutCompatibilitySnapshot compatibility;
  final LayoutCompatibilityBannerMode mode;

  @override
  Widget build(BuildContext context) {
    if (!compatibility.hasExcludedLanes) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('layout-compatibility-banner'),
      decoration: BoxDecoration(
        color: _statusColor(scheme, compatibility.status),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          mode == LayoutCompatibilityBannerMode.practice
              ? compatibility.practiceWarning
              : compatibility.playWarning,
          style: TextStyle(
            color:
                compatibility.status ==
                    LayoutCompatibilityStatus.requiredMissing
                ? scheme.onErrorContainer
                : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

enum LayoutCompatibilityBannerMode { practice, play }

Color _statusColor(ColorScheme scheme, LayoutCompatibilityStatus status) {
  switch (status) {
    case LayoutCompatibilityStatus.full:
      return Color.alphaBlend(
        TaalColors.compatFull.withValues(alpha: 0.22),
        scheme.surface,
      );
    case LayoutCompatibilityStatus.optionalMissing:
      return Color.alphaBlend(
        TaalColors.compatOptionalMissing.withValues(alpha: 0.28),
        scheme.surface,
      );
    case LayoutCompatibilityStatus.requiredMissing:
      return scheme.errorContainer;
  }
}

LayoutCompatibilityStatus _statusFromJson(String? value) {
  switch (value) {
    case 'full':
    case null:
      return LayoutCompatibilityStatus.full;
    case 'optional_missing':
      return LayoutCompatibilityStatus.optionalMissing;
    case 'required_missing':
      return LayoutCompatibilityStatus.requiredMissing;
  }
  throw ArgumentError.value(value, 'status', 'unknown layout compatibility');
}

List<String> _strings(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.whereType<String>().toList(growable: false);
}

String _laneList(List<String> laneIds) {
  return laneIds.map(_laneLabel).join(', ');
}

String _unavailableCountLabel(int count) {
  return '$count ${count == 1 ? 'lane' : 'lanes'}';
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
