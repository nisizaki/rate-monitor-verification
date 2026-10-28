import {
  type FetchLike,
  translateJapaneseToEnglish,
} from "./fixtures/deeplbot3/lib/deepl_client.ts";
import {
  DeepLbotError,
  DeepLHttpError,
} from "./fixtures/deeplbot3/lib/errors.ts";

// Direct executable transcription of Rate_Monitor.monitor_step on safe integers.
type Event = { kind: "tick"; dt: number } | { kind: "send" } | {
  kind: "other";
};
function monitor(
  capacity: number,
  rate: number,
  balance: number | null,
  events: Event[],
): number | null {
  for (const event of events) {
    if (balance === null) return null;
    switch (event.kind) {
      case "tick":
        balance = Math.min(capacity, balance + rate * event.dt);
        break;
      case "send":
        balance = balance > 0 ? balance - 1 : null;
        break;
      case "other":
        break;
    }
  }
  return balance;
}
function equal(actual: unknown, expected: unknown): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`,
    );
  }
}
class VirtualClock {
  time = 0;
  advance(dt: number) {
    this.time += dt;
  }
}
type Observation = { event: "InvokeFetch"; at: number; id: string };

// Instrument only the injected fetch boundary. Record metadata, never input,
// credentials, response bodies or translation text. The observer is passive.
function observeFetch(
  fetchFn: FetchLike,
  clock: VirtualClock,
  id: string,
  log: Observation[],
): FetchLike {
  return (input, init) => {
    log.push({ event: "InvokeFetch", at: clock.time, id });
    return fetchFn(input, init);
  };
}
async function run(fetchFn: FetchLike, extra: Record<string, unknown> = {}) {
  try {
    const text = await translateJapaneseToEnglish({
      authKey: "test-key",
      text: "sample",
      fetchFn,
      ...extra,
    });
    return { kind: "ok", text };
  } catch (error) {
    if (error instanceof DeepLHttpError) {
      return { kind: "http", status: error.status };
    }
    if (error instanceof DeepLbotError) return { kind: error.code };
    throw error;
  }
}
const reply = (status: number, payload: string): FetchLike => () =>
  Promise.resolve(new Response(payload, { status }));

Deno.test("actual DeepL client: response classes and one fetch per invocation", async () => {
  const clock = new VirtualClock();
  const cases = [
    {
      fetch: reply(200, '{"translations":[{"text":"hello"}]}'),
      expected: { kind: "ok", text: "hello" },
    },
    { fetch: reply(429, ""), expected: { kind: "http", status: 429 } },
    { fetch: reply(456, ""), expected: { kind: "http", status: 456 } },
    { fetch: reply(200, "{"), expected: { kind: "deepl_json_error" } },
    {
      fetch: reply(200, '{"translations":[]}'),
      expected: { kind: "deepl_response_error" },
    },
    {
      fetch: (() => Promise.reject(new Error("network"))) as FetchLike,
      expected: { kind: "deepl_unknown" },
    },
  ];
  for (const [i, c] of cases.entries()) {
    const log: Observation[] = [];
    const result = await run(observeFetch(c.fetch, clock, String(i), log));
    equal(result, c.expected);
    equal(log, [{ event: "InvokeFetch", at: i, id: String(i) }]);
    clock.advance(1);
  }
});

Deno.test("missing credentials fail before fetch", async () => {
  const log: Observation[] = [];
  const result = await run(
    observeFetch(reply(200, "{}"), new VirtualClock(), "a", log),
    { authKey: "" },
  );
  equal(result, { kind: "missing_deepl_auth_key" });
  equal(log, []);
});

Deno.test("injected abort is observed as client-side timeout", async () => {
  const clock = new VirtualClock();
  const log: Observation[] = [];
  const controller = new AbortController();
  const fakeFetch: FetchLike = (_input, init) =>
    new Promise((_resolve, reject) => {
      init?.signal?.addEventListener(
        "abort",
        () => reject(new DOMException("aborted", "AbortError")),
        { once: true },
      );
    });
  const pending = run(observeFetch(fakeFetch, clock, "timeout", log), {
    signal: controller.signal,
  });
  clock.advance(10);
  controller.abort();
  equal(await pending, { kind: "deepl_timeout" });
  equal(log, [{ event: "InvokeFetch", at: 0, id: "timeout" }]);
});

Deno.test("observer preserves outcomes for representative success and error paths", async () => {
  const clock = new VirtualClock();
  for (
    const make of [
      () => reply(200, '{"translations":[{"text":"hello"}]}'),
      () => reply(429, ""),
      () => reply(200, "{"),
    ]
  ) {
    const without = await run(make());
    const log: Observation[] = [];
    const withObserver = await run(observeFetch(make(), clock, "x", log));
    equal(withObserver, without);
    equal(log.length, 1);
  }
});

Deno.test("parallel invocations expose the shared-bucket counterexample", async () => {
  const clock = new VirtualClock();
  const log: Observation[] = [];
  await Promise.all(
    ["a", "b"].map((id) =>
      run(
        observeFetch(
          reply(200, '{"translations":[{"text":"ok"}]}'),
          clock,
          id,
          log,
        ),
      )
    ),
  );
  equal(log.map((x) => x.at), [0, 0]);
  const trace: Event[] = log.map(() => ({ kind: "send" }));
  equal(monitor(1, 0, 1, trace), null);
  equal(monitor(1, 0, 1, [trace[0]]), 0);
  equal(monitor(1, 0, 1, [trace[1]]), 0);
});

Deno.test("monitor follows checked token-bucket examples, including refill and absorbing rejection", () => {
  equal(
    monitor(2, 1, 2, [{ kind: "send" }, { kind: "tick", dt: 1 }, {
      kind: "send",
    }, { kind: "other" }]),
    1,
  );
  equal(
    monitor(1, 0, 1, [{ kind: "send" }, { kind: "send" }, {
      kind: "tick",
      dt: 100,
    }]),
    null,
  );
});
