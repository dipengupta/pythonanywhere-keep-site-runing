#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERVAL_DAYS="${EXTEND_INTERVAL_DAYS:-15}"
STATE_DIR="${EXTEND_STATE_DIR:-$PROJECT_DIR/.cron-state}"
LOG_DIR="${EXTEND_LOG_DIR:-$PROJECT_DIR/logs}"
LAST_SUCCESS_FILE="$STATE_DIR/last-extend-success-epoch"
NPM_BIN="${NPM_BIN:-npm}"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S %z"
}

is_positive_integer() {
  [[ "$1" =~ ^[1-9][0-9]*$ ]]
}

mkdir -p "$STATE_DIR" "$LOG_DIR"
exec >> "$LOG_DIR/extend-if-due.log" 2>&1

echo "[$(timestamp)] Checking whether PythonAnywhere extend is due."

if ! is_positive_integer "$INTERVAL_DAYS"; then
  echo "[$(timestamp)] EXTEND_INTERVAL_DAYS must be a positive integer. Got: $INTERVAL_DAYS"
  exit 1
fi

now_epoch="$(date +%s)"
required_seconds="$((INTERVAL_DAYS * 24 * 60 * 60))"

if [[ -f "$LAST_SUCCESS_FILE" ]]; then
  last_success_epoch="$(<"$LAST_SUCCESS_FILE")"

  if [[ "$last_success_epoch" =~ ^[0-9]+$ ]]; then
    elapsed_seconds="$((now_epoch - last_success_epoch))"

    if (( elapsed_seconds < required_seconds )); then
      elapsed_days="$((elapsed_seconds / 86400))"
      echo "[$(timestamp)] Last successful extend was $elapsed_days day(s) ago. Skipping until $INTERVAL_DAYS days have passed."
      exit 0
    fi
  else
    echo "[$(timestamp)] Ignoring invalid state file value: $last_success_epoch"
  fi
fi

cd "$PROJECT_DIR"

echo "[$(timestamp)] Running npm run get-date."
if ! get_date_output="$("$NPM_BIN" run --silent get-date 2>&1)"; then
  printf "%s\n" "$get_date_output"
  echo "[$(timestamp)] npm run get-date failed. Skipping npm run extend."
  exit 1
fi

printf "%s\n" "$get_date_output"

if [[ -z "${get_date_output//[[:space:]]/}" ]]; then
  echo "[$(timestamp)] npm run get-date returned no output. Skipping npm run extend."
  exit 1
fi

echo "[$(timestamp)] npm run get-date returned output. Running npm run extend."
"$NPM_BIN" run extend

date +%s > "$LAST_SUCCESS_FILE"
echo "[$(timestamp)] npm run extend completed successfully."
