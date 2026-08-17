#!/usr/bin/env python3
import unittest

from simple_wiktionary_dump import parse_page


class SimpleWiktionaryDumpTests(unittest.TestCase):
    def test_extracts_pos_definitions_examples_pronunciation_and_forms(self) -> None:
        entries = parse_page(
            "dictionary",
            """=== Pronunciation ===
* {{UK}} {{IPA|/dɪkʃən(ə)ri/}}
* {{US}} {{IPA|/dɪkʃənˌɛri/}}

== Noun ==
{{noun|2=dictionaries}}
# {{countable}} A '''dictionary''' is a book that tells you what words mean.
#: ''You are reading an online '''dictionary''' right now.''
""",
        )

        self.assertEqual(len(entries), 1)
        entry = entries[0]
        self.assertEqual(entry["pos"], "noun")
        self.assertEqual(entry["forms"][0]["form"], "dictionaries")
        self.assertEqual(entry["sounds"][0]["tags"], ["UK"])
        self.assertEqual(entry["senses"][0]["tags"], ["countable"])
        self.assertEqual(entry["senses"][0]["glosses"], ["A dictionary is a book that tells you what words mean."])
        self.assertEqual(entry["senses"][0]["examples"][0]["text"], "You are reading an online dictionary right now.")
        self.assertIn("bold_text_offsets", entry["senses"][0]["examples"][0])

    def test_extracts_multiple_supported_pos_sections(self) -> None:
        entries = parse_page(
            "run",
            """== Verb ==
{{verb2|run|runs|ran|run|running}}
# If you '''run''', you go quickly.
#: ''I like to '''run''' in the afternoon.''

== Noun ==
{{noun}}
# A trip made by a runner.
#: ''I’m going for a '''run'''.''
""",
        )

        self.assertEqual([entry["pos"] for entry in entries], ["verb", "noun"])
        self.assertEqual(entries[0]["forms"], [{"form": "runs", "tags": []}, {"form": "ran", "tags": []}, {"form": "running", "tags": []}])
        self.assertEqual(len(entries[1]["senses"]), 1)


if __name__ == "__main__":
    unittest.main()
