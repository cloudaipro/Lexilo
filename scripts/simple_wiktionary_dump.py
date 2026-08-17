"""Extract the learner-facing fields Lexilo needs from a Simple Wiktionary dump.

The Wikimedia dump is MediaWiki XML, not Wiktextract JSONL.  Simple English
Wiktionary uses a deliberately regular page layout, so this small streaming
parser keeps the build self-contained while preserving the source dump as the
only lexical input.
"""

from __future__ import annotations

import bz2
import html
import re
import xml.etree.ElementTree as ElementTree
from pathlib import Path
from typing import Any, Iterator


ALLOWED_POS = {
    "noun": "noun",
    "verb": "verb",
    "adjective": "adjective",
    "adverb": "adverb",
}
HEADER_PATTERN = re.compile(r"^(={2,6})\s*(.*?)\s*\1\s*$")
TEMPLATE_PATTERN = re.compile(r"\{\{([^{}\n]+)\}\}")
LINK_PATTERN = re.compile(r"\[\[([^\[\]]+)\]\]")
EXTERNAL_LINK_PATTERN = re.compile(r"\[(https?://\S+)(?:\s+([^\]]+))?\]")
HTML_TAG_PATTERN = re.compile(r"<[^>]+>")
COMMENT_PATTERN = re.compile(r"<!--.*?-->", re.DOTALL)

LABEL_TEMPLATES = {
    "antonym": "antonym",
    "archaic": "archaic",
    "countable": "countable",
    "dated": "dated",
    "derogatory": "derogatory",
    "formal": "formal",
    "figurative": "figurative",
    "intransitive": "intransitive",
    "literary": "literary",
    "noncountable": "uncountable",
    "obsolete": "obsolete",
    "rare": "rare",
    "slang": "slang",
    "transitive": "transitive",
    "uncountable": "uncountable",
    "vulgar": "vulgar",
}
LINK_TEMPLATES = {"l", "link", "m", "mention", "r", "reference"}
DROP_TEMPLATES = {
    "ant",
    "audio",
    "context",
    "lb",
    "q",
    "qualifier",
    "syn",
    "taxlink",
    "t",
    "wikipedia",
}
PRONUNCIATION_TEMPLATES = {"ipa", "ipa-lite", "ipachar"}
DIALECT_TEMPLATES = {
    "uk": "UK",
    "us": "US",
    "canada": "Canada",
    "ca": "Canada",
    "au": "Australia",
    "australia": "Australia",
}


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _child_text(element: ElementTree.Element, name: str) -> str:
    for child in element.iter():
        if _local_name(child.tag) == name and child.text:
            return child.text
    return ""


def _template_parts(value: str) -> tuple[str, list[str], dict[str, str]]:
    parts = [part.strip() for part in value.split("|")]
    name = parts[0].casefold()
    positional: list[str] = []
    named: dict[str, str] = {}
    for part in parts[1:]:
        if "=" in part:
            key, item = part.split("=", 1)
            named[key.strip().casefold()] = item.strip()
        elif part.strip():
            positional.append(part.strip())
    return name, positional, named


def _templates(value: str) -> Iterator[tuple[str, list[str], dict[str, str]]]:
    for match in TEMPLATE_PATTERN.finditer(value):
        yield _template_parts(match.group(1))


def _plain_text(value: str) -> str:
    result = COMMENT_PATTERN.sub("", value)

    def replace_template(match: re.Match[str]) -> str:
        name, positional, named = _template_parts(match.group(1))
        if name in LINK_TEMPLATES:
            return _plain_text(named.get("alt") or (positional[-1] if positional else ""))
        if name in LABEL_TEMPLATES or name in DROP_TEMPLATES:
            return ""
        if name in {"small", "gloss", "nowrap"}:
            return _plain_text(positional[0] if positional else "")
        return ""

    previous = None
    while previous != result:
        previous = result
        result = TEMPLATE_PATTERN.sub(replace_template, result)
    result = EXTERNAL_LINK_PATTERN.sub(lambda match: match.group(2) or "", result)

    def replace_link(match: re.Match[str]) -> str:
        value = match.group(1).split("|", 1)
        return value[-1].split("#", 1)[-1]

    result = LINK_PATTERN.sub(replace_link, result)
    result = HTML_TAG_PATTERN.sub("", result)
    result = result.replace("'''", "").replace("''", "")
    result = html.unescape(result)
    return " ".join(result.split()).strip(" ;")


