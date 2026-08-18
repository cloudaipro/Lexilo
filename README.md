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

- SwiftUI app with focused Today, Words, History, and Settings tabs
- Learning-first Today flow: study the daily word set, then use Quiz for recognition and active recall
- Learn More adds the next batch of words to today; the default batch is five
- Compact adaptive scheduler using difficulty, stability, retrievability, response time, and hints (capped at 3,650 days), with paired-card same-day exclusion
- Atomic offline JSON persistence with last-known-good recovery and immutable review history
- Bundled Simple English Wiktionary Learning Core with 5,591 learning terms, verified usage examples, CMUdict pronunciation fallback, and eSpeak NG coverage
- Deterministic offline vocabulary rotation by learning band, with learner progress stored separately from dictionary content
- Apple TTS is the default offline pronunciation engine; Kitten Nano v0.2 is an optional neural voice through sherpa-onnx, with a bounded on-device audio cache and fallback handling
- Small and medium WidgetKit widgets backed by an App Group study snapshot; each refresh advances through today’s words in order and wraps around, while the medium widget shows the full definition or example selected in Settings (Definition by default)
- Calendar-based History shows one combined list of words studied on a selected day and can start a relearning session
- Daily new-word cap, explicit StudyDay streak records, and migration-safe persistence
- Unit tests for adaptive intervals, content migration, example quality, pronunciation fallbacks, persistence, new-word limits, streaks, and paired-card constraints
- XCUITest coverage for the daily practice flow and simplified word-detail hierarchy
- App icon generated from the supplied `logo.png`

All user-facing lexical content comes from the pinned Simple English Wiktionary dump in `Lexilo/Resources/lexilo-lexicon.sqlite`. The bundled Learning Core contains 11,731 retained senses and 13,264 validated usage examples; definitions, collocations, and fragments are never substituted for a missing example. Simple English Wiktionary source order is preserved, with optional OEWN alignment available as build-time ranking evidence only. CMUdict fills IPA gaps only, eSpeak NG supplies explicitly marked generated IPA where needed, and spoken pronunciation defaults to Apple TTS; the optional Kitten engine uses the model in `Lexilo/Resources/Kitten/KittenVoice.bundle`. There is no FTS5 index. See `CONTENT_SOURCES.md` and `TTS_RESEARCH.md`.

## Validation

Validated on **iPhone 17 Pro, iOS 26.2 Simulator**:

- Full simulator build: passed
- Practice-flow XCUITest: 4 tests passed
- ReviewSchedulerTests: 43/43 passed, including source-aware seeding, exact-band rotation, daily expansion, History/Words persistence, widget snapshots, example-quality regression, persistence recovery, adaptive scheduling, pronunciation fallback, cache, and real Kitten inference
- Unsigned arm64 iPhone build: passed
- Visual checks: Today, recognition front, revealed answer, failure recycling, and completion

Test screenshots are in `screenshots/final-ui-flow/`.
