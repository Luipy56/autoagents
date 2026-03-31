#!/usr/bin/env bash
# Quick checks: GET /api/tags and POST /api/generate (non-streaming).
# Usage: load .env from repo root or export OLLAMA_API_BASE and JARVYS_OLLAMA_MODEL.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT/.env"
  set +a
fi

BASE="${OLLAMA_API_BASE:-http://127.0.0.1:11434}"
MODEL="${JARVYS_OLLAMA_MODEL:-qwen3:latest}"

echo "OLLAMA_API_BASE=$BASE"
echo "JARVYS_OLLAMA_MODEL=$MODEL"
echo "---- GET /api/tags ----"
curl -sS -f "$BASE/api/tags" | head -c 4000
echo ""
echo "---- POST /api/generate (smoke) ----"
curl -sS -f "$BASE/api/generate" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"prompt\":\"Reply with exactly: Hello world\",\"stream\":false}" \
  | head -c 2000
echo ""
