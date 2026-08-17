#!/usr/bin/env python3
"""Upgrade an existing Lexilo Learning Core to learner-oriented ranking.

This is useful when a pinned Kaikki JSONL rebuild is not locally available.
It preserves the canonical Kaikki rows, adds ranking metadata, and optionally
loads external alignment evidence.
"""

from __future__ import annotations

import argparse
from collections import defaultdict
import sqlite3
from pathlib import Path
from typing import Any

from build_lexicon import (
    load_oewn,
    load_simple_wiktionary,
    source_digest,
)
from learner_sense_ranker import RANK_MODEL_VERSION, rank_senses


def has_column(connection: sqlite3.Connection, table: str, column: str) -> bool:
    return any(row[1] == column for row in connection.execute(f"PRAGMA table_info({table})"))


def ensure_schema(connection: sqlite3.Connection) -> None:
    additions = {
        "sense": [
            ("learner_rank", "INTEGER NOT NULL DEFAULT 0"),
            ("learner_confidence", "REAL NOT NULL DEFAULT 0.0"),
            ("rank_reason", "TEXT NOT NULL DEFAULT 'legacy ranking fallback'"),
            ("rank_model_version", "TEXT NOT NULL DEFAULT 'legacy'"),
        ],
    }
    for table, columns in additions.items():
        for column, declaration in columns:
            if not has_column(connection, table, column):
                connection.execute(f"ALTER TABLE {table} ADD COLUMN {column} {declaration}")
    feature_columns = {row[1] for row in connection.execute("PRAGMA table_info(sense_rank_feature)")}
    if "feature_name" in feature_columns:
        connection.execute("DROP INDEX IF EXISTS sense_feature_sense")
        connection.execute(
            """
            CREATE TABLE sense_rank_feature_compact(
                sense_id INTEGER PRIMARY KEY REFERENCES sense(id),
                simple_wiktionary_signal REAL NOT NULL,
                oewn_signal REAL NOT NULL,
                external_support REAL NOT NULL,
                usage_penalty REAL NOT NULL,
                fallback_signal REAL NOT NULL
            )
            """
        )
        connection.execute(
            """
            INSERT INTO sense_rank_feature_compact(
                sense_id, simple_wiktionary_signal, oewn_signal,
                external_support, usage_penalty, fallback_signal
            )
            SELECT sense_id,
                   MAX(CASE WHEN feature_name = 'simple_wiktionary_signal' THEN numeric_value ELSE 0 END),
                   MAX(CASE WHEN feature_name = 'oewn_signal' THEN numeric_value ELSE 0 END),
                   MAX(CASE WHEN feature_name = 'external_support' THEN numeric_value ELSE 0 END),
                   MAX(CASE WHEN feature_name = 'usage_penalty' THEN numeric_value ELSE 0 END),
                   MAX(CASE WHEN feature_name = 'fallback_signal' THEN numeric_value ELSE 0 END)
            FROM sense_rank_feature
            GROUP BY sense_id
            """
        )
        connection.execute("DROP TABLE sense_rank_feature")
        connection.execute("ALTER TABLE sense_rank_feature_compact RENAME TO sense_rank_feature")
    connection.executescript(
        """
        CREATE TABLE IF NOT EXISTS sense_alignment(
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
        CREATE TABLE IF NOT EXISTS sense_rank_feature(
            sense_id INTEGER PRIMARY KEY REFERENCES sense(id),
            simple_wiktionary_signal REAL NOT NULL,
            oewn_signal REAL NOT NULL,
            external_support REAL NOT NULL,
            usage_penalty REAL NOT NULL,
            fallback_signal REAL NOT NULL
        );
        """
    )


def source_id(
    connection: sqlite3.Connection,
    name: str,
    version: str,
    url: str,
    license_text: str,
) -> int:
    row = connection.execute("SELECT id FROM source WHERE name = ?", (name,)).fetchone()
    if row:
        connection.execute(
            "UPDATE source SET version = ?, url = ?, license = ? WHERE id = ?",
            (version, url, license_text, row[0]),
        )
        return int(row[0])
    connection.execute(
        "INSERT INTO source(name, version, url, license) VALUES (?, ?, ?, ?)",
        (name, version, url, license_text),
    )
    return int(connection.execute("SELECT last_insert_rowid()").fetchone()[0])


