"""
Regression test for judge.py _OPS["in"] operator bug.

Bug (pre-fix): _OPS["in"] is hard-coded as a 2-element numeric range check
(b[0] <= a <= b[1]). Any contract using "operator": "in" with a >2-element
list, a boolean list, or a non-numeric list silently returns False.

Run from repo root:
  python3 -m unittest .claude/scripts/tests/test_judge_in_operator.py -v
"""

import sys, os, unittest
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from judge import _OPS


class TestInOperatorPreFix(unittest.TestCase):
    """Pre-fix: assertFalse confirms the bug is present before the fix."""

    def test_bug_3element_string_list(self):
        self.assertFalse(
            _OPS["in"](
                "REJECT-WITH-RATIONALE",
                ["ACCEPT-TO-ACTIVE", "REJECT-WITH-RATIONALE", "REVISE-AND-RESUBMIT"]
            )
        )

    def test_bug_2element_boolean_list(self):
        self.assertFalse(_OPS["in"](True, [True, False]))


class TestInOperatorPostFix(unittest.TestCase):
    """Post-fix: all assertions must pass after the fix is applied."""

    def test_string_in_3element_list_match(self):
        self.assertTrue(
            _OPS["in"](
                "REJECT-WITH-RATIONALE",
                ["ACCEPT-TO-ACTIVE", "REJECT-WITH-RATIONALE", "REVISE-AND-RESUBMIT"]
            )
        )

    def test_string_in_3element_list_no_match(self):
        self.assertFalse(
            _OPS["in"]("NOPE", ["ACCEPT-TO-ACTIVE", "REJECT-WITH-RATIONALE", "REVISE-AND-RESUBMIT"])
        )

    def test_string_in_2element_string_list_first(self):
        self.assertTrue(_OPS["in"]("ACCEPT-TO-ACTIVE", ["ACCEPT-TO-ACTIVE", "REJECT-WITH-RATIONALE"]))

    def test_string_in_2element_string_list_second(self):
        self.assertTrue(_OPS["in"]("REJECT-WITH-RATIONALE", ["ACCEPT-TO-ACTIVE", "REJECT-WITH-RATIONALE"]))

    def test_string_in_2element_string_list_no_match(self):
        self.assertFalse(_OPS["in"]("NOPE", ["ACCEPT-TO-ACTIVE", "REJECT-WITH-RATIONALE"]))

    def test_bool_true_in_bool_list(self):
        self.assertTrue(_OPS["in"](True, [True, False]))

    def test_bool_false_in_bool_list(self):
        self.assertTrue(_OPS["in"](False, [True, False]))

    def test_range_within(self):
        self.assertTrue(_OPS["in"](0.5, [0.0, 1.0]))

    def test_range_outside(self):
        self.assertFalse(_OPS["in"](2.0, [0.0, 1.0]))

    def test_range_at_lower_bound(self):
        self.assertTrue(_OPS["in"](0.0, [0.0, 1.0]))

    def test_range_at_upper_bound(self):
        self.assertTrue(_OPS["in"](1.0, [0.0, 1.0]))

    def test_range_integer(self):
        self.assertTrue(_OPS["in"](3, [1, 5]))

    def test_range_integer_outside(self):
        self.assertFalse(_OPS["in"](6, [1, 5]))

    def test_3element_float_list_no_match(self):
        self.assertFalse(_OPS["in"](0.5, [0.0, 1.0, 2.0]))

    def test_3element_float_list_match(self):
        self.assertTrue(_OPS["in"](1.0, [0.0, 1.0, 2.0]))

    def test_out_string_not_in_list(self):
        self.assertTrue(
            _OPS["out"]("NOPE", ["ACCEPT-TO-ACTIVE", "REJECT-WITH-RATIONALE", "REVISE-AND-RESUBMIT"])
        )

    def test_out_string_in_list(self):
        self.assertFalse(
            _OPS["out"]("ACCEPT-TO-ACTIVE", ["ACCEPT-TO-ACTIVE", "REJECT-WITH-RATIONALE", "REVISE-AND-RESUBMIT"])
        )

    def test_out_range_outside(self):
        self.assertTrue(_OPS["out"](2.0, [0.0, 1.0]))

    def test_out_range_inside(self):
        self.assertFalse(_OPS["out"](0.5, [0.0, 1.0]))

    def test_empty_list_no_crash(self):
        self.assertFalse(_OPS["in"]("anything", []))

    def test_non_list_target(self):
        self.assertFalse(_OPS["in"]("x", "xyz"))


if __name__ == "__main__":
    unittest.main()
