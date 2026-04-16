# Bootstrap Guide

This document explains the initial repo state and how to begin development.

## What This Repo Contains

This is a **documentation-first** bootstrap. No application code exists yet. The repo contains:

- Complete PRD (v1.9) with product scope, architecture, and phased delivery plan
- 5 companion specs (content schemas, engine API, MIDI mapping, analytics model, visual language)
- 1 accepted ADR (platform architecture — pending Phase 0 spike validation)
- 4 phase plans with 77 tasks, dependencies, and acceptance criteria
- Agent execution contract (AGENTS.md)
- Project state tracker (STATUS.md)

## Repository Structure (Target)

```
taal/
├── AGENTS.md                # Canonical agent execution contract
├── CLAUDE.md                # Thin shim → AGENTS.md
├── README.md                # Public-facing project description
├── README_BOOTSTRAP.md      # This file (remove when no longer useful for new contributors)
├── ARCHITECTURE.md           # Living system architecture (updated during coding)
├── STATUS.md                # Current project state
├── CHANGELOG.md             # Change log
├── .gitignore
│
├── docs/
│   ├── prd.md               # Product Requirements Document
│   ├── coding-model.md      # Task templates and governance rules
│   ├── adr/                 # Architecture Decision Records
│   │   └── 001-platform-architecture.md
│   ├── specs/               # Technical specifications (contracts)
│   │   ├── content-schemas.md
│   │   ├── engine-api.md
│   │   ├── midi-mapping.md
│   │   ├── analytics-model.md
│   │   └── visual-language.md
│   └── change_requests/     # CRs when docs need amendment
│
├── plans/                   # Phase execution plans
│   ├── phase-0.md
│   ├── phase-1.md
│   ├── phase-2.md
│   └── phase-3.md
│
├── lib/                     # Flutter UI (Dart) — created in Phase 0
│   ├── features/            # Player, Studio, Library, Insights, Settings, Onboarding
│   ├── widgets/             # Shared widgets
│   └── design/              # Design system tokens
│
├── rust/                    # Rust core engine — created in Phase 0
│   └── src/
│       ├── content/         # Parse, validate, compile
│       ├── runtime/         # Session, grading, scoring
│       ├── time/            # Musical ↔ ms conversion
│       ├── analytics/       # Aggregation, themes
│       ├── midi/            # Mapping, device profiles
│       └── storage/         # SQLite persistence
│
├── native/                  # Platform-specific MIDI/audio adapters
│   ├── android/
│   └── windows/
│
└── assets/                  # Bundled content + sounds
```

The `lib/`, `rust/`, `native/`, and `assets/` directories are created during Phase 0 (P0-01 Monorepo Scaffold).

## How to Start

### Prerequisites
- Flutter SDK (stable channel)
- Rust toolchain (stable)
- `flutter_rust_bridge` CLI
- Android SDK (for Android builds)
- Visual Studio Build Tools (for Windows builds)

### First Phase
1. Read `AGENTS.md`
2. Read `STATUS.md` — confirms Phase 0 is the active phase
3. Read `plans/phase-0.md` — 9 tasks, starting with P0-01 monorepo scaffold
4. Execute Phase 0 in dependency order

### Phase 0 Exit Gate
Phase 0 ends with ADR-001 finalization. If latency measurements pass (< 25ms on Windows + Android), the Flutter + Rust architecture is confirmed and Phase 1 begins.

## Historical Reference

The earlier Rust-only prototype was archived as `taal-legacy`. It may contain reusable ideas for MusicXML import (Phase 2), transcription experiments (Phase 5+), and UI sketches, but it is **not** the architectural baseline for this repo.
