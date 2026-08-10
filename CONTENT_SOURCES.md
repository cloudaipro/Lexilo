# Lexilo content-source policy

Checked: 2026-08-09

## Decisions

- Vocabulary.com is a product-behaviour reference and may be linked to, but Lexilo must not scrape or bundle its definitions, examples, contexts, or audio without written permission. Its current terms expressly prohibit automated extraction and systematic retrieval to create another database.
- The `anki-english-60k-decks` repository is useful for studying field shape, frequency grouping, atomic senses, and APKG import. Its own material is CC0, but its Merriam-Webster definitions, examples, and audio are explicitly excluded from that grant. Wiktionary-derived text is CC BY-SA 4.0, and every audio file has its own license.
- Anki’s source is a scheduling and architecture reference, not copied application code. Any future reuse of its AGPL-licensed implementation requires a separate compliance decision.

## V1 implementation

- `LexicalContentProvider` is the boundary for bundled or server-provided lexicons.
- The included starter lexicon is an original demonstration dataset, labelled `lexilo-starter` per record.
- Pronunciation uses Apple’s on-device `AVSpeechSynthesizer` by default.
- A production ingestion pipeline should use a versioned JSON schema with source URL, source revision, text license, audio license, attribution, and change notes on every sense.

## Recommended production sources

- Wiktionary structured extracts through Kaikki.org for definitions and IPA, with CC BY-SA 4.0 attribution and ShareAlike compliance.
- Wikimedia Commons pronunciation recordings only after preserving each file’s individual license and attribution.
- A commercial dictionary API only under a contract that explicitly permits caching, offline distribution, and end-user display.

## Import roadmap

1. JSON lexicon import with validation and provenance fields.
2. APKG reader for user-owned decks; map one note/sense to one vocabulary item and generate the two Lexilo scheduling cards.
3. Licensed audio cache keyed by source ID and locale, falling back to device speech.

