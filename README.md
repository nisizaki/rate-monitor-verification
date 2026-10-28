# Rate monitor verification

Isabelle/HOL models for the DeepLbot3 rate-monitoring research. These theories
are mathematical abstractions; they do not verify the TypeScript implementation.

* `Rate_Bucket.thy` defines discrete-time token-bucket transitions and proves
  the finite-run accounting and rate bounds.
* `Rate_Monitor.thy` defines a non-blocking trace checker and proves equivalence
  with the bucket transition relation, plus the accepted-trace rate bound.
  This equivalence uses the operational bucket semantics as its specification;
  an independent arrival-curve specification remains future work.
* `Bot_Order.thy` models a single execution's abstract stages and proves that
  `ReplyOK` precedes `MarkOK` in a trace from `Prepare`.
* `Bot_Rate.thy` synchronizes bot actions with bucket events and proves an
  upper bound on `SendRequest` events in any finite product-model run.
  See `docs/implementation-correspondence.md` for implementation mapping.
* `Concurrent_Bot.thy` models interleaved bot actions with a shared bucket,
  proves the global rate bound and gives a two-client independent-bucket
  counterexample. `docs/concurrent-model.md` describes its assumptions.
* `Retry_Bot.thy` models per-job attempts, retry eligibility, deadlines, quota
  and timeout events against a shared bucket. `docs/retry-model.md` describes
  the formalized properties and the boundaries of this separate model.
* `Instrumented_Retry.thy` attaches a passive monitor to the retry model and
  proves trace preservation and monitor correspondence. Its observation and
  timing assumptions are documented in `docs/instrumentation-model.md`.
* `Permit_Delay.thy` relates permit and fetch timestamps and proves a
  delay-adjusted rate bound and a counterexample to the unchanged bound; see
  `docs/permit-delay.md` for assumptions and remaining connections.
* `Permit_Operational.thy` separates granting, fetching, and cancelling permits;
  `Permit_Bridge.thy` gives a conditional connection to the concurrent model.
  See `docs/permit-bridge.md` for the still-unproved correspondence assumptions.
* `Correspondence_Examples.thy` verifies three concrete monitor results used in
  the DeepLbot3 Deno experiments, described in `experiments/README.md`.

Time and refill amounts are natural numbers. The monitored send denotes an
abstract fetch invocation, not a network arrival. Dynamic execution creation,
observation completeness, timed instrumentation, and shared-state implementation
are not yet formalized. Retry_Bot and Permit_Delay are separate models, not yet
connected by a refinement proof to each other or to the TypeScript code.

Run `isabelle build -D .` with Isabelle/HOL, or check the theories using the
isabelle-checker service. No network calls to Slack or DeepL are required.
