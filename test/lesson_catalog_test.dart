import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/library/lesson_catalog.dart';

const _sampleJson = '''
{
  "schema_version": "1.0",
  "id": "test-lesson-id",
  "title": "Test Lesson",
  "timing": {
    "time_signature": { "num": 4, "den": 4 },
    "ticks_per_beat": 480,
    "tempo_map": [{ "pos": { "bar": 1, "beat": 1, "tick": 0 }, "bpm": 100.0 }]
  },
  "lanes": [
    { "lane_id": "kick", "events": [] },
    { "lane_id": "snare", "events": [] }
  ],
  "metadata": {
    "difficulty": "intermediate",
    "tags": ["rock"],
    "skills": ["timing.backbeat"],
    "objectives": ["Play rock beat."],
    "estimated_minutes": 5
  }
}
''';

void main() {
  test('loadLessonCatalog parses JSON and sorts by difficulty', () async {
    final beginner = _sampleJson.replaceAll('"intermediate"', '"beginner"')
        .replaceAll('test-lesson-id', 'beginner-id')
        .replaceAll('Test Lesson', 'Beginner Lesson');
    final intermediate = _sampleJson
        .replaceAll('test-lesson-id', 'intermediate-id')
        .replaceAll('Test Lesson', 'Intermediate Lesson');

    final catalog = await loadLessonCatalog(
      loadString: (path) async {
        if (path.contains('beginner')) return beginner;
        return intermediate;
      },
    );

    // Should be sorted: all beginners first, then intermediates
    final beginnerIndex = catalog.indexWhere((l) => l.id == 'beginner-id');
    final intermediateIndex = catalog.indexWhere(
      (l) => l.id == 'intermediate-id',
    );
    expect(beginnerIndex, lessThan(intermediateIndex));
  });

  test('LessonSummary.difficultyLabel returns correct labels', () {
    expect(
      const LessonSummary(
        id: '1', title: 't', assetPath: 'p',
        difficulty: 'beginner', bpm: 0, estimatedMinutes: 0,
        laneIds: [], tags: [], skills: [], objectives: [],
      ).difficultyLabel,
      'Beginner',
    );
    expect(
      const LessonSummary(
        id: '1', title: 't', assetPath: 'p',
        difficulty: 'intermediate', bpm: 0, estimatedMinutes: 0,
        laneIds: [], tags: [], skills: [], objectives: [],
      ).difficultyLabel,
      'Intermediate',
    );
    expect(
      const LessonSummary(
        id: '1', title: 't', assetPath: 'p',
        difficulty: 'advanced', bpm: 0, estimatedMinutes: 0,
        laneIds: [], tags: [], skills: [], objectives: [],
      ).difficultyLabel,
      'Advanced',
    );
  });

  test('catalog extracts all fields from JSON', () async {
    final catalog = await loadLessonCatalog(
      loadString: (_) async => _sampleJson,
    );

    expect(catalog.length, 13); // one for each asset path
    final first = catalog.first;
    expect(first.title, 'Test Lesson');
    expect(first.bpm, 100.0);
    expect(first.estimatedMinutes, 5);
    expect(first.laneIds, ['kick', 'snare']);
    expect(first.tags, ['rock']);
    expect(first.skills, ['timing.backbeat']);
    expect(first.objectives, ['Play rock beat.']);
  });
}
