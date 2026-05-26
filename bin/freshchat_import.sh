#!/usr/bin/env bash
# bin/freshchat_import.sh
#
# Reusable launcher for the Freshchat → Chatwoot import rake task. Designed to
# be run detached on the Azure VM so the operator can disconnect (`nohup … &`,
# tmux, systemd-run, etc.) and check the log later from anywhere.
#
# Usage:
#   bin/freshchat_import.sh <inbox_id> <channels|pipe-separated> [dry|real] [limit]
#
# Examples:
#   bin/freshchat_import.sh 3 "Lazada IM" dry           # dry-run (rolls back)
#   bin/freshchat_import.sh 3 "Lazada IM"               # real import
#   bin/freshchat_import.sh 2 "LINE - TRP|LINE"         # multi-channel LINE
#   bin/freshchat_import.sh 22 "IG_therollingpinn" real 100   # limit to 100 convs
#
# Recommended invocation on the Azure VM (so the script outlives your SSH session):
#   mkdir -p log/freshchat
#   LOG="log/freshchat/lazada-$(date +%Y%m%d-%H%M%S).log"
#   nohup ./bin/freshchat_import.sh 3 "Lazada IM" dry >"$LOG" 2>&1 </dev/null &
#   echo "PID=$! LOG=$LOG"
#
# Then from any device:
#   ssh chatwoot@<host> "tail -f /home/chatwoot/chatwoot/$LOG"

set -euo pipefail

INBOX_ID="${1:-}"
CHANNELS="${2:-}"
MODE="${3:-real}"
LIMIT="${4:-}"

if [[ -z "$INBOX_ID" || -z "$CHANNELS" ]]; then
  echo "Usage: $0 <inbox_id> <channels|pipe-separated> [dry|real] [limit]" >&2
  exit 2
fi

# Activate Ruby (RVM-managed on the Azure VM). No-op locally if RVM absent.
if [[ -f /usr/local/rvm/scripts/rvm ]]; then
  # shellcheck source=/dev/null
  source /usr/local/rvm/scripts/rvm
  rvm use 3.4.4 >/dev/null
fi

CHATWOOT_ROOT="${CHATWOOT_ROOT:-/home/chatwoot/chatwoot}"
cd "$CHATWOOT_ROOT"

# Load Chatwoot's .env so FRESHCHAT_DB_* propagate to the rake process.
if [[ -f .env ]]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
fi

# Verify Freshchat creds are present before doing anything destructive.
missing=()
for var in FRESHCHAT_DB_HOST FRESHCHAT_DB_NAME FRESHCHAT_DB_USER FRESHCHAT_DB_PASSWORD; do
  if [[ -z "${!var:-}" ]]; then
    missing+=("$var")
  fi
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "ERROR: required env vars not set in $CHATWOOT_ROOT/.env: ${missing[*]}" >&2
  exit 3
fi

# Compose the rake bracket-arg string.
RAKE_ARGS="$INBOX_ID,$CHANNELS"
if [[ "$MODE" == "dry" ]]; then
  RAKE_ARGS="$RAKE_ARGS,dry"
  if [[ -n "$LIMIT" ]]; then
    RAKE_ARGS="$RAKE_ARGS,$LIMIT"
  fi
elif [[ -n "$LIMIT" ]]; then
  RAKE_ARGS="$RAKE_ARGS,,$LIMIT"
fi

echo "==============================================================="
echo "[$(date -Iseconds)] Starting: freshchat:import[$RAKE_ARGS]"
echo "  host=$(hostname)  pid=$$  user=$(whoami)"
echo "  ruby=$(ruby -v)"
echo "==============================================================="

RAILS_ENV=production bundle exec rails "freshchat:import[$RAKE_ARGS]"
status=$?

echo "==============================================================="
echo "[$(date -Iseconds)] Exited with status $status"
echo "==============================================================="
exit "$status"
