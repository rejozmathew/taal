import 'package:flutter/material.dart';
import 'package:taal/features/player/drum_kit/drum_kit.dart';
import 'package:taal/features/player/layout_compatibility/layout_compatibility.dart';
import 'package:taal/features/player/notation/notation_view.dart';
import 'package:taal/features/player/note_highway/note_highway.dart';
import 'package:taal/features/player/practice_mode/practice_mode_screen.dart';
import 'package:taal/features/player/review/post_lesson_review_screen.dart';
import 'package:taal/src/rust/api/practice_attempts.dart'
    as rust_practice_attempts;

enum PlayModeState { ready, countIn, running, awaitingSummary, completed }

class PlayModeAttemptRecordResult {
  const PlayModeAttemptRecordResult({this.attemptJson, this.error});

  final String? attemptJson;
  final String? error;

  bool get isSuccess => error == null;
}

abstract class PlayModeAttemptRecorder {
  PlayModeAttemptRecordResult recordAttempt({
    required String summaryJson,
    required String contextJson,
  });
}

class RustPlayModeAttemptRecorder implements PlayModeAttemptRecorder {
  const RustPlayModeAttemptRecorder({required this.databasePath});

  final String databasePath;

  @override
  PlayModeAttemptRecordResult recordAttempt({
    required String summaryJson,
    required String contextJson,
  }) {
    final result = rust_practice_attempts.recordPracticeAttempt(
      databasePath: databasePath,
      summaryJson: summaryJson,
      contextJson: contextJson,
    );
    return PlayModeAttemptRecordResult(
      attemptJson: result.attemptJson,
      error: result.error,
    );
  }
}

class PlayModePersistencePayload {
  const PlayModePersistencePayload({
    required this.summaryJson,
    required this.contextJson,
  });

  final String summaryJson;
  final String contextJson;
}

class PlayModeController extends ChangeNotifier {
  PlayModeController({
    required this.lessonTitle,
    required this.lessonBpm,
    required this.totalDurationMs,
    this.countInBeats = 4,
    this.attemptRecorder,
  }) : assert(lessonBpm > 0, 'lessonBpm must be positive'),
       assert(totalDurationMs > 0, 'totalDurationMs must be positive'),
       assert(countInBeats >= 0, 'countInBeats must not be negative'),
       _countInRemainingMs = countInBeats * 60000.0 / lessonBpm;

  final String lessonTitle;
  final double lessonBpm;
  final double totalDurationMs;
  final int countInBeats;
  final PlayModeAttemptRecorder? attemptRecorder;

  PlayModeState _state = PlayModeState.ready;
  PracticeDisplayView _displayView = PracticeDisplayView.noteHighway;
  double _currentTimeMs = 0;
  double _countInRemainingMs;
  PostLessonAttemptSummary? _reviewSummary;
  String? _storedAttemptJson;
  String? _persistenceError;

  PlayModeState get state => _state;

  PracticeDisplayView get displayView => _displayView;

  double get currentTimeMs => _currentTimeMs;

  double get countInRemainingMs => _countInRemainingMs;

  int get countInRemainingBeats {
    if (_state != PlayModeState.countIn) {
      return 0;
    }
    final beatMs = 60000.0 / lessonBpm;
    return (_countInRemainingMs / beatMs).ceil().clamp(1, countInBeats);
  }

  PostLessonAttemptSummary? get reviewSummary => _reviewSummary;

  String? get storedAttemptJson => _storedAttemptJson;

  String? get persistenceError => _persistenceError;

  bool get isRunning => _state == PlayModeState.running;

  bool get isComplete => _state == PlayModeState.completed;

  void start() {
    if (_state != PlayModeState.ready) {
      return;
    }
    _currentTimeMs = 0;
    _reviewSummary = null;
    _storedAttemptJson = null;
    _persistenceError = null;
    _countInRemainingMs = countInBeats * 60000.0 / lessonBpm;
    _state = countInBeats == 0 ? PlayModeState.running : PlayModeState.countIn;
    notifyListeners();
  }

  void selectView(PracticeDisplayView view) {
    if (_displayView == view) {
      return;
    }
    _displayView = view;
    notifyListeners();
  }

  void advanceBy(Duration elapsed) {
    if (elapsed.isNegative || elapsed == Duration.zero) {
      return;
    }

    switch (_state) {
      case PlayModeState.countIn:
        _advanceCountIn(elapsed);
      case PlayModeState.running:
        _advanceRun(elapsed);
      case PlayModeState.ready:
      case PlayModeState.awaitingSummary:
      case PlayModeState.completed:
        return;
    }
  }

