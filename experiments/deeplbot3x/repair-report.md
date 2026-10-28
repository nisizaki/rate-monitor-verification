# Observation exception repair: local evidence
The candidate preserves translator/fetch call counts and original outcomes under tested synchronous observation faults. UUID, time and codepoint failures become missing values. Classifier errors cannot replace arbitrary rejection identities. Service log serialization/output is best effort; target guards remain fail-closed.

The original eight audit scenarios are now regression checks, plus nonfinite/reversed time and unusual synchronous/rejected fetch outcomes. A separate service logger regression is included. The isolated source passed 155 ordinary tests and 10 fault tests; the public patch incorporates those fault tests into the normal suite and passed 165 tests on a clean exact baseline. Seven collector tests passed. No real Slack/DeepL calls, deployment or settings changes were performed.

The public patch excludes local Slack associations and app-local identity. Only fault-test import paths/formatting differ from the externally located tested audit. Every patched file hash was verified after applying the patch. The initial validation found one import formatting difference after relocation; the final patch fixed it and passed fmt, lint and the full offline suite.

UUID failure produces null run identity, rejected by the collector. Missing numeric fields do not enter distributions. No valid character measurements gives null, not zero. Partial observed sums are not account billing. Baseline includes common instrumentation overhead and completeness remains unknown without an independent denominator.

Limits: process termination, OOM, nonterminating observers, asynchronous sink rejection and delivery loss are not covered. translationProbe preserves values/rejections, not translator Promise identity; observedFetch directly preserves the returned Promise. Deployed source equivalence and rollback remain unverified. No new scope or runtime configuration change is part of the repair.

See source-identity.json and validation.json for exact patch/base and validation commands; deployment-smoke-plan-ja.md is a future approval-gated procedure, not an execution record. Original patch history is retained separately.
