#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERVAL_DAYS="${EXTEND_INTERVAL_DAYS:-15}"
STATE_DIR="${EXTEND_STATE_DIR:-$PROJECT_DIR/.cron-state}"
LOG_DIR="${EXTEND_LOG_DIR:-$PROJECT_DIR/logs}"
NPM_BIN="${NPM_BIN:-npm}"

# Optional: path to a per-account env file to source before running npm.
# Set by extend-all-accounts.sh, or pass manually: ENV_FILE=.env.alice bash extend-if-due.sh
ENV_FILE="${ENV_FILE:-}"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S %z"
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

mkdir -p "$STATE_DIR" "$LOG_DIR"

# Source the account env file if provided. Exported vars take precedence over .env (dotenv won't override).
if [[ -n "$ENV_FILE" ]]; then
  if [[ ! -f "$ENV_FILE" ]]; then
    echo "[$(timestamp)] ERROR: ENV_FILE not found: $ENV_FILE" >&2
    exit 1
  fi
  set -a
  # shellcheck source=/dev/null
  source "$ENV_FILE"
  set +a
fi

ACCOUNT_LABEL="${PYTHONANYWHERE_USERNAME:-unknown}"
LOG_FILE="$LOG_DIR/extend-if-due-${ACCOUNT_LABEL}.log"

exec >> "$LOG_FILE" 2>&1

# Per-account state and auth files.
LAST_SUCCESS_FILE="$STATE_DIR/last-extend-success-epoch-${ACCOUNT_LABEL}"
export PYTHONANYWHERE_AUTH_FILE="${PYTHONANYWHERE_AUTH_FILE:-$PROJECT_DIR/.auth/${ACCOUNT_LABEL}.json}"

echo ""
echo "[$(timestamp)] [account: $ACCOUNT_LABEL] ======== Starting extend-if-due run ========"
if [[ -n "$ENV_FILE" ]]; then
  echo "[$(timestamp)] [account: $ACCOUNT_LABEL] Sourced env file: $ENV_FILE"
fi
echo "[$(timestamp)] [account: $ACCOUNT_LABEL] State file:       $LAST_SUCCESS_FILE"
echo "[$(timestamp)] [account: $ACCOUNT_LABEL] Auth file:        $PYTHONANYWHERE_AUTH_FILE"
echo "[$(timestamp)] [account: $ACCOUNT_LABEL] Interval:         ${INTERVAL_DAYS} days"

if ! is_positive_integer "$INTERVAL_DAYS"; then
  echo "[$(timestamp)] [account: $ACCOUNT_LABEL] ERROR: EXTEND_INTERVAL_DAYS must be a positive integer. Got: $INTERVAL_DAYS"
  exit 1
fi

now_epoch="$(date +%s)"
required_seconds="$((INTERVAL_DAYS * 24 * 60 * 60))"

if [[ -f "$LAST_SUCCESS_FILE" ]]; then
  last_success_epoch="$(<"$LAST_SUCCESS_FILE")"

  if [[ "$last_success_epoch" =~ ^[0-9]+$ ]]; then
    elapsed_seconds="$((now_epoch - last_success_epoch))"
    elapsed_days="$((elapsed_seconds / 86400))"

    if (( elapsed_seconds < required_seconds )); then
      days_until_next="$(( (required_seconds - elapsed_seconds) / 86400 ))"
      echo "[$(timestamp)] [account: $ACCOUNT_LABEL] SKIPPED — last extend was ${elapsed_days} day(s) ago; next check in ~${days_until_next} day(s)."
      echo "[$(timestamp)] [account: $ACCOUNT_LABEL] ======== Run complete (skipped) ========"
      exit 0
    else
      echo "[$(timestamp)] [account: $ACCOUNT_LABEL] Last extend was ${elapsed_days} day(s) ago — interval reached, proceeding."
    fi
  else
    echo "[$(timestamp)] [account: $ACCOUNT_LABEL] Ignoring invalid state file value: $last_success_epoch"
  fi
else
  echo "[$(timestamp)] [account: $ACCOUNT_LABEL] No previous state file found — this appears to be the first run."
fi

cd "$PROJECT_DIR"

echo "[$(timestamp)] [account: $ACCOUNT_LABEL] Running npm run get-date..."
get_date_start="$(date +%s)"
if ! get_date_output="$("$NPM_BIN" run --silent get-date 2>&1)"; then
  get_date_elapsed="$(( $(date +%s) - get_date_start ))"
  printf "%s\n" "$get_date_output"
  echo "[$(timestamp)] [account: $ACCOUNT_LABEL] npm run get-date FAILED after ${get_date_elapsed}s. Skipping npm run extend."
  echo "[$(timestamp)] [account: $ACCOUNT_LABEL] ======== Run complete (FAILED) ========"
  exit 1
fi
get_date_elapsed="$(( $(date +%s) - get_date_start ))"
printf "%s\n" "$get_date_output"
echo "[$(timestamp)] [account: $ACCOUNT_LABEL] npm run get-date finished in ${get_date_elapsed}s."

if [[ -z "${get_date_output//[[:space:]]/}" ]]; then
  echo "[$(timestamp)] [account: $ACCOUNT_LABEL] npm run get-date returned no output — site may be disabled. Skipping npm run extend."
  echo "[$(timestamp)] [account: $ACCOUNT_LABEL] ======== Run complete (skipped — no date output) ========"
  exit 1
fi

echo "[$(timestamp)] [account: $ACCOUNT_LABEL] Running npm run extend..."
extend_start="$(date +%s)"
"$NPM_BIN" run extend
extend_elapsed="$(( $(date +%s) - extend_start ))"
echo "[$(timestamp)] [account: $ACCOUNT_LABEL] npm run extend finished in ${extend_elapsed}s."

date +%s > "$LAST_SUCCESS_FILE"
echo "[$(timestamp)] [account: $ACCOUNT_LABEL] SUCCESS — state file updated."
echo "[$(timestamp)] [account: $ACCOUNT_LABEL] ======== Run complete (SUCCESS) ========"
