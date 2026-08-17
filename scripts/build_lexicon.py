#!/usr/bin/env python3
"""Build Lexilo's compact offline Learning Core from pinned open data.

Kaikki's structured English Wiktionary extract remains the canonical sense
inventory. Optional Simple English Wiktionary and Open English WordNet inputs
are used only as build-time ranking evidence; they never add user-facing sense
rows. CMUdict is used only to fill pronunciation gaps.
"""

from __future__ import annotations

import argparse
from collections import defaultdict
import gzip
import hashlib
import json
import re
import shutil
import sqlite3
import subprocess
import tempfile
import urllib.request
import zipfile
from pathlib import Path
from typing import Any, Iterator

from wordfreq import zipf_frequency

from learner_sense_ranker import ExternalSense, RANK_MODEL_VERSION, rank_senses


KAIKKI_VERSION = "2026-08-12-quality-v3"
KAIKKI_URL = "https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl"
KAIKKI_SHA256 = "34b1929e330d52df6a725eb404e0e9456c8ca0dd302fb2ad32354106caf5ff1f"
CMUDICT_COMMIT = "74790861f652b15e4ac49015a90074ad62a27690"
CMUDICT_URL = f"https://raw.githubusercontent.com/cmusphinx/cmudict/{CMUDICT_COMMIT}/cmudict.dict"
CMUDICT_SHA256 = "81917843c7f44ce2b094ac63873c2c7a4cf802040792c455ba3ca406891c3d22"
ESPEAK_NG_VERSION = "1.52.0"
MAX_SENSES = 5
WORD_PATTERN = re.compile(r"[A-Za-z][A-Za-z' -]{1,59}")
TOKEN_PATTERN = re.compile(r"[a-z0-9]+")
ALLOWED_POS = {
    "noun": "noun",
    "verb": "verb",
    "adj": "adjective",
    "adv": "adverb",
}
REJECTED_TAGS = {
    "abbreviation", "alt-of", "archaic", "dated", "derogatory", "deprecated",
    "form-of", "historical", "obsolete", "offensive", "rare", "slur", "vulgar",
}


SCHEMA = """
PRAGMA journal_mode=OFF;
PRAGMA synchronous=OFF;
PRAGMA temp_store=MEMORY;
PRAGMA foreign_keys=ON;
CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE TABLE source(
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    version TEXT NOT NULL,
    url TEXT NOT NULL,
    license TEXT NOT NULL
);
CREATE TABLE term(
    id INTEGER PRIMARY KEY,
    word TEXT NOT NULL,
    normalized_word TEXT NOT NULL UNIQUE,
    is_phrase INTEGER NOT NULL,
    zipf_frequency REAL NOT NULL,
    frequency_rank INTEGER,
    learning_band INTEGER NOT NULL,
    is_learning_candidate INTEGER NOT NULL
);
CREATE TABLE lexeme(
    id INTEGER PRIMARY KEY,
    term_id INTEGER NOT NULL REFERENCES term(id),
    part_of_speech TEXT NOT NULL,
    UNIQUE(term_id, part_of_speech)
);
CREATE TABLE source_entry(
    id INTEGER PRIMARY KEY,
    lexeme_id INTEGER NOT NULL REFERENCES lexeme(id),
    source_id INTEGER NOT NULL REFERENCES source(id),
    source_key TEXT NOT NULL UNIQUE,
    etymology_number TEXT,
    etymology_text TEXT
);
CREATE TABLE sense(
    id INTEGER PRIMARY KEY,
    source_entry_id INTEGER NOT NULL REFERENCES source_entry(id),
    source_sense_id TEXT NOT NULL UNIQUE,
    definition TEXT NOT NULL,
    sense_order INTEGER NOT NULL,
    learner_rank INTEGER NOT NULL,
    usage_label TEXT,
    learner_score REAL NOT NULL,
    learner_confidence REAL NOT NULL,
    rank_reason TEXT NOT NULL,
    rank_model_version TEXT NOT NULL
);
CREATE TABLE sense_alignment(
    id INTEGER PRIMARY KEY,
    sense_id INTEGER NOT NULL REFERENCES sense(id),
    source_id INTEGER NOT NULL REFERENCES source(id),
    external_sense_id TEXT NOT NULL,
    external_rank INTEGER NOT NULL,
    similarity_score REAL NOT NULL,
    confidence REAL NOT NULL,
    method TEXT NOT NULL,
    UNIQUE(sense_id, source_id, external_sense_id)
);
CREATE TABLE sense_rank_feature(
    sense_id INTEGER PRIMARY KEY REFERENCES sense(id),
    simple_wiktionary_signal REAL NOT NULL,
    oewn_signal REAL NOT NULL,
    external_support REAL NOT NULL,
    usage_penalty REAL NOT NULL,
    fallback_signal REAL NOT NULL
);
CREATE TABLE pronunciation(
    id INTEGER PRIMARY KEY,
    source_entry_id INTEGER NOT NULL REFERENCES source_entry(id),
    ipa TEXT NOT NULL,
    dialect TEXT,
    notation TEXT NOT NULL,
    provenance TEXT NOT NULL,
    is_generated INTEGER NOT NULL DEFAULT 0,
    priority INTEGER NOT NULL,
    UNIQUE(source_entry_id, ipa)
);
CREATE TABLE example(
    id INTEGER PRIMARY KEY,
    sense_id INTEGER NOT NULL REFERENCES sense(id),
    text TEXT NOT NULL,
    quality_score REAL NOT NULL,
    source_type TEXT NOT NULL
);
CREATE TABLE word_form(
    id INTEGER PRIMARY KEY,
    lexeme_id INTEGER NOT NULL REFERENCES lexeme(id),
    form TEXT NOT NULL,
    normalized_form TEXT NOT NULL,
    tags TEXT,
    UNIQUE(lexeme_id, normalized_form)
);
"""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, destination: Path, expected_sha256: str | None = None) -> Path:
    urllib.request.urlretrieve(url, destination)
    if expected_sha256:
        actual = sha256(destination)
        if actual != expected_sha256:
            raise RuntimeError(f"Checksum mismatch for {url}: expected {expected_sha256}, got {actual}")
    return destination


