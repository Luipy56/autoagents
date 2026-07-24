#!/usr/bin/env bash
# Move a CLOSED-* task from agents/tasks/ to agents/tasks/done/YYYY/MM/DD/
# using the YYYYMMDD segment in the filename (see agents/TASKS-README.md).
#
# Copy this file to the host repo as: scripts/move-agent-task-to-done.sh
#
# Usage (repo root):
#   ./scripts/move-agent-task-to-done.sh agents/tasks/CLOSED-20260323-1200-slug.md
#   ./scripts/move-agent-task-to-done.sh agents/tasks/CLOSED-178-20260413-1033-slug.md

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${1:-}" = "" ]; then
  echo "usage: $0 <path-to-CLOSED-*.md>" >&2
  exit 1
fi

TASK_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
BASENAME="$(basename "$TASK_PATH")"

YYYYMMDD=""
if [[ "$BASENAME" =~ ^CLOSED-[0-9]+-([0-9]{8})-[0-9]{4}- ]]; then
  YYYYMMDD="${BASH_REMATCH[1]}"
elif [[ "$BASENAME" =~ ^CLOSED-([0-9]{8})-[0-9]{4}- ]]; then
  YYYYMMDD="${BASH_REMATCH[1]}"
else
  echo "$0: expected CLOSED-YYYYMMDD-HHMM-slug.md or CLOSED-<issue>-YYYYMMDD-HHMM-slug.md, got: $BASENAME" >&2
  exit 1
fi

if [ ! -f "$TASK_PATH" ]; then
  echo "$0: file not found: $TASK_PATH" >&2
  exit 1
fi

TASKS_DIR="$REPO_ROOT/agents/tasks"
case "$TASK_PATH" in
  "$TASKS_DIR"/*) ;;
  *)
    echo "$0: file must live under agents/tasks/ (got $TASK_PATH)" >&2
    exit 1
    ;;
esac

YEAR="${YYYYMMDD:0:4}"
MONTH="${YYYYMMDD:4:2}"
DAY="${YYYYMMDD:6:2}"

if ! [[ "$YEAR" =~ ^[0-9]{4}$ && "$MONTH" =~ ^(0[1-9]|1[0-2])$ && "$DAY" =~ ^(0[1-9]|[12][0-9]|3[01])$ ]]; then
  echo "$0: could not parse YYYYMMDD from filename: $BASENAME" >&2
  exit 1
fi

DEST_DIR="$TASKS_DIR/done/$YEAR/$MONTH/$DAY"
mkdir -p "$DEST_DIR"

DEST_PATH="$DEST_DIR/$BASENAME"
if [ -e "$DEST_PATH" ]; then
  echo "$0: destination already exists: $DEST_PATH" >&2
  exit 1
fi

ENV_FILE="${REPO_ROOT}/agents/autoagents.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a && source "$ENV_FILE" && set +a
fi

if command -v python3 >/dev/null 2>&1 && [[ -f "${REPO_ROOT}/agents/redmine_sync.py" ]]; then
  echo "Posting Redmine closing note (and time_entry when duration is known)..."
  python3 "${REPO_ROOT}/agents/redmine_sync.py" note "$TASK_PATH" || \
    echo "Warning: Redmine note sync failed (archive continues)." >&2
fi

mv "$TASK_PATH" "$DEST_PATH"
echo "moved to agents/tasks/done/$YEAR/$MONTH/$DAY/$BASENAME"
