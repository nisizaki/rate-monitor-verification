"""Strict metadata-only collector. Raw input is never echoed or persisted."""
import argparse
import collections
import json
import math
import re
import sys

UUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")
KINDS = {"experiment_start", "experiment_result", "translation_result", "fetch_invocation"}
NUMBERS = {"elapsed_ms", "translation_ms", "observed_at_ms", "observer_ms",
           "submitted_codepoints", "bucket_capacity", "refill_rate", "retries_configured", "emit_failures"}
ENUMS = {"outcome": {"success", "failure", "timeout"},
         "fetch_observation": {"absent", "enabled"}, "usage_provenance": {"unavailable"}}
# Audited result codes, not an unrestricted string field.
RESULTS = {"translated", "translated_reaction_failed", "translated_usage_record_failed",
 "experiment_filtered", "ignored_wrong_reaction", "ignored_bot_message",
 "ignored_already_translated", "failed_auth_identity", "failed_message_fetch",
 "failed_missing_text", "failed_emoji_list", "failed_translation_missing_auth_key",
 "failed_translation_http_429", "failed_translation_http_456", "failed_translation_http",
 "failed_translation_invalid_json", "failed_translation_invalid_response", "failed_translation", "failed_translation_timeout",
 "failed_translation_network_not_capable", "failed_translation_unknown",
 "failed_post"}

def sanitize(line, trial_id, mode):
    item = json.loads(line)
    if isinstance(item, dict) and isinstance(item.get("message"), str):
        item = json.loads(item["message"])
    if not isinstance(item, dict) or item.get("schema_version") != 2:
        raise ValueError("schema")
    if item.get("trial_id") != trial_id or item.get("mode") != mode:
        raise ValueError("out_of_scope")
    if item.get("kind") not in KINDS or not UUID.fullmatch(str(item.get("run_id", ""))):
        raise ValueError("identity")
    if type(item.get("seq")) is not int or not 0 <= item["seq"] <= 100000:
        raise ValueError("sequence")
    safe = {k: item[k] for k in ("schema_version", "trial_id", "run_id", "mode", "kind", "seq")}
    for key in NUMBERS:
        value = item.get(key)
        if type(value) in (int, float) and math.isfinite(value) and 0 <= value <= 1e12:
            safe[key] = value
    for key, allowed in ENUMS.items():
        if item.get(key) in allowed:
            safe[key] = item[key]
    if "result_code" in item:
        value = item["result_code"]
        safe["result_code"] = value if isinstance(value, str) and value in RESULTS else "unclassified"
    if type(item.get("accepted")) is bool:
        safe["accepted"] = item["accepted"]
    status = item.get("http_status")
    if type(status) is int and 100 <= status <= 599:
        safe["http_status"] = status
    # Current app does not collect API billing, regardless of untrusted input.
    if item["kind"] == "translation_result":
        safe["api_billed_characters"] = None
        safe["usage_provenance"] = "unavailable"
    return safe

def percentiles(values):
    values = sorted(values)
    if not values:
        return {"n": 0, "p50": None, "p95": None, "p99": None}
    # Nearest rank, no interpolation.
    return {"n": len(values), **{f"p{p}": values[max(0, math.ceil(p / 100 * len(values)) - 1)] for p in (50, 95, 99)}}

def collect(lines, trial_id, mode, expected):
    counts = collections.Counter()
    events, seen, runs = [], set(), collections.defaultdict(set)
    for line in lines:
        if counts["input_lines"] >= 10000:
            counts["collection_truncated"] = 1
            break
        counts["input_lines"] += 1
        try:
            if len(line) > 16384:
                raise ValueError("oversized")
            event = sanitize(line, trial_id, mode)
        except (ValueError, TypeError, RecursionError):
            counts["rejected_lines"] += 1
            continue
        key = (event["run_id"], event["seq"])
        if key in seen:
            counts["duplicate_events"] += 1
            continue
        seen.add(key)
        runs[event["run_id"]].add(event["seq"])
        events.append(event)
    results = [e for e in events if e["kind"] == "experiment_result"]
    translations = [e for e in events if e["kind"] == "translation_result"]
    starts = [e for e in events if e["kind"] == "experiment_start"]
    counts.update({"accepted_events": len(events), "observed_invocations": len(runs),
                   "start_events": len(starts), "result_events": len(results),
                   "translation_events": len(translations)})
    gaps = sum(max(seq) + 1 - len(seq) for seq in runs.values())
    measured_chars = [e["submitted_codepoints"] for e in translations if "submitted_codepoints" in e]
    summary = {
        "trial_id": trial_id, "mode": mode, "counts": dict(counts),
        "expected_invocations": expected, "denominator_provenance": "operator_plan",
        "missing_results_vs_plan": max(0, expected - len(results)),
        "excess_results_vs_plan": max(0, len(results) - expected),
        "sequence_gaps": gaps, "observation_completeness": "unknown",
        "missingness_caveat": "planned denominator cannot detect all unobserved invocations",
        "fetch_events": None if mode == "baseline" else sum(e["kind"] == "fetch_invocation" for e in events),
        "actual_retries": None, "retry_policy": "none_in_pinned_client",
        "http_429": sum(e.get("http_status") == 429 for e in translations),
        "http_456": sum(e.get("http_status") == 456 for e in translations),
        "result_codes": dict(collections.Counter(e.get("result_code", "unclassified") for e in results)),
        "translation_outcomes": dict(collections.Counter(e.get("outcome", "unknown") for e in translations)),
        "submitted_codepoints_observed": sum(measured_chars) if measured_chars else None,
        "character_measurements": len(measured_chars),
        "character_count_scope": "observed_translation_inputs_after_placeholder_processing",
        "missing_character_measurements": sum("submitted_codepoints" not in e for e in translations),
        "api_reported_usage_delta": None,
        "api_usage_provenance": "unavailable",
        "latency_ms": {k: percentiles([e[k] for e in events if k in e])
                       for k in ("elapsed_ms", "translation_ms", "observer_ms")},
    }
    return {"events": events, "summary": summary}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--trial-id", required=True)
    parser.add_argument("--mode", choices=("baseline", "record", "monitor"), required=True)
    parser.add_argument("--expected-invocations", type=int, default=1)
    args = parser.parse_args()
    if not UUID.fullmatch(args.trial_id) or args.expected_invocations < 0:
        parser.error("invalid non-secret trial UUID or expected count")
    # Bounded line reads avoid retaining oversized log lines; each chunk is rejected.
    lines = iter(lambda: sys.stdin.readline(16385), "")
    print(json.dumps(collect(lines, args.trial_id, args.mode, args.expected_invocations), indent=2, allow_nan=False))

if __name__ == "__main__":
    main()