def normalize(value: str) -> str:
    return " ".join(value.replace("_", " ").strip().casefold().split())


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


def clean_text(value: object, maximum: int) -> str:
    if not isinstance(value, str):
        return ""
    result = " ".join(value.split()).strip()
    return result if 0 < len(result) <= maximum else ""


def reads_as_usage_sentence(text: str) -> bool:
    """Reject gloss-like noun phrases that are not usable learner examples."""
    value = text.rstrip()
    if len(TOKEN_PATTERN.findall(value)) < 4:
        return False
    return bool(re.search(r"[.!?…](?:[\"’'”»)]*)$", value))


def normalized_ipa(value: object) -> str:
    if not isinstance(value, str):
        return ""
    return value.strip().strip("/[]").strip()


def contains_learning_word(word: str, example: dict) -> bool:
    offsets = example.get("bold_text_offsets")
    if isinstance(offsets, list) and offsets:
        return True
    target = TOKEN_PATTERN.findall(normalize(word))
    content = TOKEN_PATTERN.findall(normalize(str(example.get("text", ""))))
    return bool(target) and any(content[i:i + len(target)] == target for i in range(len(content) - len(target) + 1))


def usable_examples(word: str, sense: dict) -> list[tuple[str, str, float]]:
    candidates: list[tuple[str, str, float]] = []
    for item in sense.get("examples", []):
        if not isinstance(item, dict) or not contains_learning_word(word, item):
            continue
        source_type = item.get("type")
        maximum = 300 if source_type == "example" else 220
        if source_type not in {"example", "quotation"}:
            continue
        text = clean_text(item.get("text"), maximum)
        if not text:
            continue
        if not reads_as_usage_sentence(text):
            continue
        quality = 1.0 if source_type == "example" else 0.65
        if len(text) <= 140:
            quality += 0.15
        candidates.append((text, source_type, quality))
    candidates.sort(key=lambda value: (-value[2], len(value[0]), value[0]))
    result: list[tuple[str, str, float]] = []
    seen: set[str] = set()
    for item in candidates:
        key = normalize(item[0])
        if key not in seen:
            seen.add(key)
            result.append(item)
    return result[:3]


