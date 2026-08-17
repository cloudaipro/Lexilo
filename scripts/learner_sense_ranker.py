"""Deterministic, build-time learner-oriented sense ranking.

The ranker deliberately keeps the canonical Kaikki sense inventory intact.
Other dictionaries are alignment evidence only.  The output is plain Python
data so the SQLite builder can persist both the final order and the evidence
used to produce it.
"""

from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Any, Iterable


RANK_MODEL_VERSION = "learner-sense-ranker-v1"
MIN_ALIGNMENT_SIMILARITY = 0.12

TOKEN_PATTERN = re.compile(r"[a-z0-9]+")
STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "been", "being", "by",
    "for", "from", "has", "have", "in", "into", "is", "it", "its", "may",
    "of", "on", "or", "that", "the", "their", "this", "to", "used", "was",
    "were", "which", "with",
}
RANK_DEMOTION_TAGS = {
    "technical": 0.18,
    "specialized": 0.18,
    "formal": 0.08,
    "literary": 0.10,
    "figurative": 0.06,
    "slang": 0.18,
    "regional": 0.12,
    "dialectal": 0.12,
    "nonstandard": 0.16,
    "transitive": 0.0,
    "intransitive": 0.0,
}


@dataclass(frozen=True)
class ExternalSense:
    source_name: str
    external_sense_id: str
    definition: str
    source_order: int


@dataclass(frozen=True)
class SenseAlignment:
    source_name: str
    external_sense_id: str
    external_rank: int
    similarity: float
    confidence: float
    method: str


def normalize(value: str) -> str:
    return " ".join(value.replace("_", " ").strip().casefold().split())


def _content_tokens(value: str) -> set[str]:
    return {
        token
        for token in TOKEN_PATTERN.findall(normalize(value))
        if token not in STOPWORDS and len(token) > 1
    }


def gloss_similarity(left: str, right: str) -> float:
    """Return a conservative lexical similarity for two glosses.

    This is intentionally explainable and dependency-free.  It is an
    alignment signal, never a semantic truth claim.  Stronger future
    sense-tagged corpus evidence can supersede it.
    """

    if normalize(left) == normalize(right) and normalize(left):
        return 1.0
    left_tokens = _content_tokens(left)
    right_tokens = _content_tokens(right)
    if not left_tokens or not right_tokens:
        return 0.0
    overlap = len(left_tokens & right_tokens)
    if not overlap:
        return 0.0
    union = len(left_tokens | right_tokens)
    containment = overlap / min(len(left_tokens), len(right_tokens))
    jaccard = overlap / union
    return round(0.65 * jaccard + 0.35 * containment, 6)


def alignment_confidence(similarity: float) -> float:
    if similarity < MIN_ALIGNMENT_SIMILARITY:
        return 0.0
    if similarity >= 0.50:
        return 0.95
    if similarity >= 0.30:
        return 0.80
    if similarity >= 0.20:
        return 0.62
    return 0.40


def align_senses(
    local_senses: Iterable[dict[str, Any]],
    external_senses: list[ExternalSense],
) -> dict[str, list[SenseAlignment]]:
    """Align local senses to the closest external glosses.

    Up to two near-best matches are retained because one external synset may
    split or combine a dictionary sense.  The caller decides how much weight
    to give the result.
    """

    result: dict[str, list[SenseAlignment]] = {}
    if not external_senses:
        return result
    for local in local_senses:
        local_id = str(local["source_id"])
        candidates: list[SenseAlignment] = []
        for external in external_senses:
            similarity = gloss_similarity(str(local["definition"]), external.definition)
            confidence = alignment_confidence(similarity)
            if confidence <= 0:
                continue
            candidates.append(
                SenseAlignment(
                    source_name=external.source_name,
                    external_sense_id=external.external_sense_id,
                    external_rank=external.source_order,
                    similarity=similarity,
                    confidence=confidence,
                    method="gloss-token-overlap",
                )
            )
        candidates.sort(key=lambda item: (-item.similarity, item.external_rank, item.external_sense_id))
        if candidates:
            best = candidates[0]
            result[local_id] = [
                item
                for item in candidates[:2]
                if item.similarity >= best.similarity - 0.05
            ]
    return result