  void completeRun(
    PostLessonAttemptSummary summary, {
    PlayModePersistencePayload? persistencePayload,
  }) {
    if (_state != PlayModeState.running &&
        _state != PlayModeState.awaitingSummary) {
      return;
    }

    _currentTimeMs = totalDurationMs;
    _reviewSummary = summary;
    _state = PlayModeState.completed;
    final recorder = attemptRecorder;
    if (recorder != null && persistencePayload != null) {
      final result = recorder.recordAttempt(
        summaryJson: persistencePayload.summaryJson,
        contextJson: persistencePayload.contextJson,
      );
      _storedAttemptJson = result.attemptJson;
      _persistenceError = result.error;
    }
    notifyListeners();
  }

  void reset() {
    _state = PlayModeState.ready;
    _currentTimeMs = 0;
    _countInRemainingMs = countInBeats * 60000.0 / lessonBpm;
    _reviewSummary = null;
    _storedAttemptJson = null;
    _persistenceError = null;
    notifyListeners();
  }

  void _advanceCountIn(Duration elapsed) {
    _countInRemainingMs -= elapsed.inMicroseconds / 1000.0;
    if (_countInRemainingMs <= 0) {
      _countInRemainingMs = 0;
      _state = PlayModeState.running;
    }
    notifyListeners();
  }

  void _advanceRun(Duration elapsed) {
    _currentTimeMs = (_currentTimeMs + elapsed.inMicroseconds / 1000.0)
        .clamp(0, totalDurationMs)
        .toDouble();
    if (_currentTimeMs >= totalDurationMs) {
      _state = PlayModeState.awaitingSummary;
    }
    notifyListeners();
  }
}

class PlayModeScreen extends StatefulWidget {
  const PlayModeScreen({
    super.key,
    required this.controller,
    required this.lanes,
    required this.notes,
    this.feedback = const [],
    this.kitPads = standardFivePieceDrumKitPads,
    this.courseProgressLabel,
    this.onRetry,
    this.onNextLesson,
    this.onBackToLibrary,
    this.layoutCompatibility,
  });

  final PlayModeController controller;
  final List<NoteHighwayLane> lanes;
  final List<PracticeTimelineNote> notes;
  final List<PracticeFeedbackMarker> feedback;
  final List<VisualDrumKitPad> kitPads;
  final String? courseProgressLabel;
  final VoidCallback? onRetry;
  final VoidCallback? onNextLesson;
  final VoidCallback? onBackToLibrary;
  final LayoutCompatibilitySnapshot? layoutCompatibility;

  @override
  State<PlayModeScreen> createState() => _PlayModeScreenState();
}

class _PlayModeScreenState extends State<PlayModeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant PlayModeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.controller.reviewSummary;
    if (widget.controller.isComplete && summary != null) {
      return PostLessonReviewScreen(
        summary: summary,
        courseProgressLabel: widget.courseProgressLabel,
        layoutCompatibility: widget.layoutCompatibility,
        onRetry: widget.onRetry,
        onNextLesson: widget.onNextLesson,
        onBackToLibrary: widget.onBackToLibrary,
      );
    }

    return Column(
      children: [
        _PlayModeTopBar(
          controller: widget.controller,
          layoutCompatibility: widget.layoutCompatibility,
        ),
        if (widget.layoutCompatibility case final compatibility?
            when compatibility.hasExcludedLanes)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: LayoutCompatibilityBanner(
              compatibility: compatibility,
              mode: LayoutCompatibilityBannerMode.play,
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _PlayModeViewSurface(
                    controller: widget.controller,
                    lanes: widget.lanes,
                    notes: widget.notes,
                    feedback: widget.feedback,
                    kitPads: widget.kitPads,
                  ),
                ),
                if (widget.controller.state == PlayModeState.countIn)
                  _CountInOverlay(controller: widget.controller),
              ],
            ),
          ),
        ),
        _PlayModeProgressBar(controller: widget.controller),
      ],
    );
  }
}

class _PlayModeTopBar extends StatelessWidget {
  const _PlayModeTopBar({
    required this.controller,
    required this.layoutCompatibility,
  });

  final PlayModeController controller;
  final LayoutCompatibilitySnapshot? layoutCompatibility;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stateLabel = switch (controller.state) {
      PlayModeState.ready => 'Ready',
      PlayModeState.countIn => 'Count-in',
      PlayModeState.running => 'Scored run',
      PlayModeState.awaitingSummary => 'Finishing',
      PlayModeState.completed => 'Complete',
    };

