import type { FastifyInstance } from 'fastify';
import type { ZodType } from 'zod';
import { AppError } from '../../lib/errors.js';
import { rateLimit, emailKey } from '../../lib/rateLimit.js';
import { uploadAvatar } from '../../lib/storage.js';
import {
  signupSchema,
  otpVerifySchema,
  setPasswordSchema,
  loginSchema,
  forgotPasswordSchema,
  updateProfileSchema,
  refreshSchema,
  changePasswordSchema,
  deleteAccountSchema,
} from './schemas.js';
import * as authService from './service.js';

function parseOrThrow<T>(schema: ZodType<T>, body: unknown): T {
  const result = schema.safeParse(body);
  if (!result.success) {
    const first = result.error.issues[0];
    throw AppError.badRequest(first ? `${first.path.join('.')}: ${first.message}` : 'Invalid request body');
  }
  return result.data;
}

// Every auth endpoint gets two independent limiters: one scoped to the
// caller's IP (blunts a single bot/script hammering the endpoint) and one
// scoped to the target email (blunts an attacker rotating through many
// IPs/proxies to grind one specific account or inbox). A real attacker
// only needs one of those defeated to make progress, so both are applied.
const signupIpLimit = rateLimit({ name: 'auth:signup:ip', windowMs: 60 * 60 * 1000, max: 20 });
const signupEmailLimit = rateLimit({ name: 'auth:signup:email', windowMs: 60 * 60 * 1000, max: 5, keyGenerator: emailKey });

const forgotPasswordIpLimit = rateLimit({ name: 'auth:forgot-password:ip', windowMs: 60 * 60 * 1000, max: 20 });
const forgotPasswordEmailLimit = rateLimit({
  name: 'auth:forgot-password:email',
  windowMs: 60 * 60 * 1000,
  max: 5,
  keyGenerator: emailKey,
});

// OTP verification already has a per-code max-attempt lockout inside
// authService (see otp.ts) — these limiters add a coarser outer bound so
// a script can't just keep requesting fresh codes to reset that counter.
const otpVerifyIpLimit = rateLimit({ name: 'auth:otp-verify:ip', windowMs: 15 * 60 * 1000, max: 30 });
const otpVerifyEmailLimit = rateLimit({ name: 'auth:otp-verify:email', windowMs: 15 * 60 * 1000, max: 10, keyGenerator: emailKey });

const loginIpLimit = rateLimit({ name: 'auth:login:ip', windowMs: 15 * 60 * 1000, max: 30 });
const loginEmailLimit = rateLimit({ name: 'auth:login:email', windowMs: 15 * 60 * 1000, max: 8, keyGenerator: emailKey });

// setPassword already requires a recent OTP verification internally
// (assertRecentlyVerified in service.ts), but every sibling endpoint here
// gets an explicit limiter too rather than leaning on another endpoint's
// side effect as its only defense — consistent with the rest of this file.
const setPasswordIpLimit = rateLimit({ name: 'auth:password:ip', windowMs: 60 * 60 * 1000, max: 20 });
const setPasswordEmailLimit = rateLimit({ name: 'auth:password:email', windowMs: 60 * 60 * 1000, max: 10, keyGenerator: emailKey });

const avatarUploadLimit = rateLimit({ name: 'auth:me:avatar', windowMs: 15 * 60 * 1000, max: 10 });

// Refresh tokens are high-entropy (384 bits) — brute-forcing one isn't
// realistic — but a per-IP cap still blunts abuse/DoS against the endpoint
// itself, and matches the defense-in-depth posture used everywhere else.
const refreshLimit = rateLimit({ name: 'auth:refresh:ip', windowMs: 15 * 60 * 1000, max: 60 });
const changePasswordLimit = rateLimit({ name: 'auth:me:password', windowMs: 60 * 60 * 1000, max: 10 });
const deleteAccountLimit = rateLimit({ name: 'auth:me:delete', windowMs: 60 * 60 * 1000, max: 5 });

