# Changelog

## 0.9.1 — 2026-08-16

- Added automatic learner-oriented sense ranking at lexicon build time.
- Kept Kaikki as the canonical user-facing sense inventory while using optional
  Simple English Wiktionary and Open English WordNet alignment as ranking
  evidence only.
- Added deterministic `learner_rank`, confidence, reason, and model metadata to
  the bundled SQLite Learning Core.
- Removed the old example-presence ranking bias and all per-word manual ranking
  or content-replacement paths.
- Restored the development-only Dictionary section in the Words tab; it remains
  gated by `#if DEBUG` and does not add words to study automatically.
- Added Harbor ranking regression coverage and refreshed the bundled database.

## 0.9

- Initial offline Learning Core release.
