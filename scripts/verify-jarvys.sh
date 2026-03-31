#!/usr/bin/env bash
# Sanity checks for the Jarvys bundle (orchestration only — does not run Aider against tasks).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== bash syntax =="
for f in jarvys-agent-loop.sh scripts/git-sync-agent-branch.sh scripts/move-agent-task-to-done.sh \
         scripts/smoke-ollama.sh scripts/start-ollama-tunnel.sh scripts/jarvys-tunnel-lib.sh; do
  bash -n "$f"
  echo "  OK $f"
done

echo "== aider =="
AIDER=""
if [[ -n "${JARVYS_AIDER:-}" && -x "${JARVYS_AIDER}" ]]; then
  AIDER="$JARVYS_AIDER"
elif [[ -x "$ROOT/.venv/bin/aider" ]]; then
  AIDER="$ROOT/.venv/bin/aider"
elif command -v aider >/dev/null 2>&1; then
  AIDER="$(command -v aider)"
fi
if [[ -n "$AIDER" ]]; then
  "$AIDER" --version
else
  echo "  WARN: no aider (pip install aider-chat or python3 -m venv .venv && .venv/bin/pip install aider-chat)" >&2
fi

echo "== done =="
echo "verify-jarvys: OK"
