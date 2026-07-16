#!/usr/bin/env bash
# bin/freshchat_import.sh
#
# Reusable launcher for the Freshchat → Chatwoot import rake task. Designed to
# be run detached on the Azure VM so the operator can disconnect (`nohup … &`,
# tmux, systemd-run, etc.) and check the log later from anywhere.
#
# Usage:
#   bin/freshchat_import.sh <inbox_id> <channels|pipe-separated> [dry|real] [limit] [since] [only_actor_first_name]
#
# since values:
#   ""                       (default) auto: importer reads its sync-state
#                            marker file at log/freshchat/sync_state/inbox-<id>.json
#                            and uses last_message_imported_at; on first run does
#                            a full scan.
#   "full"                   force a full re-scan (ignore the marker file).
#   "<ISO8601>"              explicit lower bound (e.g. 2026-05-27T18:00:00Z).
#
# only_actor_first_name:
#   ""                       (default) no filter — import all customers in scope.
#   "<name>"                 import only source convs where at least one user
#                            message has actor_first_name = <name>. Marker file
#                            is NOT advanced for targeted runs.
#
# Examples:
#   bin/freshchat_import.sh 3 "Lazada IM" dry           # dry-run, auto-since (rolls back)
#   bin/freshchat_import.sh 3 "Lazada IM"               # real import, auto-since
#   bin/freshchat_import.sh 2 "LINE - TRP|LINE"         # multi-channel LINE, auto-since
#   bin/freshchat_import.sh 22 "IG_therollingpinn" real 100   # limit to 100 convs
#   bin/freshchat_import.sh 3 "Lazada IM" real "" full  # force full re-scan
#   bin/freshchat_import.sh 3 "Lazada IM" real "" 2026-05-27T18:00:00Z   # explicit since
#   bin/freshchat_import.sh 31 "IG_therollingpinn" real "" "" "shrihari.12"   # targeted single-customer test
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
SINCE="${5:-}"
ONLY_FIRST_NAME="${6:-}"

if [[ -z "$INBOX_ID" || -z "$CHANNELS" ]]; then
  echo "Usage: $0 <inbox_id> <channels|pipe-separated> [dry|real] [limit] [since] [only_actor_first_name]" >&2
  exit 2
fi

# Put RVM-installed Ruby on PATH directly (bypassing rvm's strict-mode-hostile
# bash scripting). No-op locally if the path doesn't exist.
if [[ -d /usr/local/rvm/rubies/ruby-3.4.4/bin ]]; then
  export PATH="/usr/local/rvm/gems/ruby-3.4.4/bin:/usr/local/rvm/gems/ruby-3.4.4@global/bin:/usr/local/rvm/rubies/ruby-3.4.4/bin:$PATH"
  export GEM_HOME="/usr/local/rvm/gems/ruby-3.4.4"
  export GEM_PATH="/usr/local/rvm/gems/ruby-3.4.4:/usr/local/rvm/gems/ruby-3.4.4@global"
fi

CHATWOOT_ROOT="${CHATWOOT_ROOT:-/home/chatwoot/chatwoot}"
cd "$CHATWOOT_ROOT"

# Extract just the FRESHCHAT_DB_* lines from .env (a blanket `source .env`
# trips on shell-unsafe values elsewhere in the file; Rails+dotenv loads the
# rest at rake-task boot anyway).
if [[ -f .env ]]; then
  while IFS='=' read -r key val; do
    case "$key" in
      FRESHCHAT_DB_HOST|FRESHCHAT_DB_PORT|FRESHCHAT_DB_NAME|FRESHCHAT_DB_USER|FRESHCHAT_DB_PASSWORD)
        # Strip surrounding single or double quotes if present
        val="${val%\"}"; val="${val#\"}"
        val="${val%\'}"; val="${val#\'}"
        export "$key=$val"
        ;;
    esac
  done < <(grep -E '^FRESHCHAT_DB_' .env || true)
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

# Compose the rake bracket-arg string. Rake's positional-args syntax means we
# need empty placeholders for any earlier arg we want to skip; build them all.
MODE_TOKEN=""
if [[ "$MODE" == "dry" ]]; then MODE_TOKEN="dry"; fi
RAKE_ARGS="$INBOX_ID,$CHANNELS,$MODE_TOKEN,$LIMIT,$SINCE,$ONLY_FIRST_NAME"
# Trim any run of trailing empty placeholders
while [[ "$RAKE_ARGS" == *,, ]] || [[ "$RAKE_ARGS" == *, ]]; do
  RAKE_ARGS="${RAKE_ARGS%,}"
done

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
