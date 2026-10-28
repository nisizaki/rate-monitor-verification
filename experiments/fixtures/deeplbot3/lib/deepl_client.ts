import {
  DeepLHttpError,
  DeepLJsonError,
  DeepLResponseError,
  DeepLTimeoutError,
  DeepLUnknownError,
  MissingDeepLAuthKeyError,
} from "./errors.ts";
import type {
  DeepLErrorDiagnostics,
  DeepLErrorKind,
  DeepLStage,
} from "./errors.ts";

export const DEEPL_PRO_TRANSLATE_URL = "https://api.deepl.com/v2/translate";
export const DEEPL_FREE_TRANSLATE_URL =
  "https://api-free.deepl.com/v2/translate";
export const DEEPL_TRANSLATE_URL = DEEPL_PRO_TRANSLATE_URL;
export const DEEPL_SOURCE_LANG = "JA";
export const DEEPL_TARGET_LANG = "EN";
export const DEFAULT_DEEPL_TIMEOUT_MS = 20_000;

export type FetchLike = (
  input: string | URL | Request,
  init?: RequestInit,
) => Promise<Response>;

export type TimeoutHandle = ReturnType<typeof setTimeout>;
export type SetTimeoutLike = (
  callback: () => void,
  timeoutMs: number,
) => TimeoutHandle;
export type ClearTimeoutLike = (timer: TimeoutHandle) => void;

export interface DeepLConfig {
  authKey?: string;
  glossaryId?: string;
  apiUrl?: string;
}

export interface TranslateTextOptions extends DeepLConfig {
  text: string;
  fetchFn?: FetchLike;
  signal?: AbortSignal;
  timeoutMs?: number;
  setTimeoutFn?: SetTimeoutLike;
  clearTimeoutFn?: ClearTimeoutLike;
}

interface DeepLTranslation {
  text?: unknown;
}

interface DeepLTranslateResponse {
  translations?: unknown;
}

export function readDeepLConfigFromEnv(
  env: Pick<typeof Deno.env, "get"> = Deno.env,
): DeepLConfig {
  return {
    authKey: env.get("DEEPL_AUTH_KEY") ?? undefined,
    glossaryId: env.get("DEEPL_GLOSSARY_ID") ?? undefined,
    apiUrl: env.get("DEEPL_API_URL") ?? undefined,
  };
}

export function resolveDeepLTranslateUrl(config: DeepLConfig): string {
  if (config.apiUrl) {
    return config.apiUrl;
  }

  if (config.authKey?.endsWith(":fx")) {
    return DEEPL_FREE_TRANSLATE_URL;
  }

  return DEEPL_PRO_TRANSLATE_URL;
}

export async function translateJapaneseToEnglish(
  options: TranslateTextOptions,
): Promise<string> {
  const { authKey, glossaryId, text } = options;
  const fetchFn = options.fetchFn ?? fetch;

  if (!authKey) {
    throw new MissingDeepLAuthKeyError();
  }

  const body = new URLSearchParams({
    text,
    source_lang: DEEPL_SOURCE_LANG,
    target_lang: DEEPL_TARGET_LANG,
  });

  if (glossaryId) {
    body.set("glossary_id", glossaryId);
  }

  let managedSignal: ManagedDeepLSignal;
  try {
    managedSignal = resolveDeepLSignal(options);
  } catch (error) {
    throw new DeepLUnknownError(describeDeepLError(error, "signal_setup"));
  }

  let response: Response;
  try {
    response = await fetchFn(resolveDeepLTranslateUrl(options), {
      method: "POST",
      headers: {
        Authorization: `DeepL-Auth-Key ${authKey}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body,
      signal: managedSignal.signal,
    });
  } catch (error) {
    if (isAbortLikeError(error) || managedSignal.signal.aborted) {
      throw new DeepLTimeoutError();
    }

    throw new DeepLUnknownError(describeDeepLError(error, "fetch"));
  } finally {
    managedSignal.clear();
  }

  if (!response.ok) {
    throw new DeepLHttpError(response.status);
  }

  let payload: DeepLTranslateResponse;
  try {
    payload = await response.json();
  } catch {
    throw new DeepLJsonError();
  }

  const translations = payload.translations;
  if (!Array.isArray(translations) || translations.length === 0) {
    throw new DeepLResponseError();
  }

  const firstTranslation = translations[0] as DeepLTranslation;
  if (typeof firstTranslation.text !== "string") {
    throw new DeepLResponseError();
  }

  return firstTranslation.text;
}

interface ManagedDeepLSignal {
  signal: AbortSignal;
  clear(): void;
}

function resolveDeepLSignal(options: TranslateTextOptions): ManagedDeepLSignal {
  if (options.signal) {
    return { signal: options.signal, clear: () => {} };
  }

  const timeoutMs = options.timeoutMs ?? DEFAULT_DEEPL_TIMEOUT_MS;
  if (typeof AbortSignal.timeout === "function") {
    try {
      return { signal: AbortSignal.timeout(timeoutMs), clear: () => {} };
    } catch {
      // Some runtimes expose AbortSignal.timeout but throw when it is called.
      // Fall through to the AbortController based timer.
    }
  }

  const controller = new AbortController();
  const setTimeoutFn = options.setTimeoutFn ?? setTimeout;
  const clearTimeoutFn = options.clearTimeoutFn ?? clearTimeout;
  const timer = setTimeoutFn(() => controller.abort(), timeoutMs);
  return {
    signal: controller.signal,
    clear: () => clearTimeoutFn(timer),
  };
}

function isAbortLikeError(error: unknown): boolean {
  return error instanceof DOMException &&
    (error.name === "AbortError" || error.name === "TimeoutError");
}

function describeDeepLError(
  error: unknown,
  deepLStage: DeepLStage,
): DeepLErrorDiagnostics {
  return {
    deepLStage,
    errorName: errorName(error),
    errorKind: errorKind(error),
  };
}

function errorName(error: unknown): string {
  if (error instanceof DOMException) {
    return error.name || "DOMException";
  }

  if (error instanceof Error) {
    return error.name || "Error";
  }

  return "NonError";
}

function errorKind(error: unknown): DeepLErrorKind {
  if (error instanceof DOMException) {
    return "dom_exception";
  }

  if (error instanceof Error) {
    return "error";
  }

  return "non_error";
}
