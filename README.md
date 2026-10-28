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
  a trace from `Prepare` containing `MarkOK` also contains `ReplyOK`. A stronger
  temporal ordering theorem and the relationship to TypeScript remain open.

Time and refill amounts are natural numbers. The monitored send denotes an
abstract fetch invocation, not a network arrival. Parallel execution IDs,
retry/deadline rules, observation completeness, timed instrumentation, and
shared-state implementation are not yet formalized.

Run `isabelle build -D .` with Isabelle/HOL, or check the theories using the
isabelle-checker service. No network calls to Slack or DeepL are required.
