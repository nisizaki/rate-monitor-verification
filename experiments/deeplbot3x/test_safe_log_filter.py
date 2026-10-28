import json
import unittest
from safe_log_filter import collect, sanitize
TRIAL = "00000000-0000-4000-8000-000000000001"
RUN = "00000000-0000-4000-8000-000000000002"
def event(seq=0, **kw):
    return dict(schema_version=2, trial_id=TRIAL, run_id=RUN, seq=seq, mode="baseline", kind="experiment_result", **kw)
class CollectorTests(unittest.TestCase):
    def test_secret_and_usage_not_copied(self):
        row = event(result_code="translated", elapsed_ms=3, arbitrary="SENSITIVE_SENTINEL")
        out = collect([json.dumps(row)], TRIAL, "baseline", 1)
        self.assertNotIn("SENSITIVE_SENTINEL", json.dumps(out))
        self.assertIsNone(out["summary"]["fetch_events"])
        self.assertIsNone(out["summary"]["api_reported_usage_delta"])
    def test_drop_duplicate_gap_and_missing(self):
        row = json.dumps(event(2, result_code="translated"))
        out = collect(["invalid", row, row], TRIAL, "baseline", 2)["summary"]
        self.assertEqual(out["counts"]["rejected_lines"], 1)
        self.assertEqual(out["counts"]["duplicate_events"], 1)
        self.assertEqual(out["sequence_gaps"], 2)
        self.assertEqual(out["missing_results_vs_plan"], 1)
        self.assertEqual(out["observation_completeness"], "unknown")
    def test_wrapper_scope_and_nonfinite(self):
        row = event(elapsed_ms=float("nan"), result_code="SENSITIVE_SENTINEL")
        out = sanitize(json.dumps({"message": json.dumps(row)}), TRIAL, "baseline")
        self.assertNotIn("elapsed_ms", out)
        self.assertEqual(out["result_code"], "unclassified")
        with self.assertRaises(ValueError): sanitize(json.dumps(row), TRIAL, "monitor")
    def test_429_and_usage_unknown(self):
        row = event(http_status=429, outcome="failure", submitted_codepoints=2, api_billed_characters=999)
        row["kind"] = "translation_result"
        out = collect([json.dumps(row)], TRIAL, "baseline", 1)
        self.assertEqual(out["summary"]["http_429"], 1)
        self.assertEqual(out["summary"]["submitted_codepoints_observed"], 2)
        self.assertIsNone(out["events"][0]["api_billed_characters"])
    def test_missing_measurements_are_not_zero(self):
        row = event(submitted_codepoints=None, translation_ms=None)
        row["kind"] = "translation_result"
        result = collect([json.dumps(row)], TRIAL, "baseline", 1)["summary"]
        self.assertIsNone(result["submitted_codepoints_observed"])
        self.assertEqual(result["character_measurements"], 0)
        self.assertEqual(result["missing_character_measurements"], 1)
        self.assertEqual(result["latency_ms"]["translation_ms"]["n"], 0)
        row["submitted_codepoints"] = 0
        result = collect([json.dumps(row)], TRIAL, "baseline", 1)["summary"]
        self.assertEqual(result["submitted_codepoints_observed"], 0)
        self.assertEqual(result["character_measurements"], 1)
    def test_missing_run_identity_is_rejected(self):
        row = event()
        row["run_id"] = None
        result = collect([json.dumps(row)], TRIAL, "baseline", 1)["summary"]
        self.assertEqual(result["counts"]["rejected_lines"], 1)
        self.assertEqual(result["counts"]["accepted_events"], 0)
        self.assertEqual(result["observation_completeness"], "unknown")
    def test_empty_results(self):
        out = collect([], TRIAL, "monitor", 1)["summary"]
        self.assertEqual(out["missing_results_vs_plan"], 1)
        self.assertIsNone(out["latency_ms"]["elapsed_ms"]["p50"])
if __name__ == "__main__": unittest.main()
