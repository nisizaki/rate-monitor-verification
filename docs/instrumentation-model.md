# Instrumented retry model

`Instrumented_Retry.thy` connects `Retry_Bot` and `Rate_Monitor` at the
abstract semantics level. For every retry transition, `observed_run` passes
exactly the mapped event to `monitor_step`; it never changes the retry state
or blocks a retry transition, including when the monitor is `None`. Clock
events and dispatches are projected using `bucket_of`; other events map to
`Other`. A run is a finite list of these events.

* `erase_observer` projects every observed run to the same retry run.
* `attach_observer` lifts every retry run and any initial monitor state to an
  observed run with the same event trace and final retry state.
* `observational_correspondence` combines those results with the exact monitor
  result. `rejected_monitor_does_not_block` covers the `None` monitor state.
* `monitor_trace_correct` states equivalence with the existing operational
  bucket semantics on the exact projected trace. `monitor_matches_bucket`
  shows agreement with the actual abstract token state if initialized to it.
  `monitored_rate_bound` applies the existing rate theorem when accepted.

The proofs use exact, complete event delivery and one global abstract timeline
by construction; they do not prove instrumentation of TypeScript, log delivery,
or concurrency safety. Monitor transitions take no additional time in the
model and introduce no exceptions, blocking or failures. No physical timing
transparency or instrumentation overhead is established. This is a passive
observer, not an enforcement mechanism. The monitor and controlled retry
model both use the same bucket semantics; equivalence to an independently
defined arrival curve and refinement of `Concurrent_Bot` remain future work.
