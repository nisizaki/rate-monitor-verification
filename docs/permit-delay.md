# Permit and fetch timing

`Permit_Delay.thy` gives a separate finite-set model of distinct permit IDs.
Each grant ID has a natural-number grant time; each fetch ID has a fetch time.
The finite set of fetch IDs must be a subset of grants, so no fetch is without
a permit and each permit ID is used at most once in the represented history.
Some granted permits may never be used. Time intervals are half-open `[s,t)`.

`rate_constrained` requires, for every `s <= t`, the number of grants in the
interval to be at most `B + r*(t-s)`. `fetch_bound_with_delay` assumes that
each fetch occurs after its matching grant and at most D time units later. It
proves that the number of fetches in `[s,t)` is at most
`B + r*((t-s)+D)`. The proof encloses their matched grants in `[s-D,t)` using
saturating natural subtraction. `zero_delay_preserves_bound` specializes it
to D = 0.

`unchanged_rate_counterexample` gives grant IDs 0, 1 and 2 at times 0, 1 and
2. Their grant stream respects B = 1 and r = 1. Fetching all three at time 2
uses each permit once with delay at most 2, but the fetch count 3 in `[2,3)`
exceeds the unchanged bound 2. Thus the unadjusted bound is not guaranteed.

The grant bound is an explicit assumption here. This theory does not yet
derive that assumption from `Retry_Bot` or `Concurrent_Bot`, which currently
identify permit consumption and dispatch as one transition. Nor does it model
the actual TypeScript scheduler, physical network delivery, observer overhead,
clocks on distinct machines, or a measured worst-case D. Establishing these
connections requires additional refinement and implementation work.
