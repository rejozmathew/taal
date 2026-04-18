import 'package:flutter/material.dart';

import '../../design/colors.dart';
import '../../design/tokens.dart';
import 'lesson_catalog.dart';

/// Browsable lesson library with search, difficulty filter, and lesson detail.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.lessons,
    required this.onStartPractice,
  });

  /// All available lesson summaries (pre-loaded).
  final List<LessonSummary> lessons;

  /// Called when user taps Practice on a lesson detail.
  final void Function(LessonSummary lesson) onStartPractice;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _searchQuery = '';
  String? _difficultyFilter; // null = all
  LessonSummary? _selectedLesson;

  List<LessonSummary> get _filtered {
    var lessons = widget.lessons;
    if (_difficultyFilter != null) {
      lessons = lessons
          .where((l) => l.difficulty == _difficultyFilter)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      lessons = lessons
          .where((l) => l.title.toLowerCase().contains(query))
          .toList();
    }
    return lessons;
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedLesson != null) {
      return _LessonDetailView(
        lesson: _selectedLesson!,
        onBack: () => setState(() => _selectedLesson = null),
        onStartPractice: () {
          widget.onStartPractice(_selectedLesson!);
        },
      );
    }
    return _buildListView(context);
  }

  Widget _buildListView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered;

    return Column(
      key: const ValueKey('app-shell-section-library'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Library', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: TaalTokens.space8),
        Text(
          '${widget.lessons.length} lessons available',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: TaalTokens.space16),
        // Search bar
        TextField(
          key: const ValueKey('library-search'),
          decoration: InputDecoration(
            hintText: 'Search by title…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    key: const ValueKey('library-search-clear'),
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _searchQuery = ''),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TaalTokens.radiusMedium),
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
        const SizedBox(height: TaalTokens.space12),
        // Difficulty filter chips
        Wrap(
          spacing: TaalTokens.space8,
          children: [
            _FilterChip(
              label: 'All',
              selected: _difficultyFilter == null,
              onSelected: () => setState(() => _difficultyFilter = null),
            ),
            _FilterChip(
              label: 'Beginner',
              selected: _difficultyFilter == 'beginner',
              onSelected: () => setState(() => _difficultyFilter = 'beginner'),
            ),
            _FilterChip(
              label: 'Intermediate',
              selected: _difficultyFilter == 'intermediate',
              onSelected: () =>
                  setState(() => _difficultyFilter = 'intermediate'),
            ),
            _FilterChip(
              label: 'Variety',
              selected: _difficultyFilter == 'variety',
              onSelected: () => setState(() => _difficultyFilter = 'variety'),
            ),
          ],
        ),
        const SizedBox(height: TaalTokens.space16),
        // Lesson list or empty state
        if (filtered.isEmpty)
          _EmptyFilterState(
            onReset: () => setState(() {
              _searchQuery = '';
              _difficultyFilter = null;
            }),
          )
        else
          ListView.separated(
            key: const ValueKey('library-lesson-list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: TaalTokens.space8),
            itemBuilder: (context, index) {
              final lesson = filtered[index];
              return _LessonCard(
                key: ValueKey('library-lesson-${lesson.id}'),
                lesson: lesson,
                scheme: scheme,
                onTap: () => setState(() => _selectedLesson = lesson),
              );
            },
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TaalTokens.space32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: TaalTokens.space12),
            Text(
              'No lessons match your filters.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: TaalTokens.space12),
            FilledButton.tonal(
              key: const ValueKey('library-reset-filters'),
              onPressed: onReset,
              child: const Text('Reset filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    super.key,
    required this.lesson,
    required this.scheme,
    required this.onTap,
  });

  final LessonSummary lesson;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: TaalTokens.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TaalTokens.radiusMedium),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(TaalTokens.space16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: TaalTokens.space4),
                    Wrap(
                      spacing: TaalTokens.space8,
                      runSpacing: TaalTokens.space4,
                      children: [
                        _DifficultyBadge(difficulty: lesson.difficulty),
                        _InfoChip(
                          icon: Icons.speed,
                          label: '${lesson.bpm.round()} BPM',
                        ),
                        if (lesson.estimatedMinutes > 0)
                          _InfoChip(
                            icon: Icons.timer_outlined,
                            label: '${lesson.estimatedMinutes} min',
                          ),
                      ],
                    ),
                    const SizedBox(height: TaalTokens.space8),
                    _LaneIcons(laneIds: lesson.laneIds),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifficultyBadge extends StatelessWidget {
  const _DifficultyBadge({required this.difficulty});

  final String difficulty;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (difficulty) {
      'beginner' => (
        TaalColors.gradeGood.withValues(alpha: 0.2),
        TaalColors.gradeGood,
      ),
      'intermediate' => (
        TaalColors.secondary.withValues(alpha: 0.2),
        TaalColors.secondary,
      ),
      'advanced' => (TaalColors.error.withValues(alpha: 0.2), TaalColors.error),
      _ => (TaalColors.tertiary.withValues(alpha: 0.2), TaalColors.tertiary),
    };

    final label = switch (difficulty) {
      'beginner' => 'Beginner',
      'intermediate' => 'Intermediate',
      'advanced' => 'Advanced',
      _ => difficulty,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TaalTokens.space8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(TaalTokens.radiusSmall),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _LaneIcons extends StatelessWidget {
  const _LaneIcons({required this.laneIds});

  final List<String> laneIds;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TaalTokens.space4,
      children: [
        for (final laneId in laneIds)
          Tooltip(
            message: _laneLabel(laneId),
            child: Icon(_laneIcon(laneId), size: 16, color: _laneColor(laneId)),
          ),
      ],
    );
  }

  static String _laneLabel(String laneId) {
    switch (laneId) {
      case 'kick':
        return 'Kick';
      case 'snare':
        return 'Snare';
      case 'hihat':
        return 'Hi-Hat';
      case 'crash':
        return 'Crash';
      case 'ride':
        return 'Ride';
      case 'tom1':
        return 'High Tom';
      case 'tom2':
        return 'Mid Tom';
      case 'tom3':
        return 'Floor Tom';
      default:
        return laneId;
    }
  }

  static IconData _laneIcon(String laneId) {
    // All drum pieces use a circle icon — differentiated by color.
    return Icons.circle;
  }

  static Color _laneColor(String laneId) {
    switch (laneId) {
      case 'kick':
        return TaalColors.primary;
      case 'snare':
        return TaalColors.secondary;
      case 'hihat':
        return TaalColors.tertiary;
      case 'crash':
        return TaalColors.lanePurple;
      case 'ride':
        return TaalColors.laneGray;
      case 'tom1':
        return TaalColors.laneGreen;
      case 'tom2':
        return TaalColors.laneYellow;
      case 'tom3':
        return TaalColors.laneLightTeal;
      default:
        return TaalColors.laneGray;
    }
  }
}

// ── Lesson Detail View ──────────────────────────────────────────────────────

class _LessonDetailView extends StatelessWidget {
  const _LessonDetailView({
    required this.lesson,
    required this.onBack,
    required this.onStartPractice,
  });

  final LessonSummary lesson;
  final VoidCallback onBack;
  final VoidCallback onStartPractice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      key: const ValueKey('library-lesson-detail'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back button
        TextButton.icon(
          key: const ValueKey('library-detail-back'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Library'),
        ),
        const SizedBox(height: TaalTokens.space8),
        Text(lesson.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: TaalTokens.space8),
        // Badges row
        Wrap(
          spacing: TaalTokens.space8,
          runSpacing: TaalTokens.space4,
          children: [
            _DifficultyBadge(difficulty: lesson.difficulty),
            _InfoChip(icon: Icons.speed, label: '${lesson.bpm.round()} BPM'),
            if (lesson.estimatedMinutes > 0)
              _InfoChip(
                icon: Icons.timer_outlined,
                label: '${lesson.estimatedMinutes} min',
              ),
          ],
        ),
        const SizedBox(height: TaalTokens.space16),
        // Lane icons
        Row(
          children: [
            Text('Lanes: ', style: Theme.of(context).textTheme.labelMedium),
            _LaneIcons(laneIds: lesson.laneIds),
          ],
        ),
        const SizedBox(height: TaalTokens.space16),
        // Skills
        if (lesson.skills.isNotEmpty) ...[
          Text('Skills', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: TaalTokens.space4),
          Wrap(
            spacing: TaalTokens.space4,
            runSpacing: TaalTokens.space4,
            children: [
              for (final skill in lesson.skills)
                Chip(
                  label: Text(_formatSkill(skill)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: TaalTokens.space16),
        ],
        // Objectives
        if (lesson.objectives.isNotEmpty) ...[
          Text('Objectives', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: TaalTokens.space4),
          for (final obj in lesson.objectives)
            Padding(
              padding: const EdgeInsets.only(bottom: TaalTokens.space4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: TaalTokens.space8),
                  Expanded(
                    child: Text(
                      obj,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: TaalTokens.space16),
        ],
        // Tags
        if (lesson.tags.isNotEmpty) ...[
          Wrap(
            spacing: TaalTokens.space4,
            children: [
              for (final tag in lesson.tags)
                Chip(
                  avatar: const Icon(Icons.tag, size: 14),
                  label: Text(tag),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: TaalTokens.space24),
        ],
        // Action buttons
        Wrap(
          spacing: TaalTokens.space12,
          children: [
            FilledButton.icon(
              key: const ValueKey('library-detail-practice'),
              onPressed: onStartPractice,
              icon: const Icon(Icons.music_note),
              label: const Text('Practice'),
            ),
          ],
        ),
      ],
    );
  }

  static String _formatSkill(String skill) {
    // Convert "timing.backbeat" → "Timing: Backbeat"
    return skill
        .split('.')
        .map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s)
        .join(': ');
  }
}
