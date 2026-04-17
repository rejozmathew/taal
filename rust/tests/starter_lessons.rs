use std::collections::HashSet;

use taal_core::content::{compile_lesson, load_layout, load_lesson, load_scoring_profile};

const STANDARD_LAYOUT: &str = include_str!("../../assets/content/layouts/std-5pc-v1.json");
const STANDARD_SCORING: &str = include_str!("../../assets/content/scoring/score-standard-v1.json");

struct StarterLessonFixture {
    slug: &'static str,
    json: &'static str,
}

const STARTER_LESSONS: &[StarterLessonFixture] = &[
    StarterLessonFixture {
        slug: "beginner-basic-rock",
        json: include_str!("../../assets/content/lessons/starter/beginner-basic-rock.json"),
    },
    StarterLessonFixture {
        slug: "beginner-four-on-floor",
        json: include_str!("../../assets/content/lessons/starter/beginner-four-on-floor.json"),
    },
    StarterLessonFixture {
        slug: "beginner-kick-snare-space",
        json: include_str!("../../assets/content/lessons/starter/beginner-kick-snare-space.json"),
    },
    StarterLessonFixture {
        slug: "beginner-first-fill",
        json: include_str!("../../assets/content/lessons/starter/beginner-first-fill.json"),
    },
    StarterLessonFixture {
        slug: "beginner-open-hihat",
        json: include_str!("../../assets/content/lessons/starter/beginner-open-hihat.json"),
    },
    StarterLessonFixture {
        slug: "intermediate-sixteenth-hats",
        json: include_str!("../../assets/content/lessons/starter/intermediate-sixteenth-hats.json"),
    },
    StarterLessonFixture {
        slug: "intermediate-syncopated-kick",
        json: include_str!(
            "../../assets/content/lessons/starter/intermediate-syncopated-kick.json"
        ),
    },
    StarterLessonFixture {
        slug: "intermediate-ghost-note-backbeat",
        json: include_str!(
            "../../assets/content/lessons/starter/intermediate-ghost-note-backbeat.json"
        ),
    },
    StarterLessonFixture {
        slug: "intermediate-tom-groove",
        json: include_str!("../../assets/content/lessons/starter/intermediate-tom-groove.json"),
    },
    StarterLessonFixture {
        slug: "intermediate-fill-resolution",
        json: include_str!(
            "../../assets/content/lessons/starter/intermediate-fill-resolution.json"
        ),
    },
    StarterLessonFixture {
        slug: "variety-blues-shuffle",
        json: include_str!("../../assets/content/lessons/starter/variety-blues-shuffle.json"),
    },
    StarterLessonFixture {
        slug: "variety-funk-groove",
        json: include_str!("../../assets/content/lessons/starter/variety-funk-groove.json"),
    },
    StarterLessonFixture {
        slug: "variety-half-time-rock",
        json: include_str!("../../assets/content/lessons/starter/variety-half-time-rock.json"),
    },
];

#[test]
fn all_starter_lessons_load_and_compile() {
    let layout = load_layout(STANDARD_LAYOUT).expect("standard layout should load");
    let scoring = load_scoring_profile(STANDARD_SCORING).expect("standard scoring should load");
    let layout_lane_ids = layout
        .lanes
        .iter()
        .map(|lane| lane.lane_id.as_str())
        .collect::<HashSet<_>>();

    for fixture in STARTER_LESSONS {
        let lesson = load_lesson(fixture.json)
            .unwrap_or_else(|err| panic!("{} failed: {err}", fixture.slug));
        assert_eq!(
            lesson.instrument.layout_id, "std-5pc-v1",
            "{}",
            fixture.slug
        );
        assert_eq!(
            lesson.scoring_profile_id.as_deref(),
            Some("score-standard-v1"),
            "{}",
            fixture.slug
        );
        assert!(
            !lesson.metadata.skills.is_empty(),
            "{} should include learning outcomes",
            fixture.slug
        );
        for lane in &lesson.lanes {
            assert!(
                layout_lane_ids.contains(lane.lane_id.as_str()),
                "{} references unknown lane {}",
                fixture.slug,
                lane.lane_id
            );
        }

        let compiled = compile_lesson(&lesson, &layout, &scoring)
            .unwrap_or_else(|err| panic!("{} failed compile: {err}", fixture.slug));
        assert!(
            !compiled.events.is_empty(),
            "{} should compile events",
            fixture.slug
        );
        assert!(
            compiled.total_duration_ms > 0,
            "{} should have positive duration",
            fixture.slug
        );
    }
}

#[test]
fn starter_lesson_set_has_required_progression_mix() {
    let mut beginner_count = 0;
    let mut intermediate_count = 0;
    let mut variety_count = 0;
    let mut ids = HashSet::new();

    for fixture in STARTER_LESSONS {
        let lesson = load_lesson(fixture.json).expect("starter lesson should load");
        assert!(
            ids.insert(lesson.id),
            "duplicate lesson id in {}",
            fixture.slug
        );
        match lesson.metadata.difficulty.as_deref() {
            Some("beginner") => beginner_count += 1,
            Some("intermediate") => intermediate_count += 1,
            other => panic!("{} has unexpected difficulty {other:?}", fixture.slug),
        }
        if fixture.slug.starts_with("variety-") {
            variety_count += 1;
        }
    }

    assert_eq!(STARTER_LESSONS.len(), 13);
    assert_eq!(beginner_count, 5);
    assert_eq!(intermediate_count, 8);
    assert_eq!(variety_count, 3);
}
