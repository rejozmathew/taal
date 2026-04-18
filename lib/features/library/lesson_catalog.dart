import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Lightweight lesson metadata extracted from JSON for display in the Library.
class LessonSummary {
  const LessonSummary({
    required this.id,
    required this.title,
    required this.assetPath,
    required this.difficulty,
    required this.bpm,
    required this.estimatedMinutes,
    required this.laneIds,
    required this.tags,
    required this.skills,
    required this.objectives,
    this.description,
  });

  final String id;
  final String title;
  final String assetPath;
  final String difficulty;
  final double bpm;
  final int estimatedMinutes;
  final List<String> laneIds;
  final List<String> tags;
  final List<String> skills;
  final List<String> objectives;
  final String? description;

  String get difficultyLabel {
    switch (difficulty) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      default:
        return difficulty;
    }
  }
}

/// All known starter lesson asset paths.
const List<String> _starterLessonPaths = [
  'assets/content/lessons/starter/beginner-basic-rock.json',
  'assets/content/lessons/starter/beginner-first-fill.json',
  'assets/content/lessons/starter/beginner-four-on-floor.json',
  'assets/content/lessons/starter/beginner-kick-snare-space.json',
  'assets/content/lessons/starter/beginner-open-hihat.json',
  'assets/content/lessons/starter/intermediate-fill-resolution.json',
  'assets/content/lessons/starter/intermediate-ghost-note-backbeat.json',
  'assets/content/lessons/starter/intermediate-sixteenth-hats.json',
  'assets/content/lessons/starter/intermediate-syncopated-kick.json',
  'assets/content/lessons/starter/intermediate-tom-groove.json',
  'assets/content/lessons/starter/variety-blues-shuffle.json',
  'assets/content/lessons/starter/variety-funk-groove.json',
  'assets/content/lessons/starter/variety-half-time-rock.json',
];

/// Loads all starter lesson metadata from the asset bundle.
///
/// Returns summaries sorted by difficulty (beginner → intermediate → variety)
/// then by title.
Future<List<LessonSummary>> loadLessonCatalog({
  Future<String> Function(String) loadString = _defaultLoadString,
}) async {
  final futures = _starterLessonPaths.map((path) async {
    final json = await loadString(path);
    return _parseSummary(path, json);
  });
  final summaries = await Future.wait(futures);
  summaries.sort((a, b) {
    final diffOrder = _difficultyOrder(
      a.difficulty,
    ).compareTo(_difficultyOrder(b.difficulty));
    if (diffOrder != 0) return diffOrder;
    return a.title.compareTo(b.title);
  });
  return summaries;
}

Future<String> _defaultLoadString(String path) => rootBundle.loadString(path);

int _difficultyOrder(String difficulty) {
  switch (difficulty) {
    case 'beginner':
      return 0;
    case 'intermediate':
      return 1;
    case 'advanced':
      return 2;
    default:
      return 3;
  }
}

LessonSummary _parseSummary(String assetPath, String jsonStr) {
  final map = json.decode(jsonStr) as Map<String, dynamic>;
  final meta = map['metadata'] as Map<String, dynamic>? ?? {};
  final timing = map['timing'] as Map<String, dynamic>? ?? {};
  final tempoMap = timing['tempo_map'] as List<dynamic>? ?? [];
  final firstTempo = tempoMap.isNotEmpty
      ? tempoMap[0] as Map<String, dynamic>
      : null;
  final bpm = (firstTempo?['bpm'] as num?)?.toDouble() ?? 0.0;
  final lanes = map['lanes'] as List<dynamic>? ?? [];
  final laneIds = lanes
      .map((l) => (l as Map<String, dynamic>)['lane_id'] as String)
      .toList();

  return LessonSummary(
    id: map['id'] as String? ?? assetPath,
    title: map['title'] as String? ?? 'Untitled',
    assetPath: assetPath,
    difficulty: meta['difficulty'] as String? ?? 'beginner',
    bpm: bpm,
    estimatedMinutes: (meta['estimated_minutes'] as num?)?.toInt() ?? 0,
    laneIds: laneIds,
    tags: _stringList(meta['tags']),
    skills: _stringList(meta['skills']),
    objectives: _stringList(meta['objectives']),
    description: map['description'] as String?,
  );
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((e) => e.toString()).toList();
  }
  return const [];
}
