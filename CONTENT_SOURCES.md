# Lexilo content-source policy

Checked: 2026-08-15

## Decisions

- Kaikki's structured English Wiktionary extract is Lexilo's sole lexical source. No Open English WordNet content is bundled or merged.
- CMUdict is a pronunciation fallback only. It cannot introduce a term, sense, definition, or example.
- Vocabulary.com and commercial dictionaries may be product-behaviour references, but Lexilo does not scrape or redistribute their protected content.

## Offline implementation

- `scripts/build_lexicon.py` reproducibly builds the bundled SQLite Learning Core from the pinned Kaikki 2026-08-12 JSONL extract, pinned CMUdict data, eSpeak NG 1.52.0, and wordfreq 3.1.1. The current bundled metadata version is `2026-08-12-quality-v3`.
- The app opens the database read-only. Learning selection, exact lookup, prefix lookup, inflected-form resolution, and rotation make no network requests.
- There is no full-text index. Lexilo uses ordinary SQLite B-tree indexes for the lookup patterns the app needs.
- A term enters the Learning Core because it passes frequency, modern-sense, and verified-usage quality gates—not because of an arbitrary vocabulary-count ceiling.
- Usage examples must contain the learning word (or a valid inflected form), contain at least four tokens, and read as a complete sentence ending in terminal punctuation. Phrase-like glosses, descriptions, and collocations are rejected; if no valid example remains, the field stays empty.
- Stable Wiktionary sense IDs allow lexical content to refresh without resetting cards, history, or mastery. Source changes can also migrate an existing item by its normalized term and part of speech.
- Kaikki IPA is preferred. CMUdict-derived IPA fills eligible single-word gaps, then eSpeak NG 1.52.0 generates explicitly marked fallback IPA for remaining words and phrases. Lexilo does not keep hand-written per-word pronunciation patches.
- Spoken pronunciation uses the bundled Kitten Nano v0.2 model through sherpa-onnx, with an installed iOS voice as a runtime failure fallback.
- Complete notices travel with the app in `Lexilo/Resources/LEXICON_NOTICES.md` and `Lexilo/Resources/NEURAL_VOICE_NOTICES.md`.

The current Learning Core contains 39,179 learning terms, 45,477 lexemes, 100,588 retained senses, 69,889 pronunciation rows, 115,201 validated examples, and 79,195 forms. Every selected source entry has at least one pronunciation after Kaikki, CMUdict, and generated eSpeak fallback processing.

## Packaging

- Lexilo v0.9 bundles only the Learning Core needed by the learning experience.
- A broader Full Dictionary is a future, optional download and is not exposed in the v0.9 Words tab.

## Rebuild

Install `scripts/requirements-lexicon.txt` and build or install the pinned eSpeak NG 1.52.0 executable, then run `scripts/build_lexicon.py --espeak /path/to/espeak-ng`. The script verifies pinned SHA-256 values and the G2P version, validates integrity and row counts, rejects FTS and WordNet source tables, records source versions, and compacts the result with `VACUUM`.
