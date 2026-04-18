import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taal/features/onboarding/onboarding_flow.dart';
import 'package:taal/features/player/practice_runtime/practice_runtime.dart';
import 'package:taal/features/player/tap_pads/tap_pad_surface.dart';
import 'package:taal/platform/midi/midi_adapter.dart';
import 'package:taal/src/rust/api/profiles.dart' as rust_profiles;

void main() {
  test('starter lesson follows selected experience level', () {
    expect(
      starterLessonForExperience(
        rust_profiles.ProfileExperienceLevelDto.beginner,
      ).title,
      'Basic Rock Beat',
    );
    expect(
      starterLessonForExperience(
        rust_profiles.ProfileExperienceLevelDto.intermediate,
      ).title,
      'Syncopated Kick Push',
    );
    expect(
      starterLessonForExperience(
        rust_profiles.ProfileExperienceLevelDto.teacher,
      ).title,
      'Pocket Funk Groove',
    );
  });

  testWidgets('no MIDI user reaches demo lesson with tap pads', (tester) async {
    rust_profiles.LocalProfileStateDto? completedState;
    final createdProfiles = <rust_profiles.PlayerProfileDto>[];
    final engine = _FakePracticeRuntimeEngine();

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          midiAdapter: _FakeMidiAdapter(devices: []),
          runtimeEngine: engine,
          contentLoader: _fakeContentLoader,
          onCreateProfile:
              ({required name, required avatar, required experienceLevel}) {
                final profile = rust_profiles.PlayerProfileDto(
                  id: 'player-1',
                  name: name,
                  avatar: avatar,
                  experienceLevel: experienceLevel,
                  preferredView:
                      rust_profiles.ProfilePracticeViewDto.noteHighway,
                  createdAt: '2026-04-18T10:00:00Z',
                  updatedAt: '2026-04-18T10:00:00Z',
                );
                createdProfiles.add(profile);
                return rust_profiles.LocalProfileStateDto(
                  profiles: [profile],
                  activeProfileId: profile.id,
                );
              },
          onComplete: (state) {
            completedState = state;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-get-started')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('onboarding-profile-name')),
      'Ada',
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-profile-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Playing regularly'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-experience-next')));
    await tester.pumpAndSettle();

    expect(createdProfiles.single.name, 'Ada');
    expect(
      createdProfiles.single.experienceLevel,
      rust_profiles.ProfileExperienceLevelDto.intermediate,
    );
    expect(
      find.text('No MIDI device found. Demo mode with tap pads is ready.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-use-tap-pads')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-calibration-next')));
    await tester.pumpAndSettle();

    expect(find.text('Syncopated Kick Push'), findsOneWidget);
    expect(find.text('Demo mode with tap pads is on.'), findsOneWidget);
    expect(find.byType(TapPadSurface), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('tap-pad-kick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tap-pad-kick')));
    await tester.pump();
    expect(engine.touchHits.single.laneId, 'kick');
    expect(find.text('Last pad: kick'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('onboarding-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-finish')));

    expect(completedState?.activeProfileId, 'player-1');
  });

  testWidgets('MIDI device path still offers skip-to-demo controls', (
    tester,
  ) async {
    final midi = _FakeMidiAdapter(
      devices: const [
        MidiInputDevice(id: 7, name: 'Roland TD-27', productName: 'TD-27'),
      ],
    );
    final engine = _FakePracticeRuntimeEngine();

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingFlow(
          midiAdapter: midi,
          runtimeEngine: engine,
          contentLoader: _fakeContentLoader,
          onCreateProfile:
              ({required name, required avatar, required experienceLevel}) {
                final profile = rust_profiles.PlayerProfileDto(
                  id: 'player-1',
                  name: name,
                  avatar: avatar,
                  experienceLevel: experienceLevel,
                  preferredView:
                      rust_profiles.ProfilePracticeViewDto.noteHighway,
                  createdAt: '2026-04-18T10:00:00Z',
                  updatedAt: '2026-04-18T10:00:00Z',
                );
                return rust_profiles.LocalProfileStateDto(
                  profiles: [profile],
                  activeProfileId: profile.id,
                );
              },
          onComplete: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('onboarding-get-started')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-profile-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-experience-next')));
    await tester.pumpAndSettle();

    expect(find.text('1 MIDI device found.'), findsOneWidget);
    expect(find.text('Roland TD-27'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-use-selected-kit')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding-use-tap-pads')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-use-selected-kit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('onboarding-calibration-next')));
    await tester.pumpAndSettle();

    expect(midi.openedDeviceId, 7);
    expect(find.text('Listening to Roland TD-27.'), findsOneWidget);

    midi.emit(
      const MidiNoteOnEvent(
        deviceId: 7,
        channel: 9,
        note: 38,
        velocity: 100,
        timestampNs: 505000010,
      ),
    );
    await tester.pump();

    expect(engine.midiNotes.single.note, 38);
  });
}

Future<OnboardingLessonContent> _fakeContentLoader(
  OnboardingStarterLesson lesson,
) async {
  return const OnboardingLessonContent(
    lessonJson: '{}',
    layoutJson: '{}',
    scoringProfileJson: '{}',
  );
}