def _labels(value: str) -> set[str]:
    result: set[str] = set()
    for name, positional, _ in _templates(value):
        if name in LABEL_TEMPLATES:
            result.add(LABEL_TEMPLATES[name])
        elif name in {"context", "lb", "q", "qualifier"}:
            result.update(_plain_text(item).casefold() for item in positional if _plain_text(item))
    return result


def _forms_from_line(value: str) -> list[str]:
    result: list[str] = []
    for name, positional, named in _templates(value):
        if name == "noun":
            candidates = [named.get("2", ""), named.get("plural", "")]
        elif name.startswith("verb"):
            candidates = positional
        else:
            candidates = []
        for candidate in candidates:
            form = _plain_text(candidate)
            if form and form not in result:
                result.append(form)
    return result


def _pronunciations(lines: list[str]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    in_section = False
    for line in lines:
        header = HEADER_PATTERN.match(line.strip())
        if header:
            heading = header.group(2).casefold()
            in_section = heading == "pronunciation"
            continue
        if not in_section:
            continue
        dialect = next(
            (value for name, value in DIALECT_TEMPLATES.items() if any(template[0] == name for template in _templates(line))),
            None,
        )
        for name, positional, named in _templates(line):
            if name not in PRONUNCIATION_TEMPLATES:
                continue
            ipa = (positional[0] if positional else named.get("1", "")).strip()
            if ipa:
                result.append({"ipa": ipa, "tags": [dialect] if dialect else []})
    return result


def _entry_for_section(word: str, pos: str, sounds: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "word": word,
        "lang_code": "en",
        "pos": pos,
        "senses": [],
        "sounds": sounds,
        "forms": [],
    }


def parse_page(title: str, text: str) -> list[dict[str, Any]]:
    """Return structured entries for all supported POS sections on one page."""
    word = " ".join(title.replace("_", " ").split()).strip()
    if not word:
        return []
    lines = text.splitlines()
    sounds = _pronunciations(lines)
    entries: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    subsection = ""

    for line in lines:
        header = HEADER_PATTERN.match(line.strip())
        if header:
            level = len(header.group(1))
            heading = header.group(2).strip()
            if level == 2:
                normalized_heading = heading.casefold()
                pos = ALLOWED_POS.get(normalized_heading)
                current = _entry_for_section(word, pos, sounds) if pos else None
                if current is not None:
                    entries.append(current)
                subsection = ""
            elif level >= 3:
                subsection = heading.casefold()
            continue

        if current is None or subsection:
            continue
        if line.startswith("{{"):
            current["forms"].extend(_forms_from_line(line))
            continue

        example_match = re.match(r"^#+[:*]\s*(.*)$", line)
        if example_match and current["senses"]:
            raw_example = example_match.group(1)
            example = _plain_text(raw_example)
            if example:
                record: dict[str, Any] = {"text": example, "type": "example"}
                if "'''" in raw_example:
                    record["bold_text_offsets"] = [0]
                current["senses"][-1]["examples"].append(record)
            continue

        definition_match = re.match(r"^#+\s+(.+)$", line)
        if definition_match:
            definition = _plain_text(definition_match.group(1))
            if not definition:
                continue
            current["senses"].append(
                {
                    "glosses": [definition],
                    "examples": [],
                    "tags": sorted(_labels(definition_match.group(1))),
                }
            )
            current["forms"].extend(_forms_from_line(definition_match.group(1)))

    for entry in entries:
        entry["forms"] = [
            {"form": form, "tags": []}
            for form in dict.fromkeys(entry["forms"])
            if form != word
        ]
    return [entry for entry in entries if entry["senses"]]


def iter_dump_entries(path: Path) -> Iterator[dict[str, Any]]:
    """Stream namespace-0 entries from a Wikimedia pages-articles dump."""
    with bz2.open(path, "rb") as handle:
        for _, page in ElementTree.iterparse(handle, events=("end",)):
            if _local_name(page.tag) != "page":
                continue
            if _child_text(page, "ns") == "0":
                title = _child_text(page, "title")
                text = _child_text(page, "text")
                yield from parse_page(title, text)
            page.clear()
