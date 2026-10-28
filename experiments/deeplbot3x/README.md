# DeepLbot3x experimental app preparation

This is a separate experimental copy of `nisizaki/deeplbot3`, based on commit `b4eb35ba464ebde9e4fad89c387c68653cc76dac`. `experiment.patch` applies to that exact commit and adds an experiment observer, unit tests, and a channel/workspace guard. No existing Slack app is linked to or changed by this patch. A distinct `DeepLbot3x` app was deployed and installed to the designated workspace grant. One event trigger was created, a key was set by the user, and app membership in the test channel was confirmed.

The working copy uses a local-only `app.local.ts` to name the new app `DeepLbot3x`. The Function fails closed unless `EXPERIMENT_WORKSPACE_ID`, `EXPERIMENT_CHANNEL_ID`, `EXPERIMENT_MODE`, and a non-default `DEEPL_TRIGGER_EMOJI` are supplied. The intended runtime modes are `baseline`, `record`, and `monitor`. The mode is controlled by the new app's environment. Keep IDs and secrets outside Git. Verify the new app's actual identity, target grant, app membership and emoji behavior; never select the pre-existing DeepLbot3 app.

On 2026-10-28, three initial synthetic test messages with the designated reaction started the workflow and Function. Each initial run ended with `failed_translation_network_not_capable`; no successful translation or reply was observed in those runs. The second run followed a redeployment using the local manifest, and the third explicitly selected the API Free endpoint. The remote manifest lists both DeepL endpoints in `outgoing_domains`; the CLI reported no install approval request. These facts do not establish the runtime permission cause or prove whether any HTTP request reached DeepL. The user confirmed a Free plan; do not infer a rate limit or billing outcome from the errors.

After the user approved the experimental app, it was redeployed and the Free endpoint was used in three successful smoke tests, one per mode. The Function output `translated` in each case; the record and monitor modes each emitted one `fetch_invocation`, and the monitor reported `accepted=true`. The logged service-call elapsed times were 2713.55 ms (baseline), 1579.68 ms (record), and 1546.88 ms (monitor); the logged observer computation times for the latter two were approximately 0.0022 and 0.0047 ms, respectively. Each measurement is a single execution on different text; they are not controlled comparisons and cannot estimate overhead or prove completeness. Observer computation time excludes logging. No general conclusions about DeepL rate limits or implementation refinement follow. Although success followed approval and redeployment, this observation alone does not establish the cause of the prior failure.

The observer is per Function execution, with a capacity-one, zero-refill monitor. It reports extra fetches within that one execution but cannot enforce or monitor a global rate across multiple Functions. Its clock is local to an execution; timestamps from different executions cannot be assumed comparable. `observer_ms` excludes the cost of emitting the log and should not be interpreted as total instrumentation overhead. `elapsed_ms` covers the service call after the guard and is not the full Slack platform lifecycle. Event logs omit message text, credentials, and identifiers; without independent event correlation, they cannot establish completeness. The original client's requester attribution and usage audit behavior remain in the separate app; review the implications before use.

The original preparation passed 151 local mocked tests. That original patch is retained as `experiment-initial.patch` for historical provenance; it has the observation exception defects described below and must not be applied on top of the current patch. The current preparation and offline validation supersede that local test result, not the historical deployed smoke evidence.


## Current preparation: observation exception isolation

The current `experiment.patch` applies directly to the exact base above. Do not stack it on the initial patch. It adds common trace correlation and translation measurements in all three modes, and isolates synchronous observation faults from translator/fetch execution. UUID, clock or character-count failures become missing values; error classification cannot replace an original rejection. Existing workspace/channel/mode/emoji guards remain fail-closed. The patch contains no local app identity, workspace IDs, authentication or environment files.

The new code has only been tested locally. It has not been deployed and the earlier smoke results do not validate this candidate. Baseline now includes common UUID, timing, codepoint counting, exception protection and log emission overhead. It is not an uninstrumented control. An independent invocation denominator is still absent: observation completeness remains unknown.

### Reproduce offline validation

Use a disposable clean checkout of `nisizaki/deeplbot3` at the exact base. Supply an absolute path to this research checkout:

```sh
git apply --check "$RESEARCH/experiments/deeplbot3x/experiment.patch"
git apply "$RESEARCH/experiments/deeplbot3x/experiment.patch"
deno fmt --check
deno lint
deno test --cached-only --deny-net --deny-env --deny-run --deny-write --allow-read --permit-no-files
cd "$RESEARCH/experiments/deeplbot3x"
python3 -m unittest -v test_safe_log_filter.py
```

Deno 2.9.8 was used with an already populated dependency cache. A cold cache requires separately fetching the project's pinned dependencies before this offline command; tests must not call Slack or DeepL. Applying the patch does not link an app or authorize deployment. Never use the production app for this preparation.

See `repair-report.md`, `validation.json` and `source-identity.json` for the exact source scope and test evidence. The public patch excludes local-only app naming/configuration, so its hash differs from the isolated runtime's 36-file identity.

### Metadata collector

`safe_log_filter.py` accepts bounded JSON lines (or a JSON wrapper with a message field), selects one non-secret trial UUID and mode, and outputs allowlisted metadata only. Do not save raw platform output; verify a platform log adapter separately before live use.

```sh
python3 safe_log_filter.py --trial-id "$TRIAL_UUID" --mode baseline --expected-invocations 1
```

Missing run identity causes line rejection. Missing timings are excluded from distributions. If no character measurement exists, the observed character sum is null, not zero; partial sums are not total API usage. The planned count is labelled `operator_plan`, not independent evidence of complete observation. Baseline fetch observations, actual retries and API-reported billed usage remain unknown where unavailable.

The exact offline public-patch result is 165 Deno tests and 7 Python tests, all passing. See `deployment-smoke-plan-ja.md` for the proposed approval-gated deployment, abort and three-shot smoke procedure. `check_deepl_free_usage.py` is a manual private-terminal helper; it is not run by the test suite. Account-specific usage snapshots stay outside this repository.

See `stage1-preparation-ja.md` for the fixed candidate, durable-state design, review-gated stages and stop thresholds. Smoke (3), pilot (up to 30), and main (360) are separate datasets: 393 total, not 390 when smoke is included. No runner, scheduler, deployment or live trial was started by this preparation.
