import { createEnv } from "@t3-oss/env-nextjs";
import { z } from "zod";

// Trim at the runtimeEnv source so every consumer — including paths that
// run when validation is skipped (VERCEL_ENV === "preview") — sees clean
// values. A trailing newline in Vercel env vars has tripped Stack Auth's
// UUID parser and malformed the stack-refresh-<project-id> cookie key.
const trimEnv = (value: string | undefined): string | undefined =>
  typeof value === "string" ? value.trim() : value;

const skipEnvValidation =
  process.env.SKIP_ENV_VALIDATION === "1" ||
  process.env.VERCEL_ENV === "preview";
const allowPreviewStackPlaceholders = process.env.VERCEL_ENV === "preview";

const stackEnv = (
  value: string | undefined,
  fallback: string
): string | undefined => {
  const trimmed = trimEnv(value);
  if (trimmed) return trimmed;
  return allowPreviewStackPlaceholders ? fallback : undefined;
};

const clerkEnv = (
  value: string | undefined,
  fallback: string
): string | undefined => {
  const trimmed = trimEnv(value);
  if (trimmed) return trimmed;
  return allowPreviewStackPlaceholders ? fallback : undefined;
};

export const env = createEnv({
  server: {
    RESEND_API_KEY: z.string().min(1),
    COTERM_FEEDBACK_FROM_EMAIL: z.string().email(),
    COTERM_FEEDBACK_RATE_LIMIT_ID: z.string().min(1),
    STACK_SECRET_SERVER_KEY: z.string().min(1).optional(),
    CLERK_SECRET_KEY: z.string().min(1),
    COTERM_NATIVE_AUTH_SECRET: z.string().min(32).optional(),
    // APNs push (iOS notifications). Optional: the app boots without them; the
    // push route returns a clear "not configured" error until they are set.
    // COTERM_APNS_KEY_P8 holds the .p8 PEM (literal "\n" escapes are normalized
    // by the sender).
    COTERM_APNS_KEY_P8: z.string().min(1).optional(),
    COTERM_APNS_KEY_ID: z.string().min(1).optional(),
    COTERM_APNS_TEAM_ID: z.string().min(1).optional(),
    COTERM_PUSH_RATE_LIMIT_ID: z.string().min(1).optional(),
    // coterm Founder's Edition welcome email (Stripe webhook -> Resend). Optional:
    // the /api/stripe/founders-welcome route returns "not configured" until the
    // webhook signing secret is set. COTERM_FOUNDERS_FROM_EMAIL overrides the
    // sender (defaults to austin@emergent.inc) so the verified Resend domain can
    // change without a code edit.
    STRIPE_FOUNDERS_WEBHOOK_SECRET: z.string().min(1).optional(),
    COTERM_FOUNDERS_FROM_EMAIL: z.string().email().optional(),
    // Slack Incoming Webhook for the #website-waitlist channel. Optional: the
    // /api/waitlist route silently skips the Slack ping when it is unset.
    SLACK_WAITLIST_WEBHOOK_URL: z.string().url().optional(),
    // Slack-compatible webhook for high-signal app bug/error notifications.
    // Optional: /api/bug-alerts accepts and records the event but skips fan-out.
    COTERM_BUG_ALERTS_WEBHOOK_URL: z.string().url().optional(),
    // Optional shared secret required by /api/bug-alerts when configured.
    COTERM_BUG_ALERTS_SHARED_SECRET: z.string().min(1).optional(),
    // Public R2 base used by Coterm download/update proxy routes. Example:
    // https://pub-xxxxxxxx.r2.dev
    COTERM_R2_PUBLIC_BASE_URL: z.string().url().optional(),
  },
  client: {
    NEXT_PUBLIC_STACK_PROJECT_ID: z.string().min(1).optional(),
    NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY: z.string().min(1).optional(),
    NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: z.string().min(1),
    NEXT_PUBLIC_POSTHOG_KEY: z.string().min(1).optional(),
    NEXT_PUBLIC_POSTHOG_HOST: z.string().url().optional(),
    NEXT_PUBLIC_POSTHOG_UI_HOST: z.string().url().optional(),
  },
  runtimeEnv: {
    RESEND_API_KEY: trimEnv(process.env.RESEND_API_KEY),
    COTERM_FEEDBACK_FROM_EMAIL: trimEnv(process.env.COTERM_FEEDBACK_FROM_EMAIL),
    COTERM_FEEDBACK_RATE_LIMIT_ID: trimEnv(process.env.COTERM_FEEDBACK_RATE_LIMIT_ID),
    COTERM_APNS_KEY_P8: trimEnv(process.env.COTERM_APNS_KEY_P8),
    COTERM_APNS_KEY_ID: trimEnv(process.env.COTERM_APNS_KEY_ID),
    COTERM_APNS_TEAM_ID: trimEnv(process.env.COTERM_APNS_TEAM_ID),
    COTERM_PUSH_RATE_LIMIT_ID: trimEnv(process.env.COTERM_PUSH_RATE_LIMIT_ID),
    CLERK_SECRET_KEY: clerkEnv(
      process.env.CLERK_SECRET_KEY,
      "sk_test_preview_clerk_secret_key"
    ),
    COTERM_NATIVE_AUTH_SECRET: trimEnv(process.env.COTERM_NATIVE_AUTH_SECRET),
    STRIPE_FOUNDERS_WEBHOOK_SECRET: trimEnv(process.env.STRIPE_FOUNDERS_WEBHOOK_SECRET),
    COTERM_FOUNDERS_FROM_EMAIL: trimEnv(process.env.COTERM_FOUNDERS_FROM_EMAIL),
    SLACK_WAITLIST_WEBHOOK_URL: trimEnv(process.env.SLACK_WAITLIST_WEBHOOK_URL),
    COTERM_BUG_ALERTS_WEBHOOK_URL: trimEnv(process.env.COTERM_BUG_ALERTS_WEBHOOK_URL),
    COTERM_BUG_ALERTS_SHARED_SECRET: trimEnv(process.env.COTERM_BUG_ALERTS_SHARED_SECRET),
    COTERM_R2_PUBLIC_BASE_URL: trimEnv(process.env.COTERM_R2_PUBLIC_BASE_URL),
    NEXT_PUBLIC_STACK_PROJECT_ID: stackEnv(
      process.env.NEXT_PUBLIC_STACK_PROJECT_ID,
      "00000000-0000-4000-8000-000000000000"
    ),
    NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY: stackEnv(
      process.env.NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY,
      "preview-publishable-client-key"
    ),
    NEXT_PUBLIC_POSTHOG_KEY: trimEnv(process.env.NEXT_PUBLIC_POSTHOG_KEY),
    NEXT_PUBLIC_POSTHOG_HOST: trimEnv(process.env.NEXT_PUBLIC_POSTHOG_HOST),
    NEXT_PUBLIC_POSTHOG_UI_HOST: trimEnv(process.env.NEXT_PUBLIC_POSTHOG_UI_HOST),
    STACK_SECRET_SERVER_KEY: stackEnv(
      process.env.STACK_SECRET_SERVER_KEY,
      "preview-secret-server-key"
    ),
    NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY: clerkEnv(
      process.env.NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY,
      "pk_test_preview_clerk_publishable_key"
    ),
  },
  skipValidation: skipEnvValidation,
});
