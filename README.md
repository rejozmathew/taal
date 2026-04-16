# Taal (താള്‍)

**Free, open-source instrument tutoring with real-time MIDI feedback.**

Connect your electronic drum kit via USB MIDI, play along with lessons, and get instant visual feedback on every hit — perfect, early, late, or miss. Create your own lessons, build courses, and share them as portable packs.

**Taal is free.** No subscription. No paywall. No limited daily practice time.

---

## Features

### Practice Player
Play along with drum lessons in two views: a note-highway (Guitar Hero-style) or traditional drum notation. Every hit gets instant timing feedback. Adjustable tempo, section looping, and scored assessment modes. Metronome with low-latency audio. On-screen tap pads for practice without a kit.

### Creator Studio
Author drum lessons on a multi-lane timeline editor. Set tempo, sections, and difficulty. Mark lanes as required or optional for different kit sizes. Build guided courses with progression gates. Export and share as portable `.taalpack` files.

### Progress Tracking
Daily practice streaks, timing trend analysis, and lane-specific accuracy heatmaps. Performance theme detection identifies your weak spots and recommends lessons to address them.

### Backing Tracks
Load your own audio files, sync them to lessons with beatmap authoring, and practice with a full band mix.

---

## Supported Hardware

### Electronic Drum Kits (USB MIDI)
Works with any e-kit that outputs standard MIDI over USB. Preset profiles for:
- Roland TD series (TD-07, TD-17, TD-27)
- Yamaha DTX series
- Alesis Nitro, Surge, Strike
- Any General MIDI compatible kit

Extra pads (triggers, splashes, cowbells) are supported through the extensible layout system.

### Platforms
- **Windows 10+** (primary)
- **Android 10+ tablets** (primary)
- macOS, iPadOS (planned)

---

## Install

**Taal is in active development. No release builds are available yet.** The first public release is planned at the end of Phase 3.

Once available:
- **Windows:** `.exe` installer via GitHub Releases
- **Android:** Google Play Store + sideload APK from Releases

### First Launch (when released)
1. Connect your e-kit via USB
2. Taal detects your kit automatically
3. Quick calibration (30 seconds)
4. Play your first lesson

To build from source or follow progress, see [STATUS.md](STATUS.md).

---

## Architecture

Taal is built on three layers: Flutter for cross-platform UI, Rust for deterministic timing/scoring, and thin native adapters for MIDI and audio I/O.

For the full technical overview, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture — components, data flows, boundaries |
| [docs/prd.md](docs/prd.md) | Product requirements — what we're building and why |
| [docs/specs/](docs/specs/) | Technical contracts — data models, APIs, behavioral rules |
| [docs/adr/](docs/adr/) | Architecture decisions — why we chose X over Y |
| [plans/](plans/) | Phase plans — what we're building in what order |
| [STATUS.md](STATUS.md) | Current project state |
| [CHANGELOG.md](CHANGELOG.md) | Change history |

---

## Contributing

Contributions welcome:

- **Content:** Create and share drum lessons and courses
- **Code:** See [ARCHITECTURE.md](ARCHITECTURE.md) for the codebase overview and [AGENTS.md](AGENTS.md) for execution discipline
- **Bug reports:** Open an issue with steps to reproduce
- **Feature requests:** Open an issue describing the use case

---

## License

[Apache 2.0](LICENSE)