def _usage_penalty(sense: dict[str, Any]) -> float:
    tags = {str(tag).casefold() for tag in sense.get("tags", [])}
    return round(sum(RANK_DEMOTION_TAGS.get(tag, 0.0) for tag in tags), 6)


def _external_rank_signal(alignment: SenseAlignment, count: int) -> float:
    if count <= 1:
        rank_signal = 1.0
    else:
        rank_signal = 1.0 - (alignment.external_rank / max(1, count - 1))
    return round(max(0.0, min(1.0, rank_signal)) * alignment.confidence, 6)


def rank_senses(
    word: str,
    part_of_speech: str,
    senses: list[dict[str, Any]],
    external_indexes: dict[str, dict[tuple[str, str], list[ExternalSense]]],
) -> list[dict[str, Any]]:
    """Rank local senses using external evidence, labels, and Kaikki order."""

    if not senses:
        return []

    key = (normalize(word), normalize(part_of_speech))
    alignments_by_source: dict[str, dict[str, list[SenseAlignment]]] = {}
    for source_name, index in external_indexes.items():
        external = index.get(key, [])
        alignments_by_source[source_name] = align_senses(senses, external)

    prepared: list[dict[str, Any]] = []
    for sense in senses:
        source_id = str(sense["source_id"])
        alignment_rows: list[SenseAlignment] = []
        source_features: dict[str, float] = {}
        for source_name, source_alignments in alignments_by_source.items():
            matches = source_alignments.get(source_id, [])
            if not matches:
                continue
            best = matches[0]
            alignment_rows.extend(matches)
            source_features[source_name] = _external_rank_signal(best, len(external_indexes[source_name].get(key, [])))

        simple_signal = source_features.get("simple_wiktionary", 0.0)
        oewn_signal = source_features.get("oewn", 0.0)
        external_support = 0.35 * simple_signal + 0.35 * oewn_signal
        if simple_signal and oewn_signal:
            external_support += 0.20 * min(simple_signal, oewn_signal)
        external_support = round(external_support, 6)

        usage_penalty = _usage_penalty(sense)
        fallback_signal = round(1.0 / (1.0 + max(0, int(sense["source_order"]))), 6)
        learner_score = round(
            (external_support * 100.0)
            + ((1.0 - min(1.0, usage_penalty)) * 5.0)
            + (fallback_signal * 0.01),
            6,
        )

        if source_features:
            names = []
            if "simple_wiktionary" in source_features:
                names.append("Simple Wiktionary alignment")
            if "oewn" in source_features:
                names.append("OEWN alignment")
            rank_reason = " + ".join(names)
            if usage_penalty:
                rank_reason += "; usage labels"
            confidence = round(min(0.95, 0.35 + max(source_features.values()) * 0.55 + (0.10 if len(source_features) > 1 else 0.0)), 6)
        else:
            rank_reason = "Kaikki source order fallback"
            if usage_penalty:
                rank_reason += "; usage labels"
            confidence = 0.20

        candidate = dict(sense)
        candidate["learner_score"] = learner_score
        candidate["learner_confidence"] = confidence
        candidate["rank_reason"] = rank_reason
        candidate["alignments"] = alignment_rows
        candidate["features"] = {
            "simple_wiktionary_signal": simple_signal,
            "oewn_signal": oewn_signal,
            "external_support": external_support,
            "usage_penalty": usage_penalty,
            "fallback_signal": fallback_signal,
        }
        prepared.append(candidate)

    ranked = sorted(
        prepared,
        key=lambda item: (
            -item["features"]["external_support"],
            item["features"]["usage_penalty"],
            item["source_order"],
            item["source_id"],
        ),
    )

    for rank, item in enumerate(ranked, 1):
        item["learner_rank"] = rank
    return ranked
