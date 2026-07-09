# Authentication Patterns

Login flows, session persistence, OAuth, and 2FA patterns for Coterm browser surfaces.

**Related**: [session-management.md](session-management.md), [SKILL.md](../SKILL.md)

## Contents

- [Basic Login Flow](#basic-login-flow)
- [Saving Authentication State](#saving-authentication-state)
- [Restoring Authentication](#restoring-authentication)
- [OAuth / SSO Flows](#oauth--sso-flows)
- [Two-Factor Authentication](#two-factor-authentication)
- [Cookie-Based Auth](#cookie-based-auth)
- [Token Refresh Handling](#token-refresh-handling)
- [Security Best Practices](#security-best-practices)

## Basic Login Flow

```bash
Coterm browser open https://app.example.com/login --json
Coterm browser surface:7 wait --load-state complete --timeout-ms 15000

Coterm browser surface:7 snapshot --interactive
# [ref=e1] email, [ref=e2] password, [ref=e3] submit

Coterm browser surface:7 fill e1 "user@example.com"
Coterm browser surface:7 fill e2 "$APP_PASSWORD"
Coterm browser surface:7 click e3 --snapshot-after --json
Coterm browser surface:7 wait --url-contains "/dashboard" --timeout-ms 20000
```

## Saving Authentication State

After logging in, save state for reuse:

```bash
Coterm browser surface:7 state save ./auth-state.json
```

State includes cookies, localStorage, sessionStorage, and open tab metadata for that surface.

## Restoring Authentication

```bash
Coterm browser open https://app.example.com --json
Coterm browser surface:8 state load ./auth-state.json
Coterm browser surface:8 goto https://app.example.com/dashboard
Coterm browser surface:8 snapshot --interactive
```

## OAuth / SSO Flows

```bash
Coterm browser open https://app.example.com/auth/google --json
Coterm browser surface:7 wait --url-contains "accounts.google.com" --timeout-ms 30000
Coterm browser surface:7 snapshot --interactive

Coterm browser surface:7 fill e1 "user@gmail.com"
Coterm browser surface:7 click e2 --snapshot-after --json

Coterm browser surface:7 wait --url-contains "app.example.com" --timeout-ms 45000
Coterm browser surface:7 state save ./oauth-state.json
```

## Two-Factor Authentication

```bash
Coterm browser open https://app.example.com/login --json
Coterm browser surface:7 snapshot --interactive
Coterm browser surface:7 fill e1 "user@example.com"
Coterm browser surface:7 fill e2 "$APP_PASSWORD"
Coterm browser surface:7 click e3

# complete 2FA manually in the webview, then:
Coterm browser surface:7 wait --url-contains "/dashboard" --timeout-ms 120000
Coterm browser surface:7 state save ./2fa-state.json
```

## Cookie-Based Auth

```bash
Coterm browser surface:7 cookies set session_token "abc123xyz"
Coterm browser surface:7 goto https://app.example.com/dashboard
```

## Token Refresh Handling

```bash
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="./auth-state.json"
SURFACE="surface:7"

if [ -f "$STATE_FILE" ]; then
  Coterm browser "$SURFACE" state load "$STATE_FILE"
fi

Coterm browser "$SURFACE" goto https://app.example.com/dashboard
URL=$(Coterm browser "$SURFACE" get url)

if printf '%s' "$URL" | grep -q '/login'; then
  Coterm browser "$SURFACE" snapshot --interactive
  Coterm browser "$SURFACE" fill e1 "$APP_USERNAME"
  Coterm browser "$SURFACE" fill e2 "$APP_PASSWORD"
  Coterm browser "$SURFACE" click e3
  Coterm browser "$SURFACE" wait --url-contains "/dashboard" --timeout-ms 20000
  Coterm browser "$SURFACE" state save "$STATE_FILE"
fi
```

## Security Best Practices

1. Never commit state files (they include auth tokens).
2. Use environment variables for credentials.
3. Clear state/cookies after sensitive tasks:

```bash
Coterm browser surface:7 cookies clear
rm -f ./auth-state.json
```
