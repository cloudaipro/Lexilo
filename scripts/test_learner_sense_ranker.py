#!/usr/bin/env python3
import unittest

from learner_sense_ranker import ExternalSense, rank_senses


class LearnerSenseRankerTests(unittest.TestCase):
    def test_external_first_sense_can_outvote_kaikki_order(self) -> None:
        senses = [
            {
                "source_id": "abstract",
                "definition": "Any place of shelter.",
                "source_order": 0,
                "tags": [],
                "usage_label": "",
                "examples": [],
            },
            {
                "source_id": "nautical",
                "definition": "A sheltered expanse of water in which ships may anchor or dock.",
                "source_order": 1,
                "tags": [],
                "usage_label": "",
                "examples": [],
            },
        ]
        ranked = rank_senses(
            "harbor",
            "noun",
            senses,
            {
                "simple_wiktionary": {
                    ("harbor", "noun"): [
                        ExternalSense("simple_wiktionary", "simple-nautical", "A protected area of water where ships are safe.", 0),
                        ExternalSense("simple_wiktionary", "simple-abstract", "A place where people or animals are safe.", 1),
                    ]
                },
                "oewn": {
                    ("harbor", "noun"): [
                        ExternalSense("oewn", "oewn-nautical", "a sheltered port where ships can take on or discharge cargo", 0),
                        ExternalSense("oewn", "oewn-abstract", "a place of refuge and comfort and security", 1),
                    ]
                },
            },
        )
        self.assertEqual(ranked[0]["source_id"], "nautical")
        self.assertGreater(ranked[0]["features"]["external_support"], ranked[1]["features"]["external_support"])

    def test_source_order_is_deterministic_fallback(self) -> None:
        senses = [
            {"source_id": "second", "definition": "A second thing.", "source_order": 1, "tags": [], "usage_label": "", "examples": []},
            {"source_id": "first", "definition": "A first thing.", "source_order": 0, "tags": [], "usage_label": "", "examples": []},
        ]
        ranked = rank_senses("sample", "noun", senses, {})
        self.assertEqual([item["source_id"] for item in ranked], ["first", "second"])
        self.assertEqual([item["learner_rank"] for item in ranked], [1, 2])


if __name__ == "__main__":
    unittest.main()
