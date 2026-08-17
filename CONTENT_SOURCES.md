# Lexilo content-source policy

Checked: 2026-08-16

## Decisions

- The official Simple English Wiktionary dump is Lexilo's canonical user-facing sense inventory. The dump is parsed locally into the bundled SQLite Learning Core; no English Wiktionary/Kaikki extract is used. Optional Open English WordNet input is used only as build-time ranking evidence and never contributes user-facing sense rows.
- CMUdict is a pronunciation fallback only. It cannot introduce a term, sense, definition, or example.
- Vocabulary.com and commercial dictionaries may be product-behaviour references, but Lexilo does not scrape or redistribute their protected content.

## Offline implementation

- `scripts/build_lexicon.py` reproducibly builds the bundled SQLite Learning Core from the pinned Simple English Wiktionary Wikimedia dump `simplewiktionary-20260801`, pinned CMUdict data, eSpeak NG 1.52.0, and wordfreq 3.1.1. The default source is `https://dumps.wikimedia.org/simplewiktionary/latest/`; optional `--oewn` input adds alignment evidence only. The rank model is recorded separately.
- The app opens the database read-only. Learning selection, exact lookup, prefix lookup, inflected-form resolution, and rotation make no network requests.
- There is no full-text index. Lexilo uses ordinary SQLite B-tree indexes for the lookup patterns the app needs.
- A term enters the Learning Core because it passes frequency, modern-sense, and verified-usage quality gates—not because of an arbitrary vocabulary-count ceiling.
- Usage examples must contain the learning word (or a valid inflected form), contain at least four tokens, and read as a complete sentence ending in terminal punctuation. Phrase-like glosses, descriptions, and collocations are rejected; if no valid example remains, the field stays empty.
- Stable deterministic Simple Wiktionary sense IDs allow lexical content to refresh without resetting cards, history, or mastery. Source changes can also migrate an existing item by its normalized term and part of speech.
- `sense_order` preserves upstream order. `learner_rank` is a separate deterministic build-time order, with confidence, reason, and model version recorded for QA. External alignment is ranking evidence only; Simple English Wiktionary remains the canonical user-facing sense inventory.
- Simple English Wiktionary IPA is preferred. CMUdict-derived IPA fills eligible single-word gaps, then eSpeak NG 1.52.0 generates explicitly marked fallback IPA for remaining words and phrases. Lexilo does not keep hand-written per-word pronunciation patches.
- Spoken pronunciation uses the bundled Kitten Nano v0.2 model through sherpa-onnx, with an installed iOS voice as a runtime failure fallback.
- Complete notices travel with the app in `Lexilo/Resources/LEXICON_NOTICES.md` and `Lexilo/Resources/NEURAL_VOICE_NOTICES.md`.

The current Learning Core contains 5,591 learning terms, 6,710 lexemes, 11,731 retained senses, 9,439 pronunciation rows, 13,264 validated examples, and 1,838 forms. Every selected source entry has at least one pronunciation after Simple English Wiktionary, CMUdict, and generated eSpeak fallback processing. The bundled rank metadata contains 11,731 compact feature rows; ranking evidence does not add external dictionary senses.

## Packaging

- Lexilo v0.9.1 bundles the Learning Core needed by the learning experience. Debug builds may expose a development-only Dictionary section backed by the same local data.
- A broader Full Dictionary is a future, optional download and is not exposed in the release Words tab.

## Rebuild

Install `scripts/requirements-lexicon.txt` and build or install the pinned eSpeak NG 1.52.0 executable, then run `scripts/build_lexicon.py --espeak /path/to/espeak-ng`. The script downloads the pinned Simple English Wiktionary dump from the Wikimedia dump index, verifies its SHA-256 and the G2P version, validates integrity and row counts, rejects FTS and external user-facing source entries, records source and rank versions, and compacts the result with `VACUUM`. Add `--oewn /path/to/oewn` only when a pinned secondary alignment source is available. `scripts/upgrade_lexicon_ranking.py` applies ranking metadata to an existing database when a full source rebuild is not locally available.
