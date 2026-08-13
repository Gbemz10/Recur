import { z } from 'zod';

export const waitlistSignupSchema = z.object({
  email: z.string().trim().toLowerCase().email(),
  // Which form on the marketing site the signup came from — optional, the
  // site doesn't have to send it for this to work.
  source: z.enum(['hero', 'final_cta']).optional(),
});
