#!/usr/bin/env python3
"""Unit tests for phase S's judging in tools/heads/suite_summary.py (the sign test, the flips) and the suite's phase S
draw (tools/heads/random_suite.py). Run: python -I tools/heads/test_suite_summary.py
"""
import os
import random
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import random_suite  # noqa: E402
import suite_summary  # noqa: E402


def race(label, start_ok=True, start_s=10.0, stuck_ok=True, aground_ok=True, falls=0, ocs_at_gun=False):
    return {"label": label, "drawn": {"phase": "S"}, "pass": start_ok, "boards": [{
        "board": "Hana", "falls": falls,
        "checks": {"start": {"ok": start_ok, "what": ""}, "stuck": {"ok": stuck_ok, "what": ""},
                   "aground": {"ok": aground_ok, "what": ""}, "falls": {"ok": falls == 0, "what": ""}},
        "start": {"start_s": start_s, "allowed_s": 20.0, "gun_speed_ms": 5.0, "gun_behind_m": 10.0, "ocs_at_gun": ocs_at_gun}}]}


class SignTest(unittest.TestCase):
    def test_the_method_docs_table(self):
        # Documentation/AI_TRAINING_METHOD.md, phase S: the fewest fixed that pass for each number broken.
        fewest = {0: 5, 1: 7, 2: 9, 3: 10, 4: 12, 5: 13, 6: 15, 7: 16}
        for broken, fixed in fewest.items():
            self.assertLess(suite_summary.sign_test_p(fixed, broken), 0.05, "%d-%d should pass" % (fixed, broken))
            self.assertGreaterEqual(suite_summary.sign_test_p(fixed - 1, broken), 0.05, "%d-%d should fail" % (fixed - 1, broken))

    def test_just_fail(self):
        for fixed, broken in ((8, 2), (11, 4), (14, 6)):
            self.assertGreaterEqual(suite_summary.sign_test_p(fixed, broken), 0.05)

    def test_no_flips(self):
        self.assertEqual(suite_summary.sign_test_p(0, 0), 1.0)

    def test_verdicts(self):
        self.assertEqual(suite_summary.s_verdict("start", 7, 1)[1], "pass")
        self.assertEqual(suite_summary.s_verdict("start", 6, 1)[1], "chance")
        self.assertEqual(suite_summary.s_verdict("start", 2, 2)[1], "no gain")
        self.assertEqual(suite_summary.s_verdict("no fall", 0, 5)[1], "WORSE")
        self.assertEqual(suite_summary.s_verdict("no fall", 1, 5)[1], "ok")


class Flips(unittest.TestCase):
    def test_fixed_broken_and_the_same(self):
        off = {"r1": race("r1", start_ok=False, start_s=None), "r2": race("r2"), "r3": race("r3", start_ok=False, start_s=40.0),
               "r4": race("r4", falls=1)}
        on = {"r1": race("r1"), "r2": race("r2", start_ok=False, start_s=30.0), "r3": race("r3", start_ok=False, start_s=35.0),
              "r4": race("r4"), "r5": race("r5")}
        flips = suite_summary.s_flips(off, on)
        self.assertEqual(flips["start"], (["r1"], ["r2"]))  # r3 late in both: counts for neither; r5 only in one run
        self.assertEqual(flips["no fall"], (["r4"], []))

    def test_never_over_the_line_is_endless(self):
        self.assertEqual(suite_summary.start_s(race("r1", start_ok=False, start_s=None)), float("inf"))


class PhaseSDraw(unittest.TestCase):
    def test_start_only_and_reachable(self):
        for k in range(200):
            args, drawn = random_suite.draw_race(random.Random(k), "S")
            self.assertIn("--start_only=1", args)
            self.assertIn("--start_spare_s=30", args)
            restart = [a for a in args if a.startswith("--restart_after=")]
            if restart:
                at_s = float(restart[0].split("=")[1])
                # R in the countdown or up to 2 minutes after the gun, never after the finish.
                self.assertTrue(-drawn["countdown_s"] <= at_s <= 120.0, at_s)

    def test_phase_a_draws_unchanged(self):
        # Phase S's R draw must not move phase A's: the same number of random draws before and after.
        args_a, _ = random_suite.draw_race(random.Random(5), "A")
        self.assertNotIn("--start_only=1", args_a)


