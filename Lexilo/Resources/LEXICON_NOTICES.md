# Lexilo offline lexicon notices

## Open English WordNet 2025

The offline dictionary is derived from Open English WordNet 2025. Open English
WordNet is licensed under Creative Commons Attribution 4.0 International and
incorporates Princeton WordNet. Lexilo reformats the source as SQLite, selects
a primary sense for browsing and study, and adds frequency-based learning bands.

Open English WordNet: https://en-word.net/

Copyright © 2019–present The Open English WordNet Team.

This work is licensed under CC BY 4.0:
https://creativecommons.org/licenses/by/4.0/

This work is based on or incorporates elements of the Princeton University
WordNet database. WordNet Release 3.0 copyright 2006 by Princeton University.
Permission to use, copy, modify and distribute the software and database and
its documentation for any purpose and without fee or royalty is granted,
provided that the copyright notice, license statements, and disclaimer appear
on copies and modifications. Princeton provides the database as-is, without
warranty, and the name Princeton may not be used in advertising or publicity.

Full upstream notices:
https://github.com/globalwordnet/english-wordnet/blob/main/LICENSE.md

## wordfreq 3.1.1

Frequency values used to rank the offline learning candidates were produced by
wordfreq 3.1.1. The wordfreq code is Apache-2.0 and its redistributed data is
CC BY-SA 4.0. It combines multiple credited corpora, including Google Books
Ngrams, Leeds Internet Corpus, Wikipedia, ParaCrawl, OPUS OpenSubtitles, and
SUBTLEX frequency lists.

Source, complete credits, and license:
https://github.com/rspeer/wordfreq

Lexilo stores only the resulting frequency value and rank for entries present
in Open English WordNet.
