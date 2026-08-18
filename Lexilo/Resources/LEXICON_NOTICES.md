# Lexilo offline lexicon notices

## Simple English Wiktionary

Lexilo's offline Learning Core is derived from the official Simple English
Wiktionary `pages-articles.xml.bz2` dump. Lexilo parses the dump locally,
preserving Simple English definitions, examples, parts of speech, forms, and
IPA before packaging the selected learning entries as SQLite.

The bundled build is `simplewiktionary-20260801` with rank model
`learner-sense-ranker-v1`. It contains 5,591 learning terms, 11,731 retained
senses, and 13,264 validated usage examples. Example records must contain the
learning word or a valid inflected form and read as complete sentences;
definitions, descriptions, collocations, and bare phrases are not relabeled as
examples.

Source dump index:
https://dumps.wikimedia.org/simplewiktionary/latest/

Source artifact:
https://dumps.wikimedia.org/simplewiktionary/latest/simplewiktionary-latest-pages-articles.xml.bz2

Pinned artifact SHA-256:
`f52c4492e187478fe4bf1cb47fbd37039168b5dea4c793996ef48f187bce6593`

Simple English Wiktionary:
https://simple.wiktionary.org/

Wiktionary copyright and license details:
https://en.wiktionary.org/wiki/Wiktionary:Copyrights

Wikimedia dump text is available under Creative Commons Attribution-ShareAlike
4.0 International and the GNU Free Documentation License. Lexilo reformats
and filters the dump; the source license and attribution remain applicable.

## Learner-oriented ranking evidence

Lexilo stores a separate deterministic `learner_rank` for each Simple English
Wiktionary sense. The upstream `sense_order` is preserved for provenance.
Optional Open English WordNet data can contribute alignment evidence and
ranking features only; it cannot add definitions, examples, or source rows to
the user-facing dictionary inventory.

Open English WordNet source and license:
https://github.com/globalwordnet/english-wordnet

No hand-authored per-word ranking or content-replacement data is bundled.

## CMU Pronouncing Dictionary

Pronunciations missing from selected Simple English Wiktionary entries may be
converted from the CMU Pronouncing Dictionary. CMUdict does not supply
Lexilo's vocabulary, definitions, senses, or examples.

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

Where neither Simple English Wiktionary nor CMUdict has a pronunciation,
Lexilo stores an explicitly marked generated IPA value produced by eSpeak NG
1.52.0. Human IPA always has higher priority. Source and license:
https://github.com/espeak-ng/espeak-ng
