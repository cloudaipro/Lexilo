# Lexilo

Lexilo is a focused, local-first iOS vocabulary trainer. It creates two independently scheduled cards for every vocabulary item—recognition and active recall—and never serves the pair on the same calendar day.

## Open and run

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
- Deterministic fixed-interval scheduler and paired-card same-day exclusion
- Atomic offline JSON persistence and immutable review history
- Searchable starter vocabulary, context examples, IPA, and device pronunciation
- Small WidgetKit widget target
- Unit tests for the interval model and paired-card session constraint
- XCUITest coverage for Today → practice → reveal → Don’t Know → recycled queue → completion
- App icon generated from the supplied `logo.png`

The starter lexicon is deliberately small demonstration content. Production content must enter through the `LexicalContentProvider` boundary with explicit provenance and redistribution rights; see `CONTENT_SOURCES.md`.

## Validation

Validated on **iPhone 17 Pro, iOS 26.2 Simulator**:

- Full simulator build: passed
- Practice-flow XCUITest: passed
- ReviewScheduler unit tests: 3 passed
- Visual checks: Today, recognition front, revealed answer, failure recycling, and completion

Test screenshots are in `screenshots/final-ui-flow/`.