export async function authRoutes(app: FastifyInstance) {
  app.post('/auth/signup', { preHandler: [signupIpLimit, signupEmailLimit] }, async (request, reply) => {
    const { email } = parseOrThrow(signupSchema, request.body);
    await authService.signup(email);
    return reply.send({ message: 'Code sent' });
  });

  app.post('/auth/forgot-password', { preHandler: [forgotPasswordIpLimit, forgotPasswordEmailLimit] }, async (request, reply) => {
    const { email } = parseOrThrow(forgotPasswordSchema, request.body);
    await authService.requestPasswordReset(email);
    // Same response whether or not the account exists — see service.ts.
    return reply.send({ message: 'If that email has an account, a code was sent' });
  });

  app.post('/auth/otp/verify', { preHandler: [otpVerifyIpLimit, otpVerifyEmailLimit] }, async (request, reply) => {
    const { email, code, purpose } = parseOrThrow(otpVerifySchema, request.body);
    await authService.verifyOtpCode(email, code, purpose);
    return reply.send({ verified: true });
  });

  app.post('/auth/password', { preHandler: [setPasswordIpLimit, setPasswordEmailLimit] }, async (request, reply) => {
    const { email, password, purpose } = parseOrThrow(setPasswordSchema, request.body);
    const user = await authService.setPassword(email, password, purpose);
    const accessToken = await reply.jwtSign({ sub: user.id, email: user.email });
    const refreshToken = await authService.issueRefreshToken(user.id);
    return reply.send({ accessToken, refreshToken, user: { id: user.id, email: user.email } });
  });

  app.post('/auth/login', { preHandler: [loginIpLimit, loginEmailLimit] }, async (request, reply) => {
    const { email, password } = parseOrThrow(loginSchema, request.body);
    const user = await authService.login(email, password);
    const accessToken = await reply.jwtSign({ sub: user.id, email: user.email });
    const refreshToken = await authService.issueRefreshToken(user.id);
    return reply.send({ accessToken, refreshToken, user: { id: user.id, email: user.email } });
  });

  // No auth guard — the refresh token itself is the credential, and an
  // expired/soon-to-expire access token is exactly the case this exists to
  // recover from. Rotates the refresh token on every use (see
  // rotateRefreshToken in service.ts).
  app.post('/auth/refresh', { preHandler: [refreshLimit] }, async (request, reply) => {
    const { refreshToken } = parseOrThrow(refreshSchema, request.body);
    const { user, refreshToken: nextRefreshToken } = await authService.rotateRefreshToken(refreshToken);
    const accessToken = await reply.jwtSign({ sub: user.id, email: user.email });
    return reply.send({ accessToken, refreshToken: nextRefreshToken });
  });

  // Also no auth guard — logging out should work even with an already-
  // expired access token. Revoking by the refresh token itself (a bearer
  // secret only the legitimate device holds) is proof enough of ownership.
  app.post('/auth/logout', async (request, reply) => {
    const { refreshToken } = parseOrThrow(refreshSchema, request.body);
    await authService.revokeRefreshToken(refreshToken);
    return reply.send({ message: 'Signed out' });
  });

  app.get('/auth/me', { onRequest: [app.authenticate] }, async (request, reply) => {
    const userId = request.user.sub;
    const profile = await authService.getProfile(userId);
    return reply.send({ user: profile });
  });

  app.patch('/auth/me', { onRequest: [app.authenticate] }, async (request, reply) => {
    const userId = request.user.sub;
    const { displayName } = parseOrThrow(updateProfileSchema, request.body);
    const profile = await authService.updateDisplayName(userId, displayName);
    return reply.send({ user: profile });
  });

  // Multipart, not JSON — the file comes in as `request.file()` via
  // @fastify/multipart (registered in app.ts), one field, no other form
  // fields expected.
  app.post('/auth/me/avatar', { onRequest: [app.authenticate], preHandler: [avatarUploadLimit] }, async (request, reply) => {
    const userId = request.user.sub;
    const file = await request.file();
    if (!file) throw AppError.badRequest('No image uploaded', 'NO_FILE');

    const bytes = await file.toBuffer();
    const avatarUrl = await uploadAvatar(userId, bytes, file.mimetype);
    const profile = await authService.updateAvatarUrl(userId, avatarUrl);
    return reply.send({ user: profile });
  });

  // Every other device gets signed out (see changePassword/
  // revokeAllRefreshTokens in service.ts) — this device gets a fresh token
  // pair right here so it isn't caught in that net.
  app.post('/auth/me/password', { onRequest: [app.authenticate], preHandler: [changePasswordLimit] }, async (request, reply) => {
    const userId = request.user.sub;
    const { currentPassword, newPassword } = parseOrThrow(changePasswordSchema, request.body);
    const user = await authService.changePassword(userId, currentPassword, newPassword);
    const accessToken = await reply.jwtSign({ sub: user.id, email: user.email });
    const refreshToken = await authService.issueRefreshToken(user.id);
    return reply.send({ accessToken, refreshToken });
  });

  app.delete('/auth/me', { onRequest: [app.authenticate], preHandler: [deleteAccountLimit] }, async (request, reply) => {
    const userId = request.user.sub;
    const { password } = parseOrThrow(deleteAccountSchema, request.body);
    await authService.deleteAccount(userId, password);
    return reply.send({ message: 'Account deleted' });
  });
}
