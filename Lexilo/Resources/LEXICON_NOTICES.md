# Lexilo offline lexicon notices

## Kaikki / English Wiktionary

Lexilo's offline Learning Core is derived from the English Wiktionary extract
published by Kaikki.org and produced with Wiktextract. Lexilo reformats and
filters the extract into SQLite for offline learning. Kaikki remains the
canonical user-facing sense inventory.

The bundled build is `2026-08-12-quality-v3` with rank model
`learner-sense-ranker-v1`. It contains 39,179 learning terms and 115,202
validated usage examples. Example records must contain the
learning word or a valid inflected form and read as complete sentences;
definitions, descriptions, collocations, and bare phrases are not relabeled as
examples.

Kaikki: https://kaikki.org/dictionary/English/
English Wiktionary: https://en.wiktionary.org/
Wiktextract: https://github.com/tatuylonen/wiktextract

## Learner-oriented ranking evidence

Lexilo stores a separate deterministic `learner_rank` for each sense. The
upstream `sense_order` is preserved for provenance. When supplied to the build,
Simple English Wiktionary and Open English WordNet contribute alignment
evidence and ranking features only; their definitions and sense rows are not
merged into the user-facing dictionary inventory.

Simple English Wiktionary source and license:
https://kaikki.org/simplewiktionary/rawdata.html

Open English WordNet source and license:
https://github.com/globalwordnet/english-wordnet

The current bundle records Simple English Wiktionary
`simplewiktionary-2026-08-15` (SHA-256
`679c49137170095022f6c40ce5800a8ba0d604bac565164cd1d5f5b6ac4f3bb9`) and
OEWN `OEWN-2025` (SHA-256
`9a2d2d446397aa8cac9b0c9a4e5d9b32376312594e2670eaace3c13cf260d29e`).

No hand-authored per-word ranking or content-replacement data is bundled.

Wiktionary text is available under Creative Commons Attribution-ShareAlike
4.0 International and the GNU Free Documentation License. Attribution and
license details: https://en.wiktionary.org/wiki/Wiktionary:Copyrights

## CMU Pronouncing Dictionary

Pronunciations missing from selected Kaikki entries may be converted from the
CMU Pronouncing Dictionary. CMUdict does not supply Lexilo's vocabulary,
definitions, senses, or examples.

Source and license: https://github.com/cmusphinx/cmudict

Copyright (C) 1993-2015 Carnegie Mellon University. Use of CMUdict is permitted
for any purpose provided its copyright notice and permission notice are
retained. The dictionary is supplied without warranty.

## wordfreq 3.1.1

Frequency values used to rank learning candidates were produced by wordfreq
3.1.1. Its code is Apache-2.0 and redistributed data is CC BY-SA 4.0 with
upstream corpus acknowledgements.

Source, complete credits, and license: https://github.com/rspeer/wordfreq

## eSpeak NG 1.52.0

Where neither Kaikki nor CMUdict has a pronunciation, Lexilo stores an
explicitly marked generated IPA value produced by eSpeak NG 1.52.0. Human IPA
always has higher priority. Source and license: https://github.com/espeak-ng/espeak-ng
