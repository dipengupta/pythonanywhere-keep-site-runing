#!/usr/bin/env bash
# Entry point for the cron job when running multiple accounts.
# Discovers all .env.<name> files in the project root (excluding .env.example)
# and calls extend-if-due.sh for each one.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="${EXTEND_LOG_DIR:-$PROJECT_DIR/logs}"

mkdir -p "$LOG_DIR"
SUMMARY_LOG="$LOG_DIR/extend-all-accounts.log"

timestamp() {
  date "+%Y-%m-%d %H:%M:%S %z"
}

exec >> "$SUMMARY_LOG" 2>&1

echo ""
echo "[$(timestamp)] ======== extend-all-accounts: starting run ========"

# Collect all .env.* files, excluding .env.example and bare .env
env_files=()
for f in "$PROJECT_DIR"/.env.*; do
  [[ -f "$f" ]] || continue
  basename_f="$(basename "$f")"
  [[ "$basename_f" == ".env.example" ]] && continue
  env_files+=("$f")
done

if (( ${#env_files[@]} == 0 )); then
  echo "[$(timestamp)] No account env files found (expected .env.<name> files in $PROJECT_DIR)."
  echo "[$(timestamp)] ======== extend-all-accounts: done (no accounts) ========"
  exit 0
fi

echo "[$(timestamp)] Found ${#env_files[@]} account file(s): $(printf '%s ' "${env_files[@]}" | xargs -n1 basename | tr '\n' ' ')"

declare -A results

for env_file in "${env_files[@]}"; do
  account_name="$(basename "$env_file" | sed 's/^\.env\.//')"
  echo "[$(timestamp)] --- Processing account: $account_name ($env_file) ---"

  if ENV_FILE="$env_file" bash "$SCRIPT_DIR/extend-if-due.sh"; then
    results["$account_name"]="OK"
  else
    results["$account_name"]="FAILED"
    echo "[$(timestamp)] extend-if-due.sh exited with an error for account: $account_name"
  fi
done

echo "[$(timestamp)] ======== extend-all-accounts: all accounts done ========"
summary_parts=()
for account in "${!results[@]}"; do
  summary_parts+=("${account}=${results[$account]}")
done
echo "[$(timestamp)] Summary: $(IFS=', '; echo "${summary_parts[*]}")"
