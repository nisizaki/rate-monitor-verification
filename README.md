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

Time and refill amounts are natural numbers. The monitored send denotes an
abstract fetch invocation, not a network arrival. Dynamic execution creation,
observation completeness, timed instrumentation, and shared-state implementation
are not yet formalized. Retry_Bot is a separate model, not yet a refinement of
Concurrent_Bot or of the TypeScript implementation.

Run `isabelle build -D .` with Isabelle/HOL, or check the theories using the
isabelle-checker service. No network calls to Slack or DeepL are required.
