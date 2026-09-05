export type ErrorCode =
  | "VALIDATION_ERROR"
  | "NOT_FOUND"
  | "STORAGE_ERROR"
  | "INTERNAL_ERROR"
  | "PAYLOAD_TOO_LARGE"
  | "UNSUPPORTED_MEDIA_TYPE";

export class ApiError extends Error {
  constructor(
    readonly status: number,
    readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export function validationError(message: string): ApiError {
  return new ApiError(400, "VALIDATION_ERROR", message);
}

export function internalError(): ApiError {
  return new ApiError(
    500,
    "INTERNAL_ERROR",
    "Something went wrong. Try again later.",
  );
}

export function payloadTooLargeError(message: string): ApiError {
  return new ApiError(413, "PAYLOAD_TOO_LARGE", message);
}

export function unsupportedMediaError(message: string): ApiError {
  return new ApiError(415, "UNSUPPORTED_MEDIA_TYPE", message);
}

export function storageError(): ApiError {
  return new ApiError(
    500,
    "STORAGE_ERROR",
    "The images could not be uploaded. Try again.",
  );
}

// One stable envelope. Errors never carry stack traces, SQL, or credentials,
// and are never cacheable.
export function errorResponse(error: ApiError): Response {
  return new Response(
    JSON.stringify({
      error: { code: error.code, message: error.message },
    }),
    {
      status: error.status,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      },
    },
  );
}
