#!/usr/bin/env bash
# Sync local checkout with origin/<branch> (fetch + pull --rebase).
# Copy lives in Jarvys bundle; target repo should keep this under scripts/ at repo root.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "${AGENT_GIT_SYNC:-1}" == "0" ]]; then
  exit 0
fi

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "git-sync-agent-branch: not a git repository: $ROOT" >&2
  exit 1
fi

BRANCH="${AGENT_GIT_BRANCH:-agentdevelop}"

git fetch origin

if ! git rev-parse --verify --quiet "origin/${BRANCH}" >/dev/null; then
  echo "git-sync-agent-branch: origin/${BRANCH} missing after fetch" >&2
  exit 1
fi

current="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
if [[ "$current" != "$BRANCH" ]]; then
  if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git checkout "$BRANCH"
  else
    git checkout -b "$BRANCH" "origin/${BRANCH}"
  fi
fi

git pull --rebase --autostash "origin" "$BRANCH"
