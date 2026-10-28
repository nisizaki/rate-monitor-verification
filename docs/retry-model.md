# Retry and deadline model

`Retry_Bot.thy` is a standalone shared-token operational model, extending the
bucket semantics with per-ID job status (`Waiting`, `Active`, `Finished`),
attempt count, next eligible time and dispatch deadline. It is not yet proved
to refine or extend `Concurrent_Bot.thy` and is not an implementation proof.

`Dispatch i` requires a waiting job, attempts below K, sufficient tokens,
`retry_at <= now`, and `now < deadline`. Each dispatch consumes one token,
increments attempts, and enters `Active`. `Advance d` adds natural-number time
and replenishes the shared bucket. An active job receiving `RateLimited i b h`
returns to waiting with `retry_at = now + max b h` when attempts remain, and
otherwise finishes. `QuotaExceeded`, `TimedOut`, and `Success` finish an active
job; `Expire` finishes a waiting job at or after the deadline. Timeout is a
client observation and gives no guarantee about server cancellation or billing.
`h` is an already interpreted wait duration; parsing HTTP headers and actual
backoff algorithms are outside this model.

The checked results are `dispatch_guards`, `retry_run_projection`,
`retry_rate_bound`, `bounded_run`, `attempts_account`, `attempts_limit`,
`limited_wait`, `quota_finishes`, `timeout_finishes`, `finished_run`, and
`finished_no_dispatch`. `attempts_limit` assumes all jobs' counters initially
do not exceed K and the selected job initially has zero attempts. The rate
bound counts initial sends and retries together. Finished status is absorbing,
so quota and timeout do not trigger later sends for that job under this model.

Jobs are a total function over natural IDs: creation, restarts, cancellation,
concurrency caps, actual HTTP behavior, and eventual response/time progress
are not modeled. An indefinitely waiting execution is possible; no liveness or
translation-success theorem is claimed. In the real client retries and this
shared rate limiter have not been implemented or verified.
