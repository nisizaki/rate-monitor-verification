# Concurrent bot model

`Concurrent_Bot.thy` assigns each natural-number execution ID a bot phase and
shares one token balance among all IDs. `Time d` advances the shared bucket;
`Local i a` applies the existing bot transition to ID `i`, and atomically applies
the projected bucket event. `SendRequest` projects to `Send`; other local actions
project to `Other`. The abstract scheduler can interleave enabled local actions
in any order. The total function of IDs to phases models an unbounded set of
potential IDs; it does not model dynamic creation, deletion, or deployment.

`concurrent_run_projection` proves that each concurrent run projects to a
valid bucket run. `shared_rate_bound` consequently bounds all IDs together by
`B + r * elapsed` for any finite run starting with at most `B` tokens. The
bound covers each contiguous run segment meeting the same initial balance
condition, including segments of a longer run. `shared_two_sends` constructs a
two-ID run when `B > 1`, showing that the model has nonempty send behavior.

`independent_step` gives each ID a separate balance, and
`independent_buckets_counterexample` constructs two sends with `B = 1`, `r = 0`
and no time passing. Each ID starts with one token, so the combined count is
two, exceeding the single-bucket bound of one. This counterexample concerns
local actions only; the independent model has no time transition.

Atomic consumption at the abstract `SendRequest` boundary is an assumption,
not a property established of DeepLbot3, Slack storage or distributed systems.
The current implementation does not have the proposed shared bucket. The model
does not bound network arrival times or DeepL's server-side processing, and it
does not yet model retries, deadlines or runtime instrumentation.
