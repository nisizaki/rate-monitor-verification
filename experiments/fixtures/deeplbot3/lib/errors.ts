export type DeepLbotErrorCode =
  | "missing_deepl_auth_key"
  | "deepl_http_error"
  | "deepl_json_error"
  | "deepl_response_error"
  | "deepl_timeout"
  | "deepl_unknown";

export type DeepLStage =
  | "signal_setup"
  | "fetch"
  | "response_status"
  | "response_json"
  | "response_validation";

export type DeepLErrorKind = "error" | "dom_exception" | "non_error";

export interface DeepLErrorDiagnostics {
  deepLStage: DeepLStage;
  errorName: string;
  errorKind: DeepLErrorKind;
}

export class DeepLbotError extends Error {
  constructor(
    readonly code: DeepLbotErrorCode,
    message: string,
    readonly diagnostics?: DeepLErrorDiagnostics,
  ) {
    super(message);
    this.name = "DeepLbotError";
  }
}

export class MissingDeepLAuthKeyError extends DeepLbotError {
  constructor() {
    super("missing_deepl_auth_key", "DEEPL_AUTH_KEY is not configured.");
    this.name = "MissingDeepLAuthKeyError";
  }
}

export class DeepLHttpError extends DeepLbotError {
  constructor(readonly status: number) {
    super(
      "deepl_http_error",
      `DeepL HTTP request failed with status ${status}.`,
      {
        deepLStage: "response_status",
        errorName: "DeepLHttpError",
        errorKind: "error",
      },
    );
    this.name = "DeepLHttpError";
  }
}

export class DeepLJsonError extends DeepLbotError {
  constructor() {
    super("deepl_json_error", "DeepL response was not valid JSON.", {
      deepLStage: "response_json",
      errorName: "DeepLJsonError",
      errorKind: "error",
    });
    this.name = "DeepLJsonError";
  }
}

export class DeepLResponseError extends DeepLbotError {
  constructor() {
    super(
      "deepl_response_error",
      "DeepL response did not contain a translation.",
      {
        deepLStage: "response_validation",
        errorName: "DeepLResponseError",
        errorKind: "error",
      },
    );
    this.name = "DeepLResponseError";
  }
}

export class DeepLTimeoutError extends DeepLbotError {
  constructor() {
    super("deepl_timeout", "DeepL request timed out.", {
      deepLStage: "fetch",
      errorName: "DeepLTimeoutError",
      errorKind: "error",
    });
    this.name = "DeepLTimeoutError";
  }
}

export class DeepLUnknownError extends DeepLbotError {
  constructor(override readonly diagnostics: DeepLErrorDiagnostics) {
    super("deepl_unknown", "DeepL request failed.");
    this.name = "DeepLUnknownError";
  }
}
