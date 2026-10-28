import {
  type FetchLike,
  translateJapaneseToEnglish,
} from "./fixtures/deeplbot3/lib/deepl_client.ts";

// Preliminary local mock benchmark. Milliseconds from performance.now() are
// rounded down to natural-number ticks, as in Rate_Monitor.thy. No network.
type Mode = "baseline" | "record" | "monitor";
type LogEntry = { at: number };
const rounds = 1500;
const warmup = 300;
const counts: Record<Mode, number> = { baseline: 0, record: 0, monitor: 0 };
const durations: Record<Mode, number[]> = {
  baseline: [],
  record: [],
  monitor: [],
};
const logs: Record<Mode, LogEntry[]> = {
  baseline: [],
  record: [],
  monitor: [],
};
let balance: number | null = rounds + warmup;
let rejected = 0;

async function one(mode: Mode, measured: boolean) {
  const epoch = performance.now();
  const mock: FetchLike = () => {
    counts[mode]++;
    return Promise.resolve(
      new Response('{"translations":[{"text":"ok"}]}', { status: 200 }),
    );
  };
  const fetchFn: FetchLike = mode === "baseline" ? mock : (input, init) => {
    const at = Math.floor(performance.now());
    logs[mode].push({ at });
    if (!measured) logs[mode].pop();
    if (mode === "monitor") {
      // B = rounds + warmup; r = 0. No refill; Other has no effect.
      balance = balance === null || balance === 0 ? null : balance - 1;
      if (balance === null && measured) rejected++;
    }
    return mock(input, init);
  };
  const result = await translateJapaneseToEnglish({
    authKey: "test-key",
    text: "test",
    fetchFn,
  });
  const duration = performance.now() - epoch;
  if (result !== "ok") throw new Error("Unexpected result");
  if (measured) durations[mode].push(duration);
}

// Rotate order to avoid putting a single mode consistently first or last.
const modes: Mode[] = ["baseline", "record", "monitor"];
for (let i = 0; i < warmup + rounds; i++) {
  for (let j = 0; j < modes.length; j++) {
    await one(modes[(i + j) % modes.length], i >= warmup);
  }
}
function quantile(xs: number[], q: number): number {
  const sorted = [...xs].sort((a, b) => a - b);
  return sorted[Math.ceil(q * sorted.length) - 1];
}
const summary = Object.fromEntries(modes.map((mode) => [mode, {
  n: durations[mode].length,
  p50_ms: quantile(durations[mode], 0.50),
  p95_ms: quantile(durations[mode], 0.95),
  p99_ms: quantile(durations[mode], 0.99),
  mock_invocations_including_warmup: counts[mode],
  observed: mode === "baseline" ? null : logs[mode].length,
  missing_records: mode === "baseline" ? null : rounds - logs[mode].length,
}]));
console.log(JSON.stringify(
  {
    kind: "local-mock-preliminary",
    utc: new Date().toISOString(),
    deno: Deno.version.deno,
    v8: Deno.version.v8,
    os: Deno.build.os,
    arch: Deno.build.arch,
    warmup,
    rounds,
    sequential: true,
    capacity: rounds + warmup,
    rate_per_ms: 0,
    monitor_rejected: rejected,
    summary,
    samples_ms: durations,
    observed_times_ms: { record: logs.record, monitor: logs.monitor },
  },
  null,
  2,
));
