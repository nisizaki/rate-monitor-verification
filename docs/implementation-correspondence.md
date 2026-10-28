# DeepLbot3: implementation correspondence

Reference: `nisizaki/deeplbot3` commit `b4eb35ba464ebde9e4fad89c387c68653cc76dac`.
The mapping below is a review of code, not a formal refinement proof.

| Model | Implementation | Abstraction or limitation |
| --- | --- | --- |
| `Prepare` / `PrepareOK` | `lib/translate_reaction_service.ts`: trigger filter, identity, message and emoji preparation | Several calls, filtering and failures are compressed into one transition; the environment is abstract. |
| `SendRequest` | `lib/deepl_client.ts`: call to `fetchFn` in `translateJapaneseToEnglish` | The proposed boundary is invocation, not server receipt. Missing key and signal setup can fail before this point. |
| `HttpOK` / `Decode` | `response.ok`, then `response.json()` and translation validation in `lib/deepl_client.ts` | The response payload and translation text are abstracted. The default timer is cleared when `fetchFn` settles, before JSON parsing. |
| `ValidTranslation` / `Post` | successful translation, placeholder restoration and requester lookup, then `postThreadReply` | Intermediate operations are collapsed. |
| `ReplyOK` / `Audit` | successful `postThreadReply`, then permalink lookup and `putUsageEvent` | Audit errors are allowed; they do not remove the reply. |
| `AuditDone` / `MarkOK` | `addReaction` after the audit attempt | `MarkOK` means success, not merely an attempted reaction; failed reaction leaves the reply. |
| `Fail` | error / ignored-result paths | The model allows failure from every phase, an over-approximation. It does not classify all result codes. |

The actual client performs one fetch per invocation and treats HTTP failures as
errors. `Bot_Order` has no retry transitions and permits at most one send along
its successful progression. Multiple Slack Function invocations, duplicate
messages, clock behavior, and platform-side processing are not modeled.

`Bot_Rate` adds a *proposed* bucket-controlled product, not present in the
current DeepLbot3 implementation. It maps `Action SendRequest` to `Send`,
`Clock d` to `Tick d`, and other actions to `Other`. An action and the bucket
update form one abstract transition; no TypeScript atomicity or cross-function
sharing has been proved. The theorem counts calls at this abstract boundary.
The real client has no demonstrated shared rate limiter, and the proof makes
no claim about DeepL's unknown internal limit or network arrival times.

Source: https://github.com/nisizaki/deeplbot3/blob/b4eb35ba464ebde9e4fad89c387c68653cc76dac/lib/deepl_client.ts

Source: https://github.com/nisizaki/deeplbot3/blob/b4eb35ba464ebde9e4fad89c387c68653cc76dac/lib/translate_reaction_service.ts
