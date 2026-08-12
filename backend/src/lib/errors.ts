/**
 * A single error type for anything the API deliberately rejects (bad
 * credentials, expired OTP, not found, etc.), as opposed to an unexpected
 * crash. Routes throw this and the error handler in `app.ts` turns it into
 * a consistent `{ error: { code, message } }` response — the Flutter
 * client can switch on `code` without parsing message strings.
 */
export class AppError extends Error {
  readonly statusCode: number;
  readonly code: string;

  constructor(statusCode: number, code: string, message: string) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
  }

  static badRequest(message: string, code = 'BAD_REQUEST') {
    return new AppError(400, code, message);
  }

  static unauthorized(message = 'Invalid credentials', code = 'UNAUTHORIZED') {
    return new AppError(401, code, message);
  }

  static forbidden(message = 'Not allowed', code = 'FORBIDDEN') {
    return new AppError(403, code, message);
  }

  static notFound(message = 'Not found', code = 'NOT_FOUND') {
    return new AppError(404, code, message);
  }

  static conflict(message: string, code = 'CONFLICT') {
    return new AppError(409, code, message);
  }

  static tooManyRequests(message = 'Too many attempts', code = 'RATE_LIMITED') {
    return new AppError(429, code, message);
  }

  /** A real server-side condition (missing config, unreachable dependency)
   *  the client can't do anything about — still worth a clear code/message
   *  over the generic "Something went wrong" a plain Error collapses to. */
  static internal(message = 'Something went wrong', code = 'INTERNAL') {
    return new AppError(500, code, message);
  }
}
