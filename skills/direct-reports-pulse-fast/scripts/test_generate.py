from __future__ import annotations

import importlib.util
import sys
import unittest
from datetime import datetime, timezone
from pathlib import Path

MODULE_PATH = Path(__file__).with_name("generate.py")
SPEC = importlib.util.spec_from_file_location("pulse_generate", MODULE_PATH)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class GenerateTests(unittest.TestCase):
    def test_normalize_manager_accepts_email(self):
        self.assertEqual(MODULE.normalize_manager("Manager@Microsoft.com"), "manager")

    def test_nearest_rank_matches_lower_median(self):
        self.assertEqual(MODULE.nearest_rank([1, 2, 3, 4], 0.5), 2)
        self.assertEqual(MODULE.nearest_rank([1, 2, 3, 4, 5], 0.8), 4)

    def test_period_metrics_assigns_opened_and_merged_by_own_timestamps(self):
        now = datetime(2026, 9, 16, tzinfo=timezone.utc)
        rows = [
            {
                "author": "a",
                "created": "2026-09-14T10:00:00Z",
                "closed": "2026-09-15T10:00:00Z",
                "status": "completed",
                "isTrunk": True,
                "isChore": False,
                "mergeHours": 24.0,
            },
            {
                "author": "b",
                "created": "2026-09-01T10:00:00Z",
                "closed": "2026-09-14T12:00:00Z",
                "status": "completed",
                "isTrunk": True,
                "isChore": False,
                "mergeHours": 100.0,
            },
        ]
        result = MODULE.period_metrics(
            rows,
            datetime(2026, 9, 14).date(),
            datetime(2026, 9, 20).date(),
            now,
        )
        self.assertEqual(result["opened"], 1)
        self.assertEqual(result["merged"], 2)
        self.assertEqual(result["contributors"], 2)
        self.assertEqual(result["median"], 24.0)


if __name__ == "__main__":
    unittest.main()
