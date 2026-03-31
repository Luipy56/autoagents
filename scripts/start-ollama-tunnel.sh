#!/usr/bin/env bash
# Optional: SSH LocalForward to a remote Ollama host. Not needed for local Ollama.
# Loads bundle .env; uses scripts/jarvys-tunnel-lib.sh (set JARVYS_TUNNEL_STYLE and SSH vars — see .env.example / docs/jarvys-network.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
load_dotenv() {
  [[ -f "$1" ]] || return 0
  set -a
  # shellcheck source=/dev/null
  source "$1"
  set +a
}
if [[ "$(basename "$ROOT")" == "jarvys-team" ]]; then
  load_dotenv "$(cd "$ROOT/.." && pwd)/.env"
fi
load_dotenv "$ROOT/.env"

# shellcheck source=/dev/null
source "${ROOT}/scripts/jarvys-tunnel-lib.sh"

LOCAL="${JARVYS_SSH_LOCAL_PORT:-11434}"
echo "Tunnel: $(jarvys_tunnel_describe)"
echo "Local: OLLAMA_API_BASE=http://127.0.0.1:${LOCAL}"
echo "Ctrl+C to stop."

ssh_cmd=()
jarvys_fill_ssh_tunnel_argv ssh_cmd 1
exec "${ssh_cmd[@]}"