    return Material(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton(
              onPressed: controller.state == PlayModeState.ready
                  ? controller.start
                  : null,
              child: const Text('Start Play Mode'),
            ),
            Text(
              '${controller.lessonBpm.round()} BPM',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Chip(label: Text(stateLabel)),
            SegmentedButton<PracticeDisplayView>(
              segments: const [
                ButtonSegment(
                  value: PracticeDisplayView.noteHighway,
                  label: Text('Highway'),
                ),
                ButtonSegment(
                  value: PracticeDisplayView.notation,
                  label: Text('Notation'),
                ),
                ButtonSegment(
                  value: PracticeDisplayView.drumKit,
                  label: Text('Kit'),
                ),
              ],
              selected: {controller.displayView},
              onSelectionChanged: (selection) =>
                  controller.selectView(selection.single),
            ),
            if (controller.persistenceError case final error?)
              Text(error, style: TextStyle(color: scheme.error)),
            if (layoutCompatibility case final compatibility?)
              LayoutCompatibilityIndicator(compatibility: compatibility),
          ],
        ),
      ),
    );
  }
}

class _PlayModeViewSurface extends StatelessWidget {
  const _PlayModeViewSurface({
    required this.controller,
    required this.lanes,
    required this.notes,
    required this.feedback,
    required this.kitPads,
  });

  final PlayModeController controller;
  final List<NoteHighwayLane> lanes;
  final List<PracticeTimelineNote> notes;
  final List<PracticeFeedbackMarker> feedback;
  final List<VisualDrumKitPad> kitPads;

  @override
  Widget build(BuildContext context) {
    switch (controller.displayView) {
      case PracticeDisplayView.noteHighway:
        return NoteHighwayWidget(
          lanes: lanes,
          notes: notes
              .map(
                (note) => NoteHighwayNote(
                  expectedId: note.expectedId,
                  laneId: note.laneId,
                  tMs: note.tMs,
                ),
              )
              .toList(growable: false),
          feedback: feedback
              .map(
                (marker) => NoteHighwayFeedback(
                  expectedId: marker.expectedId,
                  laneId: marker.laneId,
                  tMs: marker.tMs,
                  deltaMs: marker.deltaMs,
                  grade: marker.grade,
                ),
              )
              .toList(growable: false),
          currentTimeMs: controller.currentTimeMs,
        );
      case PracticeDisplayView.notation:
        return NotationViewWidget(
          notes: notes
              .map(
                (note) => NotationNote(
                  expectedId: note.expectedId,
                  laneId: note.laneId,
                  tMs: note.tMs,
                  articulation: note.articulation,
                ),
              )
              .toList(growable: false),
          feedback: feedback
              .map(
                (marker) => NotationFeedback(
                  expectedId: marker.expectedId,
                  laneId: marker.laneId,
                  tMs: marker.tMs,
                  deltaMs: marker.deltaMs,
                  grade: marker.grade,
                ),
              )
              .toList(growable: false),
          currentTimeMs: controller.currentTimeMs,
        );
      case PracticeDisplayView.drumKit:
        return VisualDrumKitWidget(pads: kitPads, hits: _activeKitHits());
    }
  }

  List<VisualDrumKitHit> _activeKitHits() {
    const flashWindowMs = 260.0;
    return feedback
        .where(
          (marker) =>
              (controller.currentTimeMs - marker.tMs).abs() <= flashWindowMs,
        )
        .map(
          (marker) => VisualDrumKitHit(
            laneId: marker.laneId,
            grade: marker.grade,
            progress:
                ((controller.currentTimeMs - marker.tMs).abs() / flashWindowMs)
                    .clamp(0.0, 1.0)
                    .toDouble(),
          ),
        )
        .toList(growable: false);
  }
}

class _CountInOverlay extends StatelessWidget {
  const _CountInOverlay({required this.controller});

  final PlayModeController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.92),
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Count-in', style: Theme.of(context).textTheme.titleMedium),
              Text(
                controller.countInRemainingBeats.toString(),
                key: const ValueKey('count-in-beats'),
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayModeProgressBar extends StatelessWidget {
  const _PlayModeProgressBar({required this.controller});

  final PlayModeController controller;

  @override
  Widget build(BuildContext context) {
    final progress = (controller.currentTimeMs / controller.totalDurationMs)
        .clamp(0.0, 1.0)
        .toDouble();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Text(
              '${(controller.currentTimeMs / 1000).toStringAsFixed(1)}s of ${(controller.totalDurationMs / 1000).toStringAsFixed(1)}s',
            ),
          ],
        ),
      ),
    );
  }
}