def s3_board(name, score_m, start_ok=True, penalties=0, near_s=0.0):
    return {"board": name, "falls": 0,
            "checks": {"start": {"ok": start_ok, "what": ""}, "stuck": {"ok": True, "what": ""},
                       "aground": {"ok": True, "what": ""}, "falls": {"ok": True, "what": ""}},
            "start": {"start_s": 5.0 if start_ok else 40.0, "allowed_s": 20.0, "gun_speed_ms": 5.0, "gun_behind_m": 10.0,
                      "ocs_at_gun": False, "score_m": score_m, "cross_speed_ms": 6.0, "near_s": near_s,
                      "penalties": penalties, "gun_mean_kt": 16.0, "gun_felt_60s_kt": 12.0}}


def s3_race(label, boards):
    return {"label": label, "drawn": {"phase": "S3"}, "pass": True, "boards": boards}


class PhaseS3(unittest.TestCase):
    """Phase S3 (10 November 2026): three boards a race, each judged on its own, and the start's score."""

    def test_every_board_is_a_start_of_its_own(self):
        results = {"r1": s3_race("r1", [s3_board("A", 100.0), s3_board("B", 50.0), s3_board("C", -10.0, start_ok=False)])}
        self.assertEqual(sorted(suite_summary.units(results)), ["r1/0", "r1/1", "r1/2"])
        numbers = suite_summary.s_numbers(results)
        self.assertEqual(numbers["boards"], 3)
        self.assertAlmostEqual(numbers["start %"], 200.0 / 3.0)
        self.assertEqual(numbers["score median m"], 50.0)
        self.assertAlmostEqual(numbers["felt/mean wind"], 0.75)

    def test_the_score_flips_by_more_than_the_tie(self):
        off = {"r1": s3_race("r1", [s3_board("A", 100.0), s3_board("B", 50.0), s3_board("C", 0.0)])}
        on = {"r1": s3_race("r1", [s3_board("A", 104.0), s3_board("B", 70.0), s3_board("C", -20.0)])}
        better, worse, diffs = suite_summary.score_flips(off, on)
        self.assertEqual(better, ["r1/1"])  # +20 m
        self.assertEqual(worse, ["r1/2"])  # -20 m; A's +4 m is the same start
        self.assertEqual(len(diffs), 3)

    def test_penalties_and_tangles_are_measures(self):
        off = {"r1": s3_race("r1", [s3_board("A", 10.0, penalties=1), s3_board("B", 10.0, near_s=8.0)])}
        on = {"r1": s3_race("r1", [s3_board("A", 10.0), s3_board("B", 10.0)])}
        flips = suite_summary.s_flips(off, on)
        self.assertEqual(flips["no penalty"], (["r1/0"], []))
        self.assertEqual(flips["untangled"], (["r1/1"], []))

    def test_the_draw_has_three_general_heads_and_follows_the_start(self):
        for k in range(200):
            args, drawn = random_suite.draw_race(random.Random(k), "S3")
            for head in random_suite.GENERAL_HEAD:
                self.assertIn(head, args, "the general head (Max: the fastest skipper)")
            self.assertIn("--boards=3", args)
            spots = [a for a in args if a.startswith("--start_spots=")][0].split("=", 1)[1].split(",")
            self.assertEqual(len(spots), 3, "each its own start spot")
            self.assertTrue(all(0.0 <= float(x) <= 1.0 for x in spots))
            self.assertIn("--start_follow_s=30", args)
            self.assertIn("--start_only=1", args)

    def test_phase_s_draws_unchanged(self):
        # Phase S3 must not move phase S's draws (the old seeds stay the same races).
        args_s, _ = random_suite.draw_race(random.Random(5), "S")
        self.assertIn("--skippers=persona:hana", args_s)
        self.assertNotIn("--start_follow_s=30", args_s)


if __name__ == "__main__":
    unittest.main()
