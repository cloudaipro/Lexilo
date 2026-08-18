# Changelog

## Unreleased — 2026-08-17

- Updated the learner workflow so Today opens directly on the daily word-study pager. The top-right Quiz action tests only the current daily set, and Learn More adds the next batch of five words after the final card.
- Added the current History behavior to the product surface: calendar selection, one combined studied-word list, and Relearn these words.
- Removed the old Next Round and Practice these words flows, the Words/History Study this word controls, and the onboarding first-language-support switch.
- Made Apple TTS the default pronunciation engine while retaining Kitten as an optional offline engine.
- Updated the Home Screen widget contract: it advances through today’s word set in order and wraps back to the first word.
- Updated Widget deep links so tapping a widget opens Today’s words directly; Quiz now starts only from the Today screen.
- Refreshed documentation and validation references for the Simple English Wiktionary Learning Core and current UI behavior.

## 0.9.1 — 2026-08-16

- Added automatic learner-oriented sense ranking at lexicon build time.
- Switched the canonical user-facing inventory to the official Simple English
  Wiktionary Wikimedia dump and removed the English Wiktionary/Kaikki extract
  from the build.
- Added deterministic `learner_rank`, confidence, reason, and model metadata to
  the bundled SQLite Learning Core.
- Removed the old example-presence ranking bias and all per-word manual ranking
  or content-replacement paths.
- Restored the development-only Dictionary section in the Words tab; it remains
  gated by `#if DEBUG` and does not add words to study automatically.
- Added Harbor ranking regression coverage and refreshed the bundled database.

## 0.9

- Initial offline Learning Core release.
