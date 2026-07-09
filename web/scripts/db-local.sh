#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if REPO_DIR="$(git -C "$ROOT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_DIR="$(cd "$ROOT_DIR/.." && pwd)"
fi

command="${1:-status}"

coterm_port="${COTERM_PORT:-${PORT:-3777}}"
if [[ ! "$coterm_port" =~ ^[0-9]+$ ]]; then
  echo "COTERM_PORT must be numeric, got: $coterm_port" >&2
  exit 2
fi

db_kind="${COTERM_DB_KIND:-dev}"
db_offset="${COTERM_DB_PORT_OFFSET:-10000}"
if [[ ! "$db_offset" =~ ^[0-9]+$ ]]; then
  echo "COTERM_DB_PORT_OFFSET must be numeric, got: $db_offset" >&2
  exit 2
fi

db_port="${COTERM_DB_PORT:-$((coterm_port + db_offset))}"
db_user="${COTERM_DB_USER:-coterm}"
db_password="${COTERM_DB_PASSWORD:-coterm}"
db_name="${COTERM_DB_NAME:-coterm}"

branch="$(git -C "$REPO_DIR" branch --show-current 2>/dev/null || true)"
if [[ -z "$branch" ]]; then
  branch="$(basename "$REPO_DIR")"
fi
slug="$(
  printf '%s' "$branch" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' \
    | cut -c1-48
)"
if [[ -z "$slug" ]]; then
  slug="worktree"
fi

export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-coterm-db-${slug}-${db_kind}-${coterm_port}}"
export COTERM_DB_CONTAINER_NAME="${COTERM_DB_CONTAINER_NAME:-coterm-postgres-${slug}-${db_kind}-${coterm_port}}"
export COTERM_DB_VOLUME_NAME="${COTERM_DB_VOLUME_NAME:-coterm-postgres-${slug}-${db_kind}-${coterm_port}}"
export COTERM_DB_PORT="$db_port"
export COTERM_DB_USER="$db_user"
export COTERM_DB_PASSWORD="$db_password"
export COTERM_DB_NAME="$db_name"
export DATABASE_URL="${DATABASE_URL:-postgres://${db_user}:${db_password}@localhost:${db_port}/${db_name}}"
export DIRECT_DATABASE_URL="${DIRECT_DATABASE_URL:-$DATABASE_URL}"

compose() {
  docker compose -f "$ROOT_DIR/docker-compose.db.yml" "$@"
}

wait_for_postgres() {
  for _ in $(seq 1 60); do
    if compose exec -T postgres pg_isready -U "$db_user" -d "$db_name" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "Timed out waiting for Postgres on localhost:${db_port}" >&2
  compose ps >&2 || true
  return 1
}

print_status() {
  local redacted_url
  redacted_url="postgres://${db_user}:<redacted>@localhost:${db_port}/${db_name}"
  cat <<EOF
COTERM_PORT=$coterm_port
COTERM_DB_KIND=$db_kind
COTERM_DB_PORT=$db_port
COMPOSE_PROJECT_NAME=$COMPOSE_PROJECT_NAME
COTERM_DB_CONTAINER_NAME=$COTERM_DB_CONTAINER_NAME
COTERM_DB_VOLUME_NAME=$COTERM_DB_VOLUME_NAME
DATABASE_URL=$redacted_url
EOF
}

case "$command" in
  up)
    compose up -d
    wait_for_postgres
    print_status
    ;;
  down)
    compose down
    ;;
  reset)
    compose down -v
    compose up -d
    wait_for_postgres
    print_status
    ;;
  status)
    print_status
    compose ps
    ;;
  migrate)
    "$0" up >/dev/null
    bunx drizzle-kit migrate --config "$ROOT_DIR/drizzle.config.ts"
    ;;
  ready)
    compose exec -T postgres pg_isready -U "$db_user" -d "$db_name" >/dev/null
    ;;
  test)
    env \
      -u COMPOSE_PROJECT_NAME \
      -u COTERM_DB_CONTAINER_NAME \
      -u COTERM_DB_VOLUME_NAME \
      -u COTERM_DB_PORT \
      -u DATABASE_URL \
      -u DIRECT_DATABASE_URL \
      COTERM_DB_KIND=test \
      COTERM_DB_PORT_OFFSET="${COTERM_TEST_DB_PORT_OFFSET:-30000}" \
      COTERM_DB_NAME="${COTERM_TEST_DB_NAME:-coterm_test}" \
      "$0" up >/dev/null
    export COTERM_DB_TEST=1
    export COTERM_DB_KIND=test
    export COTERM_DB_PORT_OFFSET="${COTERM_TEST_DB_PORT_OFFSET:-30000}"
    export COTERM_DB_NAME="${COTERM_TEST_DB_NAME:-coterm_test}"
    export COTERM_DB_PORT="$((coterm_port + ${COTERM_TEST_DB_PORT_OFFSET:-30000}))"
    export DATABASE_URL="postgres://${db_user}:${db_password}@localhost:${COTERM_DB_PORT}/${COTERM_DB_NAME}"
    export DIRECT_DATABASE_URL="$DATABASE_URL"
    bunx drizzle-kit migrate --config "$ROOT_DIR/drizzle.config.ts"
    bunx drizzle-kit migrate --config "$ROOT_DIR/drizzle.config.ts"
    bash "$ROOT_DIR/scripts/run-db-behavior-tests.sh"
    ;;
  url)
    printf '%s\n' "$DATABASE_URL"
    ;;
  *)
    echo "Usage: bun db:{up,down,reset,status,migrate,ready,test}" >&2
    exit 2
    ;;
esac
