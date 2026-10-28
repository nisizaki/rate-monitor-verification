# TypeScript correspondence experiments

Run from the repository root with Deno installed:

```sh
deno test --no-config experiments/correspondence_test.ts
```

No environment, network, filesystem, or subprocess permission is requested. The tests use a fixed copy of the actual DeepLbot3 client and its error definitions, imported from `experiments/fixtures/deeplbot3/`. These are unmodified files from commit `b4eb35ba464ebde9e4fad89c387c68653cc76dac`, distributed with the upstream MIT license included there. The upstream repository is https://github.com/nisizaki/deeplbot3.

The observer wraps the injected `fetchFn`; it records only an anonymous test ID and virtual invocation time. It forwards the original inputs to the mock and does not inspect or record request or response contents. The fake credential and input are test-only; there is no connection to Slack or DeepL. The injected clock controls recorded invocation times and test-driven aborts; it does not virtualize the Deno runtime or the application's timers. For the timeout test, an explicit `AbortController` models a client-observed abort and does not prove anything about server-side cancellation.

Cases include success, HTTP 429 and 456, invalid JSON, invalid translation data, transport failure, missing credentials, an injected abort, observer-on/off comparisons, and two concurrent invocations. Each HTTP failure results in a single invocation: the actual client in this commit does not retry. Two simultaneous invocations illustrate that the current client does not enforce a shared capacity-one budget.

The test-side `monitor` is a handwritten TypeScript transcription of `Rate_Monitor.monitor_step` for the small natural-number test cases. `Correspondence_Examples.thy` proves the outcomes for three matching traces in Isabelle. The test compares these results and observations; this is not code generated from Isabelle, a proof of equivalence for all inputs, or a proof that the original client implements a limiter. JavaScript numeric precision and parameter validation are not addressed for arbitrary values. The observer logs the `fetchFn` invocation, not network arrival or permit grant. Observer-on/off equality is empirical for the tested branches and does not establish timing preservation.

The retry model, `Permit_Operational`, and `Permit_Bridge` describe proposed behavior absent from this version of the bot. They are not directly validated by these client tests. A complete step 7 still requires an executable reference model linked to the Isabelle relations, a prospective controlled client implementation, and conformance scenarios for retries, permit delay, and deadline behavior. The `window_correspondence` assumption and the connection between retry and permit models remain open. Real Slack instrumentation and overhead measurement are subsequent work.
