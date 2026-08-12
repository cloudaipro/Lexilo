# Lexilo

Lexilo is a focused, local-first iOS vocabulary trainer. It creates two independently scheduled cards for every vocabulary item—recognition and active recall—and never serves the pair on the same calendar day.

Read the [User Guide & Design Philosophy](USER_GUIDE_AND_DESIGN_PHILOSOPHY.md) for the learner workflow, scheduling behavior, and product principles.

## Open and run

The sherpa-onnx and ONNX Runtime XCFrameworks are intentionally excluded from Git. Install the pinned local runtime after cloning:

```sh
scripts/install_sherpa_runtime.sh
```

1. Open `Lexilo.xcodeproj` in Xcode 26 or newer.
2. Choose the `Lexilo` scheme.
3. Select **iPhone 17 Pro** as the run destination.
4. Build and run with `⌘R`.

The project is generated from `project.yml` using XcodeGen. Regenerate after changing target structure with:

```sh
xcodegen generate
```

## Included

- SwiftUI app with Today, Words, Progress, and Settings tabs
- Two-direction daily practice flow with reveal and Know/Don’t Know decisions
- Deterministic 1/2/3-day linear scheduler (capped at 180 days) and paired-card same-day exclusion
- Atomic offline JSON persistence with last-known-good recovery and immutable review history
- Bundled, searchable Open English WordNet SQLite lexicon with 135,282 lexemes and 17,725 learning candidates
- Deterministic offline vocabulary rotation by learning band, with learner progress stored separately from dictionary content
- Kitten Nano v0.2 neural pronunciation through sherpa-onnx, launch prewarming, and a bounded on-device audio cache
- Small WidgetKit widget target backed by an App Group study snapshot
- Daily new-word cap, explicit StudyDay streak records, and migration-safe persistence
- Unit tests for intervals, failure reset, new-word limits, streaks, and paired-card constraints
- XCUITest coverage for Today → practice → reveal → Don’t Know → recycled queue → completion
- App icon generated from the supplied `logo.png`

All vocabulary comes from the versioned Open English WordNet database in `Lexilo/Resources/lexilo-lexicon.sqlite`; pronunciation uses the model in `Lexilo/Resources/Kitten/KittenVoice.bundle`. See `CONTENT_SOURCES.md` and `TTS_RESEARCH.md`.

## Validation

Validated on **iPhone 17 Pro, iOS 26.2 Simulator**:

- Full simulator build: passed
- Practice-flow XCUITest: passed
- OEWN-only seeding, exact-band rotation, unavailable-state, sense repair, persistence recovery, scheduler, cache, greeting, and real Kitten inference tests: 21 passed
- Unsigned arm64 iPhone build: passed
- Visual checks: Today, recognition front, revealed answer, failure recycling, and completion

Test screenshots are in `screenshots/final-ui-flow/`.
