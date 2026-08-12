import { z } from 'zod';

const email = z.string().trim().toLowerCase().email();

// 8+ chars, at least one letter and one number — mirrors the live
// requirement checklist on the Flutter create-password screen exactly, so
// the client's "this will be accepted" promise is never wrong.
const password = z
  .string()
  .min(8, 'Password must be at least 8 characters')
  .regex(/[A-Za-z]/, 'Password must contain a letter')
  .regex(/[0-9]/, 'Password must contain a number');

export const signupSchema = z.object({ email });

export const otpVerifySchema = z.object({
  email,
  code: z.string().trim(),
  purpose: z.enum(['SIGNUP', 'RESET_PASSWORD']),
});

export const setPasswordSchema = z.object({
  email,
  password,
  purpose: z.enum(['SIGNUP', 'RESET_PASSWORD']),
});

export const loginSchema = z.object({
  email,
  password: z.string().min(1, 'Password is required'),
});

export const forgotPasswordSchema = z.object({ email });

export const updateProfileSchema = z.object({
  displayName: z.string().trim().min(1, 'Name cannot be empty').max(80, 'Name is too long'),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(1, 'refreshToken is required'),
});

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1, 'Current password is required'),
  newPassword: password,
});

export const deleteAccountSchema = z.object({
  password: z.string().min(1, 'Password is required'),
});
