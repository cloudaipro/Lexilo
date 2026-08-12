#!/usr/bin/env python3
"""Build Lexilo's immutable offline lexicon from a pinned OEWN release.

The resulting SQLite file contains the complete Open English WordNet catalog.
A smaller, quality-filtered subset is marked as eligible for automatic study.
Frequency values come from wordfreq and are used only at build time.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sqlite3
import tempfile
import urllib.request
import zipfile
from pathlib import Path

from wordfreq import zipf_frequency


OEWN_VERSION = "2025"
OEWN_URL = "https://en-word.net/static/english-wordnet-2025-json.zip"
OEWN_SHA256 = "7d749f6e2c39e6970e4997839dcf6e42fd281f3c2fae0171d2192bae8cfa4b51"
SOURCE_URL = "https://en-word.net/"
WORD_PATTERN = re.compile(r"[A-Za-z][A-Za-z' -]{1,59}")
POS_NAMES = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective", "r": "adverb"}


SCHEMA = """
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE lexeme(
    id TEXT PRIMARY KEY,
    lemma TEXT NOT NULL,
    normalized_lemma TEXT NOT NULL,
    part_of_speech TEXT NOT NULL,
    pronunciation TEXT,
    zipf_frequency REAL NOT NULL,
    frequency_rank INTEGER,
    learning_band INTEGER NOT NULL,
    is_phrase INTEGER NOT NULL,
    is_learning_candidate INTEGER NOT NULL,
    source_id TEXT NOT NULL
);
CREATE TABLE sense(
    id TEXT PRIMARY KEY,
    lexeme_id TEXT NOT NULL REFERENCES lexeme(id),
    synset_id TEXT NOT NULL,
    definition TEXT NOT NULL,
    sense_order INTEGER NOT NULL,
    usage_label TEXT
);
CREATE TABLE example(
    id INTEGER PRIMARY KEY,
    sense_id TEXT NOT NULL REFERENCES sense(id),
    text TEXT NOT NULL
);
CREATE INDEX lexeme_normalized ON lexeme(normalized_lemma);
CREATE INDEX lexeme_learning ON lexeme(is_learning_candidate, learning_band, frequency_rank);
CREATE INDEX sense_lexeme ON sense(lexeme_id, sense_order);
CREATE INDEX example_sense ON example(sense_id);
"""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def obtain_source(source_dir: Path | None, work_dir: Path) -> Path:
    if source_dir:
        return source_dir
    archive = work_dir / "oewn.zip"
    urllib.request.urlretrieve(OEWN_URL, archive)
    actual = sha256(archive)
    if actual != OEWN_SHA256:
        raise RuntimeError(f"OEWN checksum mismatch: expected {OEWN_SHA256}, got {actual}")
    extracted = work_dir / "oewn"
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(extracted)
    return extracted


def normalized_lemma(value: str) -> str:
    return value.replace("_", " ").strip().lower()


def text_value(value: object) -> str:
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, dict) and isinstance(value.get("text"), str):
        return value["text"].strip()
    return ""


def band_for(frequency: float) -> int:
    if frequency >= 5.0:
        return 1
    if frequency >= 4.3:
        return 2
    if frequency >= 3.7:
        return 3
    if frequency >= 3.1:
        return 4
    return 5


def load_entry_metadata(source: Path):
    senses: dict[tuple[str, str, str], str] = {}
    pronunciations: dict[tuple[str, str], str] = {}
    for path in sorted(source.glob("entries-*.json")):
        for lemma, variants in json.loads(path.read_text()).items():
            for pos, entry in variants.items():
                pronunciation = next((p.get("value", "") for p in entry.get("pronunciation", []) if p.get("value")), "")
                if pronunciation:
                    pronunciations[(lemma, pos)] = pronunciation
                for sense in entry.get("sense", []):
                    senses[(lemma, pos, sense["synset"])] = sense["id"]
    return senses, pronunciations


def build(source: Path, output: Path) -> None:
    sense_ids, pronunciations = load_entry_metadata(source)
    synsets: list[tuple[str, dict]] = []
    for path in sorted(source.glob("*.json")):
        if path.name.startswith("entries-") or path.name == "frames.json":
            continue
        synsets.extend(json.loads(path.read_text()).items())

    lemma_frequencies: dict[str, float] = {}
    for _, synset in synsets:
        for lemma in synset.get("members", []):
            normalized = normalized_lemma(lemma)
            lemma_frequencies.setdefault(normalized, zipf_frequency(normalized, "en"))
    ranks = {
        lemma: index + 1
        for index, (lemma, _) in enumerate(sorted(lemma_frequencies.items(), key=lambda item: (-item[1], item[0])))
    }

    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    connection = sqlite3.connect(output)
    connection.executescript(SCHEMA)
    connection.executemany(
        "INSERT INTO metadata VALUES (?, ?)",
        [
            ("schema_version", "1"),
            ("dataset", "Open English WordNet"),
            ("dataset_version", OEWN_VERSION),
            ("source_url", SOURCE_URL),
            ("text_license", "CC BY 4.0 and Princeton WordNet License"),
            ("frequency_source", "wordfreq 3.1.1"),
        ],
    )

    lexemes: dict[tuple[str, str], str] = {}
    sense_order: dict[str, int] = {}
    candidate_count = 0
    for synset_id, synset in synsets:
        raw_pos = synset.get("partOfSpeech", "")
        pos = "a" if raw_pos == "s" else raw_pos
        if pos not in POS_NAMES:
            continue
        definitions = synset.get("definition", [])
        if not definitions:
            continue
        definition = text_value(definitions[0])
        examples = [text for item in synset.get("example", []) if (text := text_value(item))]
        for lemma in synset.get("members", []):
            normalized = normalized_lemma(lemma)
            lexeme_key = (normalized, pos)
            lexeme_id = lexemes.get(lexeme_key)
            frequency = lemma_frequencies[normalized]
            is_phrase = int(" " in normalized)
            if lexeme_id is None:
                lexeme_id = f"oewn:{pos}:{normalized}"
                lexemes[lexeme_key] = lexeme_id
                valid_shape = bool(WORD_PATTERN.fullmatch(normalized)) and len(normalized.split()) <= 3
                candidate = int(valid_shape and frequency >= 3.0 and bool(examples))
                candidate_count += candidate
                pronunciation = pronunciations.get((lemma, raw_pos)) or pronunciations.get((lemma, pos))
                connection.execute(
                    "INSERT INTO lexeme VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        lexeme_id,
                        normalized,
                        normalized,
                        POS_NAMES[pos],
                        pronunciation,
                        frequency,
                        ranks[normalized],
                        band_for(frequency),
                        is_phrase,
                        candidate,
                        "oewn-2025",
                    ),
                )
                sense_order[lexeme_id] = 0

            order = sense_order[lexeme_id]
            source_sense_id = sense_ids.get((lemma, raw_pos, synset_id)) or sense_ids.get((lemma, pos, synset_id))
            stable_sense_id = f"oewn:{source_sense_id}" if source_sense_id else f"oewn:{synset_id}:{normalized}"
            connection.execute(
                "INSERT OR IGNORE INTO sense VALUES (?, ?, ?, ?, ?, ?)",
                (stable_sense_id, lexeme_id, synset_id, definition, order, None),
            )
            for example in examples:
                connection.execute("INSERT INTO example(sense_id, text) VALUES (?, ?)", (stable_sense_id, example))
            sense_order[lexeme_id] = order + 1

    connection.executemany(
        "INSERT INTO metadata VALUES (?, ?)",
        [("lexeme_count", str(len(lexemes))), ("learning_candidate_count", str(candidate_count))],
    )
    connection.execute("ANALYZE")
    connection.commit()
    connection.execute("VACUUM")
    integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    actual_lexemes = connection.execute("SELECT count(*) FROM lexeme").fetchone()[0]
    actual_candidates = connection.execute("SELECT count(*) FROM lexeme WHERE is_learning_candidate = 1").fetchone()[0]
    if integrity != "ok" or actual_lexemes != len(lexemes) or actual_candidates != candidate_count:
        raise RuntimeError(
            f"Database validation failed: integrity={integrity}, "
            f"lexemes={actual_lexemes}/{len(lexemes)}, candidates={actual_candidates}/{candidate_count}"
        )
    connection.close()
    print(f"Built {output}: {len(lexemes)} lexemes, {candidate_count} learning candidates")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-dir", type=Path, help="Already extracted english-wordnet JSON directory")
    parser.add_argument("--output", type=Path, default=Path("Lexilo/Resources/lexilo-lexicon.sqlite"))
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="lexilo-lexicon-") as temporary:
        build(obtain_source(args.source_dir, Path(temporary)), args.output)


if __name__ == "__main__":
    main()
