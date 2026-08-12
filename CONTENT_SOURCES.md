# Lexilo content-source policy

Checked: 2026-08-11

## Decisions

- Vocabulary.com is a product-behaviour reference and may be linked to, but Lexilo must not scrape or bundle its definitions, examples, contexts, or audio without written permission. Its current terms expressly prohibit automated extraction and systematic retrieval to create another database.
- The `anki-english-60k-decks` repository is useful for studying field shape, frequency grouping, atomic senses, and APKG import. Its own material is CC0, but its Merriam-Webster definitions, examples, and audio are explicitly excluded from that grant. Wiktionary-derived text is CC BY-SA 4.0, and every audio file has its own license.
- Anki’s source is a scheduling and architecture reference, not copied application code. Any future reuse of its AGPL-licensed implementation requires a separate compliance decision.

## Offline implementation

- `scripts/build_lexicon.py` reproducibly builds the bundled SQLite database from the pinned Open English WordNet 2025 JSON release and wordfreq 3.1.1.
- The app opens the database read-only. Definitions, examples, search, candidate selection, and rotation do not make network requests.
- The database contains 135,282 lemma/part-of-speech lexemes. A curated 17,725-entry subset has an example and sufficient corpus frequency to enter rotation.
- Learning state stores stable WordNet sense IDs separately. Replacing the bundled database on an app update refreshes lexical content without resetting cards, history, or mastery.
- Open English WordNet is the sole vocabulary source. If its bundled database cannot open, the app shows an unavailable state rather than substituting fixed words.
- Every word is pronounced by the bundled Kitten Nano v0.2 model running through sherpa-onnx. The model is prewarmed at launch; synthesized featured and upcoming-practice words are cached locally. An installed iOS voice is retained only as a runtime failure fallback. Playback never downloads audio.
- Complete license notices travel with the database in `Lexilo/Resources/LEXICON_NOTICES.md` and with the neural voice pack in `Lexilo/Resources/NEURAL_VOICE_NOTICES.md`.

## Sources considered but not bundled

- Kaikki/Wiktionary provides substantially broader coverage, but its English extract is several gigabytes before app-specific indexing and carries CC BY-SA/GFDL obligations. It remains suitable for an optional build profile, not the compact default app.
- Forvo’s commercial API for online long-tail coverage only after accepting its commercial terms. Its API audio links expire after two hours and audio caching is prohibited, so it does not fit Lexilo’s offline cache.
- A commercial dictionary API only under a contract that explicitly permits caching, offline distribution, and end-user display.

## Rebuild

Install `scripts/requirements-lexicon.txt`, then run `scripts/build_lexicon.py`. The script verifies the pinned upstream SHA-256, validates the schema and row counts, records source versions in the metadata table, and compacts the result with `VACUUM`.