def usable_senses(word: str, entry: dict) -> list[dict]:
    result: list[dict] = []
    for source_order, sense in enumerate(entry.get("senses", [])):
        if not isinstance(sense, dict):
            continue
        tags = {str(tag).casefold() for tag in sense.get("tags", [])}
        if tags & REJECTED_TAGS:
            continue
        definition = next((clean_text(value, 500) for value in sense.get("glosses", []) if clean_text(value, 500)), "")
        source_id = clean_text(sense.get("id"), 300)
        if not definition or not source_id:
            continue
        examples = usable_examples(word, sense)
        result.append({
            "source_id": source_id,
            "definition": definition,
            "usage_label": ", ".join(sorted(tags)),
            "tags": sorted(tags),
            "source_order": source_order,
            "examples": examples,
        })
    return result


def iter_json_lines(path: Path) -> Iterator[dict[str, Any]]:
    opener = gzip.open if path.suffix.casefold() == ".gz" else open
    with opener(path, "rt", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            value = json.loads(line)
            if isinstance(value, dict):
                yield value


def load_simple_wiktionary(path: Path | None) -> dict[tuple[str, str], list[ExternalSense]]:
    if path is None:
        return {}
    result: dict[tuple[str, str], list[ExternalSense]] = defaultdict(list)
    entry_counts: dict[tuple[str, str], int] = defaultdict(int)
    for entry in iter_json_lines(path):
        if entry.get("lang_code") != "en":
            continue
        part_of_speech = ALLOWED_POS.get(str(entry.get("pos", "")))
        word = clean_text(entry.get("word"), 60)
        if not part_of_speech or not word:
            continue
        key = (normalize(word), part_of_speech)
        entry_order = entry_counts[key]
        entry_counts[key] += 1
        for source_order, sense in enumerate(entry.get("senses", [])):
            if not isinstance(sense, dict):
                continue
            definition = next(
                (clean_text(value, 500) for value in sense.get("glosses", []) if clean_text(value, 500)),
                "",
            )
            source_sense_id = clean_text(sense.get("id"), 300) or f"simple:{normalize(word)}:{part_of_speech}:entry{entry_order}:sense{source_order}"
            if not definition or not source_sense_id:
                continue
            result[key].append(
                ExternalSense(
                    source_name="simple_wiktionary",
                    external_sense_id=source_sense_id,
                    definition=definition,
                    source_order=len(result[key]),
                )
            )
    for values in result.values():
        unique: dict[str, ExternalSense] = {}
        for value in values:
            unique.setdefault(value.external_sense_id, value)
        values[:] = sorted(unique.values(), key=lambda value: (value.source_order, value.external_sense_id))
    return dict(result)


def _json_objects_from_path(path: Path, pattern: str) -> Iterator[tuple[str, dict[str, Any]]]:
    if path.is_dir():
        paths = sorted(path.glob(pattern))
        for candidate in paths:
            payload = json.loads(candidate.read_text(encoding="utf-8"))
            if isinstance(payload, dict):
                yield candidate.name, payload
        return
    if path.suffix.casefold() != ".zip":
        raise RuntimeError(f"OEWN input must be a directory or .zip file: {path}")
    with zipfile.ZipFile(path) as archive:
        for name in sorted(value for value in archive.namelist() if re.fullmatch(pattern.replace("*", ".*"), Path(value).name)):
            payload = json.loads(archive.read(name).decode("utf-8"))
            if isinstance(payload, dict):
                yield Path(name).name, payload


def load_oewn(path: Path | None) -> dict[tuple[str, str], list[ExternalSense]]:
    if path is None:
        return {}
    pos_map = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective", "r": "adverb"}
    synsets: dict[str, str] = {}
    for name, payload in _json_objects_from_path(path, "*.json"):
        if name.startswith("entries-") or name == "frames.json":
            continue
        for synset_id, record in payload.items():
            if not isinstance(record, dict):
                continue
            definitions = record.get("definition", [])
            if isinstance(definitions, list):
                definition = next((clean_text(value, 800) for value in definitions if clean_text(value, 800)), "")
            else:
                definition = clean_text(definitions, 800)
            if definition:
                synsets[synset_id] = definition

    result: dict[tuple[str, str], list[ExternalSense]] = defaultdict(list)
    for name, payload in _json_objects_from_path(path, "entries-*.json"):
        del name
        for word, entry in payload.items():
            if not isinstance(entry, dict):
                continue
            normalized_word = normalize(str(word))
            for external_pos, part_of_speech in pos_map.items():
                part = entry.get(external_pos)
                if not isinstance(part, dict):
                    continue
                for source_order, sense in enumerate(part.get("sense", [])):
                    if not isinstance(sense, dict):
                        continue
                    external_sense_id = clean_text(sense.get("id"), 300)
                    synset_id = clean_text(sense.get("synset"), 100)
                    definition = synsets.get(synset_id, "")
                    if not external_sense_id or not definition:
                        continue
                    result[(normalized_word, part_of_speech)].append(
                        ExternalSense(
                            source_name="oewn",
                            external_sense_id=external_sense_id,
                            definition=definition,
                            source_order=source_order,
                        )
                    )
    for values in result.values():
        unique: dict[str, ExternalSense] = {}
        for value in values:
            unique.setdefault(value.external_sense_id, value)
        values[:] = sorted(unique.values(), key=lambda value: (value.source_order, value.external_sense_id))
    return dict(result)


def source_digest(path: Path) -> str:
    if path.is_file():
        return sha256(path)
    digest = hashlib.sha256()
    for candidate in sorted(value for value in path.rglob("*") if value.is_file()):
        digest.update(str(candidate.relative_to(path)).encode("utf-8"))
        digest.update(sha256(candidate).encode("ascii"))
    return digest.hexdigest()


def preferred_pronunciations(entry: dict) -> list[tuple[str, str, int]]:
    values: list[tuple[str, str, int]] = []
    seen: set[str] = set()
    for sound in entry.get("sounds", []):
        if not isinstance(sound, dict):
            continue
        ipa = normalized_ipa(sound.get("ipa"))
        if not ipa or ipa in seen:
            continue
        seen.add(ipa)
        tags = [str(tag) for tag in sound.get("tags", [])]
        lowered = {tag.casefold() for tag in tags}
        if lowered & {"general-american", "us", "canada"}:
            priority = 0
        elif not tags:
            priority = 1
        elif lowered & {"received-pronunciation", "uk"}:
            priority = 2
        else:
            priority = 3
        values.append((ipa, ", ".join(tags), priority))
    values.sort(key=lambda value: (value[2], value[0]))
    return values[:3]


ARPABET = {
    "AA": "ɑ", "AE": "æ", "AH": "ʌ", "AO": "ɔ", "AW": "aʊ", "AY": "aɪ",
    "B": "b", "CH": "t͡ʃ", "D": "d", "DH": "ð", "EH": "ɛ", "ER": "ɝ",
    "EY": "eɪ", "F": "f", "G": "ɡ", "HH": "h", "IH": "ɪ", "IY": "i",
    "JH": "d͡ʒ", "K": "k", "L": "l", "M": "m", "N": "n", "NG": "ŋ",
    "OW": "oʊ", "OY": "ɔɪ", "P": "p", "R": "ɹ", "S": "s", "SH": "ʃ",
    "T": "t", "TH": "θ", "UH": "ʊ", "UW": "u", "V": "v", "W": "w",
    "Y": "j", "Z": "z", "ZH": "ʒ",
}
VOWELS = {"AA", "AE", "AH", "AO", "AW", "AY", "EH", "ER", "EY", "IH", "IY", "OW", "OY", "UH", "UW"}


def arpabet_to_ipa(phones: list[str]) -> str:
    syllables = sum(1 for phone in phones if re.sub(r"[012]$", "", phone) in VOWELS)
    result: list[str] = []
    for phone in phones:
        match = re.fullmatch(r"([A-Z]+)([012]?)", phone)
        if not match or match.group(1) not in ARPABET:
            return ""
        symbol, stress = match.groups()
        value = ARPABET[symbol]
        if stress == "0" and symbol == "AH":
            value = "ə"
        elif stress == "0" and symbol == "ER":
            value = "ɚ"
        if syllables > 1 and stress == "1":
            value = "ˈ" + value
        elif syllables > 1 and stress == "2":
            value = "ˌ" + value
        result.append(value)
    return "".join(result)


def load_cmudict(path: Path | None, wanted: set[str]) -> dict[str, str]:
    if path is None or not path.exists():
        return {}
    result: dict[str, str] = {}
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if not line or line.startswith(";;;"):
                continue
            fields = line.strip().split()
            if len(fields) < 2:
                continue
            word = re.sub(r"\(\d+\)$", "", fields[0]).casefold()
            if word in wanted and word not in result:
                ipa = arpabet_to_ipa(fields[1:])
                if ipa:
                    result[word] = ipa
    return result


def generate_pronunciations(binary: Path, data_root: Path, words: set[str]) -> dict[str, str]:
    ordered = sorted(words)
    if not ordered:
        return {}
    version = subprocess.run(
        [str(binary), f"--path={data_root}", "--version"],
        check=True, capture_output=True, text=True,
    ).stdout
    if ESPEAK_NG_VERSION not in version:
        raise RuntimeError(f"Expected eSpeak NG {ESPEAK_NG_VERSION}, got: {version.strip()}")
    process = subprocess.run(
        [str(binary), f"--path={data_root}", "-q", "--ipa=3", "-v", "en-us"],
        input="\n".join(ordered) + "\n",
        check=True,
        capture_output=True,
        text=True,
    )
    outputs = [value.strip().replace("\u200d", "") for value in process.stdout.splitlines()]
    if len(outputs) != len(ordered):
        raise RuntimeError(f"eSpeak output mismatch: {len(outputs)} pronunciations for {len(ordered)} terms")
    return {word: ipa for word, ipa in zip(ordered, outputs) if ipa}


def finalize_learner_ranks(connection: sqlite3.Connection) -> None:
    """Assign contiguous learner ranks across every lexeme/POS.

    A Kaikki lexeme can have multiple etymology/source entries.  Ranking each
    source entry independently would produce duplicate rank 1 values, so the
    final pass establishes one global order for the app-facing lexeme.
    """

    rows = connection.execute(
        """
        SELECT s.id, se.lexeme_id, s.learner_score,
               s.sense_order, s.source_sense_id
        FROM sense s
        JOIN source_entry se ON se.id = s.source_entry_id
        ORDER BY se.lexeme_id, s.id
        """
    ).fetchall()
    by_lexeme: dict[int, list[tuple[Any, ...]]] = defaultdict(list)
    for row in rows:
        by_lexeme[int(row[1])].append(row)

    for lexeme_id, senses in by_lexeme.items():
        senses.sort(key=lambda row: (-float(row[2]), int(row[3]), str(row[4]), int(row[0])))
        for rank, row in enumerate(senses, 1):
            connection.execute("UPDATE sense SET learner_rank = ? WHERE id = ?", (rank, row[0]))


def build(
    source: Path,
    output: Path,
    cmudict_path: Path | None,
    espeak_binary: Path,
    espeak_data: Path,
    simple_wiktionary_path: Path | None,
    oewn_path: Path | None,
    simple_version: str | None,
    oewn_version: str | None,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    external_indexes: dict[str, dict[tuple[str, str], list[ExternalSense]]] = {}
    if simple_wiktionary_path:
        external_indexes["simple_wiktionary"] = load_simple_wiktionary(simple_wiktionary_path)
    if oewn_path:
        external_indexes["oewn"] = load_oewn(oewn_path)

    connection = sqlite3.connect(output)
    connection.executescript(SCHEMA)
    source_ids: dict[str, int] = {}

    def add_source(name: str, version: str, url: str, license_text: str) -> int:
        connection.execute(
            "INSERT INTO source(name, version, url, license) VALUES (?, ?, ?, ?)",
            (name, version, url, license_text),
        )
        source_id = int(connection.execute("SELECT last_insert_rowid()").fetchone()[0])
        source_ids[name] = source_id
        return source_id

    kaikki_source_id = add_source(
        "Kaikki / English Wiktionary",
        KAIKKI_VERSION,
        "https://kaikki.org/dictionary/English/",
        "CC BY-SA 4.0 and GFDL",
    )
    if simple_wiktionary_path:
        source_ids["simple_wiktionary"] = add_source(
            "Kaikki / Simple English Wiktionary",
            f"{simple_version or 'unversioned'} sha256:{source_digest(simple_wiktionary_path)}",
            "https://kaikki.org/simplewiktionary/rawdata.html",
            "CC BY-SA 4.0 and GFDL",
        )
    if oewn_path:
        source_ids["oewn"] = add_source(
            "Open English WordNet",
            f"{oewn_version or 'unversioned'} sha256:{source_digest(oewn_path)}",
            "https://github.com/globalwordnet/english-wordnet",
            "CC BY 4.0",
        )

    terms: dict[str, int] = {}
    lexemes: dict[tuple[int, str], int] = {}
    entries_without_ipa: list[tuple[int, str]] = []
    selected_entries = 0
    with source.open(encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            entry = json.loads(line)
            if entry.get("lang_code") != "en" or entry.get("pos") not in ALLOWED_POS:
                continue
            word = clean_text(entry.get("word"), 60)
            normalized = normalize(word)
            if not word or not WORD_PATTERN.fullmatch(word) or len(normalized.split()) > 3:
                continue
            frequency = zipf_frequency(normalized, "en")
            if frequency < 3.0:
                continue
            pos = ALLOWED_POS[entry["pos"]]
            senses = usable_senses(word, entry)
            ranked_senses = rank_senses(
                word,
                pos,
                senses,
                external_indexes,
            )
            if not ranked_senses or not any(sense["examples"] for sense in ranked_senses):
                continue
            ranked_senses = ranked_senses[:MAX_SENSES]

            term_id = terms.get(normalized)
            if term_id is None:
                connection.execute(
                    "INSERT INTO term(word, normalized_word, is_phrase, zipf_frequency, learning_band, is_learning_candidate) VALUES (?, ?, ?, ?, ?, 1)",
                    (word, normalized, int(" " in normalized), frequency, band_for(frequency)),
                )
                term_id = connection.execute("SELECT last_insert_rowid()").fetchone()[0]
                terms[normalized] = term_id
            lexeme_key = (term_id, pos)
            lexeme_id = lexemes.get(lexeme_key)
            if lexeme_id is None:
                connection.execute("INSERT INTO lexeme(term_id, part_of_speech) VALUES (?, ?)", (term_id, pos))
                lexeme_id = connection.execute("SELECT last_insert_rowid()").fetchone()[0]
                lexemes[lexeme_key] = lexeme_id

            source_key_material = "|".join([normalized, pos, str(entry.get("etymology_number", ""))] + sorted(s["source_id"] for s in ranked_senses))
            source_key = "kaikki:" + hashlib.sha256(source_key_material.encode()).hexdigest()[:24]
            connection.execute(
                "INSERT INTO source_entry(lexeme_id, source_id, source_key, etymology_number, etymology_text) VALUES (?, ?, ?, ?, ?)",
                (lexeme_id, kaikki_source_id, source_key, str(entry.get("etymology_number", "")), clean_text(entry.get("etymology_text"), 4000)),
            )
            source_entry_id = connection.execute("SELECT last_insert_rowid()").fetchone()[0]
            for sense in ranked_senses:
                connection.execute(
                    """
                    INSERT OR IGNORE INTO sense(
                        source_entry_id, source_sense_id, definition,
                        sense_order, learner_rank, usage_label,
                        learner_score, learner_confidence, rank_reason,
                        rank_model_version
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        source_entry_id,
                        sense["source_id"],
                        sense["definition"],
                        sense["source_order"],
                        sense["learner_rank"],
                        sense["usage_label"],
                        sense["learner_score"],
                        sense["learner_confidence"],
                        sense["rank_reason"],
                        RANK_MODEL_VERSION,
                    ),
                )
                sense_id = connection.execute("SELECT id FROM sense WHERE source_sense_id = ?", (sense["source_id"],)).fetchone()[0]
                for text, source_type, quality in sense["examples"]:
                    connection.execute(
                        "INSERT OR IGNORE INTO example(sense_id, text, quality_score, source_type) VALUES (?, ?, ?, ?)",
                        (sense_id, text, quality, source_type),
                    )
                for alignment in sense["alignments"]:
                    external_source_id = source_ids.get(alignment.source_name)
                    if external_source_id is None:
                        continue
                    connection.execute(
                        """
                        INSERT OR IGNORE INTO sense_alignment(
                            sense_id, source_id, external_sense_id, external_rank,
                            similarity_score, confidence, method
                        ) VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                        (
                            sense_id,
                            external_source_id,
                            alignment.external_sense_id,
                            alignment.external_rank,
                            alignment.similarity,
                            alignment.confidence,
                            alignment.method,
                        ),
                    )
                connection.execute(
                    """
                    INSERT OR REPLACE INTO sense_rank_feature(
                        sense_id, simple_wiktionary_signal, oewn_signal,
                        external_support, usage_penalty, fallback_signal
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    (
                        sense_id,
                        sense["features"]["simple_wiktionary_signal"],
                        sense["features"]["oewn_signal"],
                        sense["features"]["external_support"],
                        sense["features"]["usage_penalty"],
                        sense["features"]["fallback_signal"],
                    ),
                )
            pronunciations = preferred_pronunciations(entry)
            for ipa, dialect, priority in pronunciations:
                connection.execute(
                    "INSERT OR IGNORE INTO pronunciation(source_entry_id, ipa, dialect, notation, provenance, priority) VALUES (?, ?, ?, 'IPA', 'kaikki-wiktionary', ?)",
                    (source_entry_id, ipa, dialect, priority),
                )
            if not pronunciations:
                entries_without_ipa.append((source_entry_id, normalized))
            for form in entry.get("forms", []):
                if not isinstance(form, dict):
                    continue
                value = clean_text(form.get("form"), 80)
                normalized_form = normalize(value)
                tags = [str(tag) for tag in form.get("tags", [])]
                if value and WORD_PATTERN.fullmatch(value) and not ({tag.casefold() for tag in tags} & REJECTED_TAGS):
                    connection.execute(
                        "INSERT OR IGNORE INTO word_form(lexeme_id, form, normalized_form, tags) VALUES (?, ?, ?, ?)",
                        (lexeme_id, value, normalized_form, ", ".join(tags)),
                    )
            selected_entries += 1
            if selected_entries % 5000 == 0:
                connection.commit()
                print(f"Selected {selected_entries:,} Kaikki entries (source line {line_number:,})", flush=True)

    finalize_learner_ranks(connection)

    cmu = load_cmudict(cmudict_path, {word for _, word in entries_without_ipa})
    for source_entry_id, word in entries_without_ipa:
        if ipa := cmu.get(word):
            connection.execute(
                "INSERT OR IGNORE INTO pronunciation(source_entry_id, ipa, dialect, notation, provenance, priority) VALUES (?, ?, 'General American', 'IPA', 'cmudict-converted', 10)",
                (source_entry_id, ipa),
            )
    missing_after_cmu = {(entry_id, word) for entry_id, word in entries_without_ipa if word not in cmu}
    generated = generate_pronunciations(espeak_binary, espeak_data, {word for _, word in missing_after_cmu})
    for source_entry_id, word in missing_after_cmu:
        if ipa := generated.get(word):
            connection.execute(
                "INSERT OR IGNORE INTO pronunciation(source_entry_id, ipa, dialect, notation, provenance, is_generated, priority) VALUES (?, ?, 'General American', 'IPA', 'generated-g2p', 1, 20)",
                (source_entry_id, ipa),
            )

    connection.executescript("""
    CREATE INDEX term_normalized ON term(normalized_word);
    CREATE INDEX term_learning ON term(is_learning_candidate, learning_band, frequency_rank);
    CREATE INDEX lexeme_term ON lexeme(term_id, part_of_speech);
    CREATE INDEX source_entry_lexeme ON source_entry(lexeme_id);
    CREATE INDEX sense_entry ON sense(source_entry_id, learner_rank, sense_order);
    CREATE INDEX sense_learner_rank ON sense(source_entry_id, learner_rank);
    CREATE INDEX sense_lexeme_rank ON sense(source_entry_id, learner_rank, id);
    CREATE INDEX sense_alignment_sense ON sense_alignment(sense_id, confidence DESC);
    CREATE INDEX pronunciation_entry ON pronunciation(source_entry_id, priority);
    CREATE INDEX example_sense ON example(sense_id, quality_score DESC);
    CREATE INDEX word_form_normalized ON word_form(normalized_form);
    """)
    ranked = connection.execute("SELECT id FROM term ORDER BY zipf_frequency DESC, normalized_word").fetchall()
    connection.executemany("UPDATE term SET frequency_rank = ? WHERE id = ?", ((rank, row[0]) for rank, row in enumerate(ranked, 1)))
    metadata = [
        ("schema_version", "4"),
        ("dataset", "Kaikki / English Wiktionary"),
        ("dataset_version", KAIKKI_VERSION),
        ("source_url", "https://kaikki.org/dictionary/English/"),
        ("text_license", "CC BY-SA 4.0 and GFDL"),
        ("rank_model_version", RANK_MODEL_VERSION),
        ("rank_external_sources", ", ".join(sorted(external_indexes)) or "none"),
        ("pronunciation_fallback", f"CMUdict {CMUDICT_COMMIT}"),
        ("generated_pronunciation", f"eSpeak NG {ESPEAK_NG_VERSION}"),
        ("frequency_source", "wordfreq 3.1.1"),
        ("term_count", str(len(terms))),
        ("lexeme_count", str(len(lexemes))),
        ("learning_candidate_count", str(len(terms))),
    ]
    connection.executemany("INSERT INTO metadata VALUES (?, ?)", metadata)
    connection.execute("ANALYZE")
    connection.commit()
    connection.execute("VACUUM")
    integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    fts_tables = connection.execute("SELECT count(*) FROM sqlite_master WHERE sql LIKE '%VIRTUAL TABLE%FTS%' COLLATE NOCASE").fetchone()[0]
    external_user_rows = connection.execute(
        """
        SELECT count(*)
        FROM source_entry se
        JOIN source src ON src.id = se.source_id
        WHERE src.name <> 'Kaikki / English Wiktionary'
        """
    ).fetchone()[0]
    bad_ranked_lexemes = connection.execute(
        """
        SELECT count(*)
        FROM (
            SELECT se.lexeme_id,
                   COUNT(*) AS sense_count,
                   COUNT(DISTINCT s.learner_rank) AS rank_count,
                   MIN(s.learner_rank) AS first_rank
            FROM sense s
            JOIN source_entry se ON se.id = s.source_entry_id
            GROUP BY se.lexeme_id
            HAVING rank_count <> sense_count OR first_rank <> 1
        )
        """
    ).fetchone()[0]
    if integrity != "ok" or fts_tables or external_user_rows or bad_ranked_lexemes:
        raise RuntimeError(
            "Database validation failed: "
            f"integrity={integrity}, fts={fts_tables}, external_user_rows={external_user_rows}, "
            f"bad_ranked_lexemes={bad_ranked_lexemes}"
        )
    counts = {
        table: connection.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
        for table in (
            "term", "lexeme", "source_entry", "sense", "sense_alignment",
            "sense_rank_feature", "pronunciation", "example", "word_form",
        )
    }
    connection.close()
    print(f"Built {output} ({output.stat().st_size / 1024 / 1024:.1f} MiB): {counts}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, help="Pinned Kaikki English JSONL file")
    parser.add_argument("--cmudict", type=Path, help="Pinned cmudict.dict file")
    parser.add_argument(
        "--simple-wiktionary",
        type=Path,
        help="Optional pinned Simple English Wiktionary Kaikki JSONL(.gz) used only for ranking evidence",
    )
    parser.add_argument(
        "--simple-version",
        help="Version label for the optional Simple English Wiktionary input",
    )
    parser.add_argument(
        "--oewn",
        type=Path,
        help="Optional Open English WordNet JSON directory or release .zip used only for ranking evidence",
    )
    parser.add_argument("--oewn-version", help="Version label for the optional OEWN input")
    parser.add_argument("--espeak", type=Path, help=f"eSpeak NG {ESPEAK_NG_VERSION} executable")
    parser.add_argument(
        "--espeak-data",
        type=Path,
        default=Path("Lexilo/Resources/Kitten/KittenVoice.bundle"),
        help="Directory containing espeak-ng-data",
    )
    parser.add_argument("--output", type=Path, default=Path("Lexilo/Resources/lexilo-lexicon.sqlite"))
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="lexilo-lexicon-") as temporary:
        work = Path(temporary)
        source = args.source or download(KAIKKI_URL, work / "kaikki-english.jsonl", KAIKKI_SHA256)
        if sha256(source) != KAIKKI_SHA256:
            raise RuntimeError(f"Kaikki checksum mismatch for {source}")
        cmudict = args.cmudict or download(CMUDICT_URL, work / "cmudict.dict", CMUDICT_SHA256)
        if sha256(cmudict) != CMUDICT_SHA256:
            raise RuntimeError(f"CMUdict checksum mismatch for {cmudict}")
        espeak_binary = args.espeak or (Path(found) if (found := shutil.which("espeak-ng")) else None)
        if espeak_binary is None:
            raise RuntimeError(f"eSpeak NG {ESPEAK_NG_VERSION} is required; pass --espeak /path/to/espeak-ng")
        if args.simple_wiktionary and not args.simple_wiktionary.exists():
            raise RuntimeError(f"Simple English Wiktionary input does not exist: {args.simple_wiktionary}")
        if args.oewn and not args.oewn.exists():
            raise RuntimeError(f"OEWN input does not exist: {args.oewn}")
        build(
            source,
            args.output,
            cmudict,
            espeak_binary,
            args.espeak_data,
            args.simple_wiktionary,
            args.oewn,
            args.simple_version,
            args.oewn_version,
        )


if __name__ == "__main__":
    main()