class _FakeMidiAdapter implements Phase0MidiAdapter {
  _FakeMidiAdapter({required this.devices});

  final List<MidiInputDevice> devices;
  final _events = StreamController<MidiNoteOnEvent>.broadcast();
  int? openedDeviceId;
  var closeCount = 0;

  @override
  String get platformName => 'test';

  @override
  Stream<MidiNoteOnEvent> get noteOnEvents => _events.stream;

  @override
  Future<List<MidiInputDevice>> listDevices() async => devices;

  @override
  Future<void> openDevice(int deviceId) async {
    openedDeviceId = deviceId;
  }

  @override
  Future<void> closeDevice() async {
    closeCount += 1;
  }

  void emit(MidiNoteOnEvent event) {
    _events.add(event);
  }
}

class _FakePracticeRuntimeEngine implements PracticeRuntimeEngine {
  final touchHits = <_TouchSubmission>[];
  final midiNotes = <_MidiNoteSubmission>[];
  var disposeCount = 0;

  @override
  int clockNs() => 10;

  @override
  PracticeRuntimeStart startSession({
    required String lessonJson,
    required String layoutJson,
    required String scoringProfileJson,
    required String? deviceProfileJson,
    required PracticeRuntimeMode mode,
    required double bpm,
    required int startTimeNs,
    required int lookaheadMs,
  }) {
    return PracticeRuntimeStart(sessionId: 7, timeline: _timeline);
  }

  @override
  List<PracticeRuntimeEvent> submitTouchHit({
    required int sessionId,
    required String laneId,
    required int velocity,
    required int timestampNs,
  }) {
    touchHits.add(_TouchSubmission(laneId, velocity, timestampNs));
    return [
      PracticeRuntimeEvent(
        type: PracticeRuntimeEventType.hitGraded,
        expectedId: '$laneId-1',
        laneId: laneId,
        grade: PracticeRuntimeGrade.perfect,
        deltaMs: 0,
        combo: touchHits.length,
        streak: touchHits.length,
        scoreRunning: 100,
      ),
    ];
  }

  @override
  List<PracticeRuntimeEvent> submitMidiNoteOn({
    required int sessionId,
    required int channel,
    required int note,
    required int velocity,
    required int timestampNs,
  }) {
    midiNotes.add(_MidiNoteSubmission(channel, note, velocity, timestampNs));
    return const [
      PracticeRuntimeEvent(
        type: PracticeRuntimeEventType.hitGraded,
        expectedId: 'snare-1',
        laneId: 'snare',
        grade: PracticeRuntimeGrade.good,
        deltaMs: 12,
        combo: 1,
        streak: 1,
        scoreRunning: 80,
      ),
    ];
  }

  @override
  List<PracticeRuntimeEvent> submitMidiControlChange({
    required int sessionId,
    required int channel,
    required int controller,
    required int value,
    required int timestampNs,
  }) {
    return const [];
  }

  @override
  List<PracticeRuntimeEvent> tick({
    required int sessionId,
    required int nowNs,
  }) {
    return const [];
  }

  @override
  List<PracticeRuntimeEvent> drainEvents(int sessionId) => const [];

  @override
  List<PracticeRuntimeEvent> pause(int sessionId) => const [];

  @override
  List<PracticeRuntimeEvent> resume(int sessionId) => const [];

  @override
  PracticeRuntimeStop stop(int sessionId) {
    return const PracticeRuntimeStop(summaryJson: '{}', events: []);
  }

  @override
  void disposeSession(int sessionId) {
    disposeCount += 1;
  }
}

class _TouchSubmission {
  const _TouchSubmission(this.laneId, this.velocity, this.timestampNs);

  final String laneId;
  final int velocity;
  final int timestampNs;
}

class _MidiNoteSubmission {
  const _MidiNoteSubmission(
    this.channel,
    this.note,
    this.velocity,
    this.timestampNs,
  );

  final int channel;
  final int note;
  final int velocity;
  final int timestampNs;
}

const _timeline = PracticeRuntimeTimeline(
  lessonId: '550e8400-e29b-41d4-a716-446655441007',
  mode: 'practice',
  bpm: 98,
  totalDurationMs: 4900,
  lanes: [
    PracticeRuntimeLane(laneId: 'kick', label: 'Kick', slotId: 'kick'),
    PracticeRuntimeLane(laneId: 'snare', label: 'Snare', slotId: 'snare'),
    PracticeRuntimeLane(laneId: 'hihat', label: 'Hi-Hat', slotId: 'hihat'),
  ],
  notes: [
    PracticeRuntimeNote(
      expectedId: 'kick-1',
      laneId: 'kick',
      tMs: 0,
      articulation: 'normal',
    ),
    PracticeRuntimeNote(
      expectedId: 'snare-1',
      laneId: 'snare',
      tMs: 612,
      articulation: 'normal',
    ),
    PracticeRuntimeNote(
      expectedId: 'hihat-1',
      laneId: 'hihat',
      tMs: 0,
      articulation: 'closed',
    ),
  ],
  sections: [
    PracticeRuntimeSection(
      sectionId: 'main',
      label: 'Main',
      startMs: 0,
      endMs: 4900,
      loopable: true,
    ),
  ],
);
