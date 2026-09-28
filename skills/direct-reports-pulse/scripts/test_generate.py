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

    def test_week_windows_use_previous_complete_week_on_monday(self):
        windows = MODULE.week_windows(datetime(2026, 9, 28, 12, tzinfo=timezone.utc))

        self.assertEqual(windows[-1]["start"].isoformat(), "2026-09-21")
        self.assertEqual(windows[-1]["end"].isoformat(), "2026-09-27")
        self.assertFalse(windows[-1]["current"])
        self.assertEqual(MODULE.latest_period_name(windows[-1]), "latest seven-day period")

    def test_week_windows_use_current_week_to_date_after_monday(self):
        windows = MODULE.week_windows(datetime(2026, 9, 29, 12, tzinfo=timezone.utc))

        self.assertEqual(windows[-1]["start"].isoformat(), "2026-09-28")
        self.assertEqual(windows[-1]["end"].isoformat(), "2026-10-04")
        self.assertTrue(windows[-1]["current"])
        self.assertEqual(MODULE.latest_period_name(windows[-1]), "current week-to-date")

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

    def test_html_renders_person_details_inline(self):
        now = datetime(2026, 9, 16, tzinfo=timezone.utc)
        people = [MODULE.Person("a", "Person A", "Area")]
        rows = [{
            "author": "a",
            "created": "2026-09-14T10:00:00Z",
            "closed": "2026-09-15T10:00:00Z",
            "status": "completed",
            "isTrunk": True,
            "isChore": False,
            "mergeHours": 24.0,
            "repository": "repo",
            "url": "https://example.test/pr/1",
            "title": "Example PR",
        }]
        html = MODULE.render_html("Manager", people, rows, MODULE.week_windows(now), now)
        self.assertIn('class="detail-row"', html)
        self.assertIn("detailHtml(x.person.alias,p)", html)
        self.assertNotIn('id="details"', html)
        self.assertNotIn('id="drillTitle"', html)

    def test_monday_summary_describes_latest_seven_day_period(self):
        now = datetime(2026, 9, 28, 12, tzinfo=timezone.utc)
        text = MODULE.summary([], MODULE.week_windows(now), now, "Manager")

        self.assertIn("in the latest seven-day period", text)
        self.assertNotIn("current week-to-date", text)


if __name__ == "__main__":
    unittest.main()