def upgrade(
    database: Path,
    simple_path: Path | None,
    oewn_path: Path | None,
    simple_version: str | None,
    oewn_version: str | None,
) -> None:
    external_indexes = {}
    if simple_path:
        external_indexes["simple_wiktionary"] = load_simple_wiktionary(simple_path)
    if oewn_path:
        external_indexes["oewn"] = load_oewn(oewn_path)

    connection = sqlite3.connect(database)
    connection.execute("PRAGMA foreign_keys=ON")
    ensure_schema(connection)

    external_source_ids: dict[str, int] = {}
    if simple_path:
        external_source_ids["simple_wiktionary"] = source_id(
            connection,
            "Kaikki / Simple English Wiktionary",
            f"{simple_version or 'unversioned'} sha256:{source_digest(simple_path)}",
            "https://kaikki.org/simplewiktionary/rawdata.html",
            "CC BY-SA 4.0 and GFDL",
        )
    if oewn_path:
        external_source_ids["oewn"] = source_id(
            connection,
            "Open English WordNet",
            f"{oewn_version or 'unversioned'} sha256:{source_digest(oewn_path)}",
            "https://github.com/globalwordnet/english-wordnet",
            "CC BY 4.0",
        )

    sense_rows = connection.execute(
        """
        SELECT s.id, l.id, t.word, l.part_of_speech, s.source_sense_id,
               s.definition, s.sense_order,
               COALESCE(s.usage_label, '')
        FROM sense s
        JOIN source_entry se ON se.id = s.source_entry_id
        JOIN lexeme l ON l.id = se.lexeme_id
        JOIN term t ON t.id = l.term_id
        ORDER BY l.id, s.id
        """
    ).fetchall()
    by_lexeme: dict[int, list[tuple[Any, ...]]] = defaultdict(list)
    for row in sense_rows:
        by_lexeme[int(row[1])].append(row)

    examples_by_sense: dict[int, list[tuple[str, str, float]]] = defaultdict(list)
    for row in connection.execute("SELECT sense_id, text, source_type, quality_score FROM example"):
        examples_by_sense[int(row[0])].append((str(row[1]), str(row[2]), float(row[3])))

    for lexeme_id, rows in by_lexeme.items():
        del lexeme_id
        local_senses = []
        for row in rows:
            local_senses.append(
                {
                    "db_id": int(row[0]),
                    "source_id": str(row[4]),
                    "definition": str(row[5]),
                    "usage_label": str(row[7]),
                    "tags": [tag.strip() for tag in str(row[7]).split(",") if tag.strip()],
                    "source_order": int(row[6]),
                    "examples": examples_by_sense[int(row[0])],
                }
            )
        word = str(rows[0][2])
        part_of_speech = str(rows[0][3])
        ranked = rank_senses(word, part_of_speech, local_senses, external_indexes)

        for sense in ranked:
            db_id = int(sense["db_id"])
            connection.execute(
                """
                UPDATE sense
                SET definition = ?, sense_order = ?, learner_rank = ?,
                    learner_score = ?, learner_confidence = ?,
                    rank_reason = ?, rank_model_version = ?
                WHERE id = ?
                """,
                (
                    sense["definition"],
                    sense["source_order"],
                    sense["learner_rank"],
                    sense["learner_score"],
                    sense["learner_confidence"],
                    sense["rank_reason"],
                    RANK_MODEL_VERSION,
                    db_id,
                ),
            )
            connection.execute("DELETE FROM sense_alignment WHERE sense_id = ?", (db_id,))
            connection.execute("DELETE FROM sense_rank_feature WHERE sense_id = ?", (db_id,))
            for alignment in sense["alignments"]:
                external_id = external_source_ids.get(alignment.source_name)
                if external_id is None:
                    continue
                connection.execute(
                    """
                    INSERT INTO sense_alignment(
                        sense_id, source_id, external_sense_id, external_rank,
                        similarity_score, confidence, method
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        db_id,
                        external_id,
                        alignment.external_sense_id,
                        alignment.external_rank,
                        alignment.similarity,
                        alignment.confidence,
                        alignment.method,
                    ),
                )
            connection.execute(
                """
                INSERT INTO sense_rank_feature(
                    sense_id, simple_wiktionary_signal, oewn_signal,
                    external_support, usage_penalty, fallback_signal
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                (
                    db_id,
                    sense["features"]["simple_wiktionary_signal"],
                    sense["features"]["oewn_signal"],
                    sense["features"]["external_support"],
                    sense["features"]["usage_penalty"],
                    sense["features"]["fallback_signal"],
                ),
            )
    connection.execute("INSERT OR REPLACE INTO metadata(key, value) VALUES ('schema_version', '4')")
    connection.execute("INSERT OR REPLACE INTO metadata(key, value) VALUES ('rank_model_version', ?)", (RANK_MODEL_VERSION,))
    connection.execute(
        "INSERT OR REPLACE INTO metadata(key, value) VALUES ('rank_external_sources', ?)",
        (", ".join(sorted(external_indexes)) or "none",),
    )
    connection.executescript(
        """
        CREATE INDEX IF NOT EXISTS sense_entry ON sense(source_entry_id, learner_rank, sense_order);
        CREATE INDEX IF NOT EXISTS sense_learner_rank ON sense(source_entry_id, learner_rank);
        CREATE INDEX IF NOT EXISTS sense_lexeme_rank ON sense(source_entry_id, learner_rank, id);
        CREATE INDEX IF NOT EXISTS sense_alignment_sense ON sense_alignment(sense_id, confidence DESC);
        CREATE INDEX IF NOT EXISTS example_sense ON example(sense_id, quality_score DESC);
        """
    )
    connection.commit()
    connection.execute("VACUUM")
    connection.commit()
    integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
    if integrity != "ok":
        raise RuntimeError(f"Database validation failed: integrity={integrity}")
    connection.close()
    print(f"Upgraded {database} with {RANK_MODEL_VERSION}; external sources: {', '.join(sorted(external_indexes)) or 'none'}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", type=Path, default=Path("Lexilo/Resources/lexilo-lexicon.sqlite"))
    parser.add_argument("--simple-wiktionary", type=Path)
    parser.add_argument("--simple-version")
    parser.add_argument("--oewn", type=Path)
    parser.add_argument("--oewn-version")
    args = parser.parse_args()
    upgrade(
        args.database,
        args.simple_wiktionary,
        args.oewn,
        args.simple_version,
        args.oewn_version,
    )


if __name__ == "__main__":
    main()
