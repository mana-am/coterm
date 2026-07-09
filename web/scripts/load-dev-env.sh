#!/usr/bin/env bash

# Source this file from direnv or dev scripts. It intentionally keeps local dev
# database URLs derived from COTERM_PORT so parallel worktrees cannot hit the same
# Postgres instance by accident.

coterm_web_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

coterm_existing_coterm_port_set="${COTERM_PORT+x}"
coterm_existing_coterm_port="${COTERM_PORT-}"
coterm_existing_port_set="${PORT+x}"
coterm_existing_port="${PORT-}"
coterm_existing_db_port_offset_set="${COTERM_DB_PORT_OFFSET+x}"
coterm_existing_db_port_offset="${COTERM_DB_PORT_OFFSET-}"
coterm_existing_db_port_set="${COTERM_DB_PORT+x}"
coterm_existing_db_port="${COTERM_DB_PORT-}"
coterm_existing_db_user_set="${COTERM_DB_USER+x}"
coterm_existing_db_user="${COTERM_DB_USER-}"
coterm_existing_db_password_set="${COTERM_DB_PASSWORD+x}"
coterm_existing_db_password="${COTERM_DB_PASSWORD-}"
coterm_existing_db_name_set="${COTERM_DB_NAME+x}"
coterm_existing_db_name="${COTERM_DB_NAME-}"

coterm_extra_secret_file="${COTERM_EXTRA_ENV_FILE:-${COTERM_WEB_EXTRA_ENV_FILE:-}}"
if [[ -z "$coterm_extra_secret_file" && -f "$HOME/.secrets/coterm.env" ]]; then
  coterm_extra_secret_file="$HOME/.secrets/coterm.env"
fi

coterm_secret_file="${COTERM_ENV_FILE:-${COTERM_WEB_ENV_FILE:-}}"
if [[ -z "$coterm_secret_file" ]]; then
  if [[ -f "$HOME/.secrets/coterm-dev.env" ]]; then
    coterm_secret_file="$HOME/.secrets/coterm-dev.env"
  elif [[ -f "$HOME/.secret/coterm.env" ]]; then
    coterm_secret_file="$HOME/.secret/coterm.env"
  elif [[ -f "$HOME/.secrets/coterm.env" ]]; then
    coterm_secret_file="$HOME/.secrets/coterm.env"
  else
    echo "Missing coterm web secrets. Expected ~/.secrets/coterm-dev.env." >&2
    return 1 2>/dev/null || exit 1
  fi
fi

coterm_nounset_was_enabled=0
case "$-" in
  *u*) coterm_nounset_was_enabled=1 ;;
esac
set +u
set -a
if [[ -n "$coterm_extra_secret_file" ]]; then
  # shellcheck disable=SC1090
  source "$coterm_extra_secret_file"
fi
# shellcheck disable=SC1090
source "$coterm_secret_file"
set +a
if ! grep -q '^STACK_SUPER_SECRET_ADMIN_KEY=' "$coterm_secret_file"; then
  unset STACK_SUPER_SECRET_ADMIN_KEY
fi
if [[ "$coterm_nounset_was_enabled" == "1" ]]; then
  set -u
fi

if [[ -n "$coterm_existing_coterm_port_set" ]]; then export COTERM_PORT="$coterm_existing_coterm_port"; fi
if [[ -n "$coterm_existing_port_set" ]]; then export PORT="$coterm_existing_port"; fi
if [[ -n "$coterm_existing_db_port_offset_set" ]]; then export COTERM_DB_PORT_OFFSET="$coterm_existing_db_port_offset"; fi
if [[ -n "$coterm_existing_db_port_set" ]]; then export COTERM_DB_PORT="$coterm_existing_db_port"; fi
if [[ -n "$coterm_existing_db_user_set" ]]; then export COTERM_DB_USER="$coterm_existing_db_user"; fi
if [[ -n "$coterm_existing_db_password_set" ]]; then export COTERM_DB_PASSWORD="$coterm_existing_db_password"; fi
if [[ -n "$coterm_existing_db_name_set" ]]; then export COTERM_DB_NAME="$coterm_existing_db_name"; fi

coterm_port="${COTERM_PORT:-${PORT:-3777}}"
if [[ ! "$coterm_port" =~ ^[0-9]+$ ]]; then
  echo "COTERM_PORT must be numeric, got: $coterm_port" >&2
  return 2 2>/dev/null || exit 2
fi
export COTERM_PORT="$coterm_port"

coterm_db_offset="${COTERM_DB_PORT_OFFSET:-10000}"
if [[ ! "$coterm_db_offset" =~ ^[0-9]+$ ]]; then
  echo "COTERM_DB_PORT_OFFSET must be numeric, got: $coterm_db_offset" >&2
  return 2 2>/dev/null || exit 2
fi
export COTERM_DB_PORT_OFFSET="$coterm_db_offset"

export COTERM_DB_USER="${COTERM_DB_USER:-coterm}"
export COTERM_DB_PASSWORD="${COTERM_DB_PASSWORD:-coterm}"
export COTERM_DB_NAME="${COTERM_DB_NAME:-coterm}"
export COTERM_DB_PORT="${COTERM_DB_PORT:-$((coterm_port + coterm_db_offset))}"

if [[ "${COTERM_DEV_USE_EXTERNAL_DATABASE_URL:-0}" != "1" ]]; then
  export DATABASE_URL="postgres://${COTERM_DB_USER}:${COTERM_DB_PASSWORD}@localhost:${COTERM_DB_PORT}/${COTERM_DB_NAME}"
  export DIRECT_DATABASE_URL="$DATABASE_URL"
elif [[ -z "${DIRECT_DATABASE_URL:-}" && -n "${DATABASE_URL:-}" ]]; then
  export DIRECT_DATABASE_URL="$DATABASE_URL"
fi

if [[ "${COTERM_DEV_USE_EXTERNAL_VM_API_BASE_URL:-0}" != "1" ]]; then
  export COTERM_VM_API_BASE_URL="http://localhost:${COTERM_PORT}"
fi

# Local dev should not require a checked-in or per-worktree .env.local just to pass
# startup validation for routes the developer is not exercising.
export RESEND_API_KEY="${RESEND_API_KEY:-coterm-local-dev}"
export COTERM_FEEDBACK_FROM_EMAIL="${COTERM_FEEDBACK_FROM_EMAIL:-dev@example.invalid}"
export COTERM_FEEDBACK_RATE_LIMIT_ID="${COTERM_FEEDBACK_RATE_LIMIT_ID:-coterm-feedback-local}"
export COTERM_PUSH_RATE_LIMIT_ID="${COTERM_PUSH_RATE_LIMIT_ID:-coterm-push-local}"

export COTERM_WEB_SECRET_ENV_FILE="$coterm_secret_file"
export COTERM_WEB_EXTRA_SECRET_ENV_FILE="$coterm_extra_secret_file"
export PATH="$coterm_web_dir/node_modules/.bin:$PATH"
