import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/library/lesson_catalog.dart';
import 'package:taal/features/library/library_screen.dart';

const _testLessons = [
  LessonSummary(
    id: 'beginner-1',
    title: 'Basic Rock Beat',
    assetPath: 'assets/content/lessons/starter/beginner-basic-rock.json',
    difficulty: 'beginner',
    bpm: 92,
    estimatedMinutes: 4,
    laneIds: ['kick', 'snare', 'hihat'],
    tags: ['rock', 'backbeat'],
    skills: ['timing.backbeat', 'subdivision.8ths'],
    objectives: ['Lock kick on 1 and 3 with snare on 2 and 4.'],
  ),
  LessonSummary(
    id: 'beginner-2',
    title: 'First Fill',
    assetPath: 'assets/content/lessons/starter/beginner-first-fill.json',
    difficulty: 'beginner',
    bpm: 80,
    estimatedMinutes: 3,
    laneIds: ['kick', 'snare', 'hihat', 'tom1'],
    tags: ['fills'],
    skills: ['fills.basic'],
    objectives: ['Execute a simple two-bar fill.'],
  ),
  LessonSummary(
    id: 'intermediate-1',
    title: 'Ghost Note Backbeat',
    assetPath:
        'assets/content/lessons/starter/intermediate-ghost-note-backbeat.json',
    difficulty: 'intermediate',
    bpm: 88,
    estimatedMinutes: 5,
    laneIds: ['kick', 'snare', 'hihat'],
    tags: ['ghost-notes'],
    skills: ['dynamics.ghost'],
    objectives: ['Play ghost notes before the backbeat.'],
  ),
  LessonSummary(
    id: 'variety-1',
    title: 'Blues Shuffle',
    assetPath: 'assets/content/lessons/starter/variety-blues-shuffle.json',
    difficulty: 'variety',
    bpm: 110,
    estimatedMinutes: 5,
    laneIds: ['kick', 'snare', 'hihat', 'ride'],
    tags: ['blues', 'shuffle'],
    skills: ['subdivision.triplets'],
    objectives: ['Play a shuffled ride pattern.'],
  ),
];

void main() {
  testWidgets('library shows all lessons with difficulty badges', (
    tester,
  ) async {
    LessonSummary? practiceLesson;
    await _pumpLibrary(
      tester,
      lessons: _testLessons,
      onStartPractice: (l) => practiceLesson = l,
    );

    // Header
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('4 lessons available'), findsOneWidget);

    // All lesson titles visible
    expect(find.text('Basic Rock Beat'), findsOneWidget);
    expect(find.text('First Fill'), findsOneWidget);
    expect(find.text('Ghost Note Backbeat'), findsOneWidget);
    expect(find.text('Blues Shuffle'), findsOneWidget);

    // Difficulty badges visible
    expect(find.text('Beginner'), findsAtLeast(1));
    expect(find.text('Intermediate'), findsAtLeast(1));

    // BPM chips visible
    expect(find.text('92 BPM'), findsOneWidget);
    expect(find.text('88 BPM'), findsOneWidget);
  });

  testWidgets('search filters lessons by title', (tester) async {
    await _pumpLibrary(tester, lessons: _testLessons);

    // Type in search
    await tester.enterText(
      find.byKey(const ValueKey('library-search')),
      'rock',
    );
    await tester.pumpAndSettle();

    // Only Basic Rock Beat matches
    expect(find.text('Basic Rock Beat'), findsOneWidget);
    expect(find.text('First Fill'), findsNothing);
    expect(find.text('Ghost Note Backbeat'), findsNothing);
    expect(find.text('Blues Shuffle'), findsNothing);
  });

  testWidgets('difficulty filter shows only matching lessons', (tester) async {
    await _pumpLibrary(tester, lessons: _testLessons);

    // Tap Intermediate filter chip
    await tester.tap(find.text('Intermediate').first);
    await tester.pumpAndSettle();

    // Only intermediate lesson visible
    expect(find.text('Ghost Note Backbeat'), findsOneWidget);
    expect(find.text('Basic Rock Beat'), findsNothing);
    expect(find.text('First Fill'), findsNothing);
    expect(find.text('Blues Shuffle'), findsNothing);
  });

  testWidgets('empty filter shows message and reset button', (tester) async {
    await _pumpLibrary(tester, lessons: _testLessons);

    // Search for something that doesn't match
    await tester.enterText(
      find.byKey(const ValueKey('library-search')),
      'zzzzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('No lessons match your filters.'), findsOneWidget);
    expect(find.text('Reset filters'), findsOneWidget);

    // Tap reset
    await tester.tap(find.byKey(const ValueKey('library-reset-filters')));
    await tester.pumpAndSettle();

    // All lessons back
    expect(find.text('Basic Rock Beat'), findsOneWidget);
    expect(find.text('First Fill'), findsOneWidget);
  });

  testWidgets('tap card shows lesson detail with Practice button', (
    tester,
  ) async {
    LessonSummary? practiceLesson;
    await _pumpLibrary(
      tester,
      lessons: _testLessons,
      onStartPractice: (l) => practiceLesson = l,
    );

    // Tap Basic Rock Beat card
    await tester.tap(find.text('Basic Rock Beat'));
    await tester.pumpAndSettle();

    // Detail view visible
    expect(find.byKey(const ValueKey('library-lesson-detail')), findsOneWidget);
    expect(find.text('Back to Library'), findsOneWidget);

    // Skills and objectives visible
    expect(find.text('Timing: Backbeat'), findsOneWidget);
    expect(
      find.text('Lock kick on 1 and 3 with snare on 2 and 4.'),
      findsOneWidget,
    );

    // Tags visible
    expect(find.text('rock'), findsOneWidget);
    expect(find.text('backbeat'), findsOneWidget);

    // Practice button
    expect(
      find.byKey(const ValueKey('library-detail-practice')),
      findsOneWidget,
    );

    // Tap Practice
    await tester.tap(find.byKey(const ValueKey('library-detail-practice')));
    await tester.pumpAndSettle();

    expect(practiceLesson?.id, 'beginner-1');
  });

  testWidgets('back from detail returns to lesson list', (tester) async {
    await _pumpLibrary(tester, lessons: _testLessons);

    // Open detail
    await tester.tap(find.text('Basic Rock Beat'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('library-lesson-detail')), findsOneWidget);

    // Tap back
    await tester.tap(find.byKey(const ValueKey('library-detail-back')));
    await tester.pumpAndSettle();

    // Back to list
    expect(
      find.byKey(const ValueKey('library-lesson-list')),
      findsOneWidget,
    );
    expect(find.text('Basic Rock Beat'), findsOneWidget);
  });
}

Future<void> _pumpLibrary(
  WidgetTester tester, {
  required List<LessonSummary> lessons,
  void Function(LessonSummary)? onStartPractice,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: LibraryScreen(
            lessons: lessons,
            onStartPractice: onStartPractice ?? (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
