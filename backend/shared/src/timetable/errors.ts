export type ErrorCode =
  | "validation_error"
  | "not_found"
  | "import_conflict"
  | "dependency_unavailable"
  | "rate_limited"
  | "internal_error";

const STATUS_BY_CODE: Record<ErrorCode, number> = {
  validation_error: 400,
  not_found: 404,
  import_conflict: 409,
  dependency_unavailable: 503,
  rate_limited: 429,
  internal_error: 500,
};

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly status: number;

  constructor(code: ErrorCode, message: string) {
    super(message);
    this.name = "AppError";
    this.code = code;
    this.status = STATUS_BY_CODE[code];
  }
}

export type ErrorResponse = {
  error: {
    code: ErrorCode;
    message: string;
    requestId: string;
  };
};

export function isAppError(error: unknown): error is AppError {
  return error instanceof AppError;
}
