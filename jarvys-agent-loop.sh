#!/usr/bin/env bash
# Jarvys Team agent loop — same orchestration as laravel-ecommerce-agent-loop.sh;
# run_agent uses Aider + Ollama instead of cursor-agent.
#
# Run from repo root (if this file lives under agents/):
#   ./agents/jarvys-agent-loop.sh [COMMAND]
# Or from this package root:
#   ./jarvys-agent-loop.sh [COMMAND]
#
# Requires: aider on PATH (pip install aider-chat), Ollama reachable via OLLAMA_API_BASE.
# Task dir: agents/tasks/ (sibling of agents/ when script is under agents/).

set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"

if [[ "$(basename "$SCRIPTDIR")" == "agents" ]]; then
  REPO_ROOT="$(cd "${SCRIPTDIR}/.." && pwd)"
  TASKDIR="${SCRIPTDIR}/tasks"
  AGENT_PROMPT_ROOT="${SCRIPTDIR}"
else
  REPO_ROOT="${JARVYS_REPO_ROOT:-$SCRIPTDIR}"
  TASKDIR="${SCRIPTDIR}/agents/tasks"
  AGENT_PROMPT_ROOT="${SCRIPTDIR}/agents"
fi

load_env() {
  for d in "$SCRIPTDIR" "$REPO_ROOT"; do
    if [[ -f "$d/.env" ]]; then
      set -a
      # shellcheck source=/dev/null
      source "$d/.env"
      set +a
      break
    fi
  done
}

# Values exported in the invoking shell win over the same keys in .env (one-off overrides).
if [[ -n ${JARVYS_OLLAMA_MODEL+x} ]]; then _jarvys_cli_model="$JARVYS_OLLAMA_MODEL"; fi
if [[ -n ${OLLAMA_API_BASE+x} ]]; then _jarvys_cli_ollama_base="$OLLAMA_API_BASE"; fi
if [[ -n ${AGENT_GIT_SYNC+x} ]]; then _jarvys_cli_git_sync="$AGENT_GIT_SYNC"; fi
load_env
if [[ -n ${_jarvys_cli_model+x} ]]; then export JARVYS_OLLAMA_MODEL="$_jarvys_cli_model"; fi
if [[ -n ${_jarvys_cli_ollama_base+x} ]]; then export OLLAMA_API_BASE="$_jarvys_cli_ollama_base"; fi
if [[ -n ${_jarvys_cli_git_sync+x} ]]; then export AGENT_GIT_SYNC="$_jarvys_cli_git_sync"; fi
unset _jarvys_cli_model _jarvys_cli_ollama_base _jarvys_cli_git_sync

if [[ -d "${REPO_ROOT}/scripts" ]]; then
  JARVYS_SCRIPTS_DIR="${REPO_ROOT}/scripts"
else
  JARVYS_SCRIPTS_DIR="${SCRIPTDIR}/scripts"
fi
# shellcheck source=/dev/null
if [[ -f "${JARVYS_SCRIPTS_DIR}/jarvys-tunnel-lib.sh" ]]; then
  source "${JARVYS_SCRIPTS_DIR}/jarvys-tunnel-lib.sh"
else
  echo "ERROR: missing ${JARVYS_SCRIPTS_DIR}/jarvys-tunnel-lib.sh" >&2
  exit 1
fi

sleepminutes="${AGENT_LOOP_SLEEP_MINUTES:-5}"
sleepseconds=$((sleepminutes * 60))

cd "$SCRIPTDIR" || exit 1

# Ollama / Aider: https://aider.chat/docs/llms/ollama.html
export OLLAMA_API_BASE="${OLLAMA_API_BASE:-http://127.0.0.1:11434}"
JARVYS_OLLAMA_MODEL="${JARVYS_OLLAMA_MODEL:-qwen3:latest}"

ollama_base_norm() {
  local b="${OLLAMA_API_BASE:-http://127.0.0.1:11434}"
  b="${b%/}"
  printf '%s' "$b"
}

ollama_tags_url() {
  printf '%s/api/tags' "$(ollama_base_norm)"
}

ollama_reachable() {
  curl -sf --connect-timeout 2 --max-time 8 "$(ollama_tags_url)" >/dev/null 2>&1
}

try_auto_ssh_tunnel() {
  [[ "${JARVYS_AUTO_SSH_TUNNEL:-0}" == "1" ]] || return 1
  local local_p="${JARVYS_SSH_LOCAL_PORT:-11434}"

  ollama_reachable && return 0

  echo "-----> Jarvys: Ollama not responding at $(ollama_base_norm); starting SSH tunnel: $(jarvys_tunnel_describe)" >&2

  local -a ssh_cmd=()
  if ! jarvys_fill_ssh_tunnel_argv ssh_cmd 0; then
    return 1
  fi
  if ! "${ssh_cmd[@]}"; then
    echo "Jarvys: SSH tunnel failed. Check keys and JARVYS_TUNNEL_STYLE (amvara8_local vs amvara4_forward). See docs/jarvys-network.md" >&2
    return 1
  fi
  sleep 2
  if ollama_reachable; then
    echo "-----> Jarvys: Ollama reachable after tunnel." >&2
    return 0
  fi
  echo "Jarvys: Tunnel started but GET /api/tags still failed. Match OLLAMA_API_BASE to port ${local_p}; for amvara4_forward set JARVYS_OLLAMA_REMOTE_HOST to amvara8 as seen from amvara4." >&2
  return 1
}

ensure_ollama_before_aider() {
  ollama_reachable && return 0
  try_auto_ssh_tunnel && return 0
  cat >&2 <<EOF
ERROR: Ollama unreachable at $(ollama_base_norm).

Local: start Ollama on this machine and ensure it listens on OLLAMA_API_BASE (see https://ollama.com).

Remote via SSH: set JARVYS_AUTO_SSH_TUNNEL=1 and tunnel vars in .env, or run ./scripts/start-ollama-tunnel.sh — docs/jarvys-network.md.

Test: curl -sS '$(ollama_tags_url)'

EOF
  return 1
}

cmd_ollama_check() {
  echo "-----> Ollama check: $(ollama_tags_url)"
  if ! ollama_reachable; then
    echo "-----> Not reachable; trying auto tunnel (JARVYS_AUTO_SSH_TUNNEL=${JARVYS_AUTO_SSH_TUNNEL:-0})..."
    try_auto_ssh_tunnel || true
  fi
  if ! ollama_reachable; then
    echo "ERROR: /api/tags failed" >&2
    exit 1
  fi
  echo "-----> GET /api/tags OK"
  local model="${JARVYS_OLLAMA_MODEL:-qwen3:latest}"
  echo "-----> POST /api/generate smoke (model=${model})..."
  local genout
  genout="$(mktemp)"
  if ! curl -sf --connect-timeout 5 --max-time 300 "$(ollama_base_norm)/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"${model}\",\"prompt\":\"Reply with exactly: Hello world\",\"stream\":false}" \
    -o "$genout"; then
    rm -f "$genout"
    echo "ERROR: POST /api/generate failed" >&2
    exit 1
  fi
  head -c 800 "$genout"
  rm -f "$genout"
  echo ""
  echo "-----> ollama-check: OK"
}

aider_bin() {
  if [[ -n "${JARVYS_AIDER:-}" ]]; then
    echo "$JARVYS_AIDER"
    return
  fi
  if command -v aider >/dev/null 2>&1; then
    command -v aider
    return
  fi
  if [[ -x "${SCRIPTDIR}/.venv/bin/aider" ]]; then
    echo "${SCRIPTDIR}/.venv/bin/aider"
    return
  fi
  echo ""
}

have_aider() {
  [[ -n "$(aider_bin)" ]]
}

sync_repo() {
  if [[ "${AGENT_GIT_SYNC:-1}" == "0" ]]; then
    echo "----- git sync (skip: AGENT_GIT_SYNC=0)"
    return 0
  fi
  local sync_script="${REPO_ROOT}/scripts/git-sync-agent-branch.sh"
  if [[ ! -f "$sync_script" ]]; then
    echo "ERROR: missing $sync_script (copy scripts/ from Jarvys bundle or set AGENT_GIT_SYNC=0)" >&2
    exit 1
  fi
  echo "-----> git sync agent branch $(date "+%Y-%m-%d %H:%M:%S") <----"
  if ! bash "$sync_script"; then
    echo "ERROR: git sync failed (conflicts, network, or missing origin branch). Resolve and retry." >&2
    exit 1
  fi
}

# Build `aider --read …` args so the model sees current task files (not only the role prompt).
jarvys_fill_aider_read_args() {
  local -n _jarvys_reads_out="$1"
  local prompt="$2"
  _jarvys_reads_out=()
  case "$prompt" in
    002-coder/CODER.md)
      while IFS= read -r -d '' f; do
        _jarvys_reads_out+=(--read "$f")
      done < <(find "$TASKDIR" -maxdepth 1 \( -name 'NEW-*.md' -o -name 'WIP-*.md' \) -print0 2>/dev/null | sort -z)
      ;;
    006-feature-coder/FEATURE-CODER.md)
      while IFS= read -r -d '' f; do
        _jarvys_reads_out+=(--read "$f")
      done < <(find "$TASKDIR" -maxdepth 1 -name 'FEAT-*.md' -print0 2>/dev/null | sort -z)
      ;;
    003-tester/TESTER.md)
      while IFS= read -r -d '' f; do
        _jarvys_reads_out+=(--read "$f")
      done < <(find "$TASKDIR" -maxdepth 1 -name 'UNTESTED-*.md' -print0 2>/dev/null | sort -z)
      ;;
    004-closing-reviewer/CLOSING-REVIEWER-PROMPT.md)
      while IFS= read -r -d '' f; do
        _jarvys_reads_out+=(--read "$f")
      done < <(find "$TASKDIR" -maxdepth 1 -name 'CLOSED-*.md' -print0 2>/dev/null | sort -z)
      ;;
  esac
}

# Prompt paths are relative to AGENT_PROMPT_ROOT (agents/).
run_agent_jarvys() {
  local desc="$1" cond="$2" prompt="$3" msg="$4"
  local p="${AGENT_PROMPT_ROOT}/${prompt}"
  if [[ ! -f "$p" ]]; then
    echo "----- $desc (skip: missing prompt $prompt — see README.md)"
    return 0
  fi
  if ! have_aider; then
    echo "----- $desc (skip: aider not on PATH — pip install aider-chat)"
    return 0
  fi
  if eval "$cond" 2>/dev/null; then
    echo "-----> $desc $(date "+%Y-%m-%d %H:%M:%S") <----"
    if ! ensure_ollama_before_aider; then
      exit 1
    fi
    local msgfile
    msgfile="$(mktemp)"
    printf '%s\n\n---\n\nOperator instruction: %s\n' "$(cat "$p")" "$msg" > "$msgfile"
    local -a read_args=()
    jarvys_fill_aider_read_args read_args "$prompt"
    (cd "$REPO_ROOT" && OLLAMA_API_BASE="$OLLAMA_API_BASE" \
      "$(aider_bin)" --model "ollama_chat/${JARVYS_OLLAMA_MODEL}" --yes \
      --no-show-model-warnings \
      --no-show-release-notes \
      "${read_args[@]}" \
      --message-file "$msgfile")
    rm -f "$msgfile"
  else
    echo "----- $desc (skip: nothing to do)"
  fi
  echo "<-- end of $desc $(date "+%Y-%m-%d %H:%M:%S") -->"
  echo "--------------------------------"
  echo ""
}

step_log_reviewer() {
  sync_repo
  echo "-----> log reviewer (001) <----"
  run_agent_jarvys "log reviewer (001)" \
    "true" \
    "001-log-reviewer/LOG-REVIEWER-PROMPT.md" \
    "Run 001: (A) GitHub — up to 3 open issues → create FEAT-*.md only (feature coders). (B) Laravel logs / runtime — NEW-*.md only for real incidents. gh comment/label on issues when applicable. Do your job."
}

step_feat() {
  sync_repo
  echo "-----> feature coding (FEAT) <----"
  run_agent_jarvys "feature coding (FEAT)" \
    "test -n \"\$(find \"$TASKDIR\" -maxdepth 1 -name 'FEAT-*.md' 2>/dev/null)\"" \
    "006-feature-coder/FEATURE-CODER.md" \
    "Start feature coding now. Pick up a FEAT task if any. Do your job."
}

step_coder() {
  sync_repo
  echo "-----> coding (NEW / WIP) <----"
  run_agent_jarvys "coding" \
    "test -n \"\$(find \"$TASKDIR\" -maxdepth 1 \\( -name 'NEW-*.md' -o -name 'WIP-*.md' \\) 2>/dev/null)\"" \
    "002-coder/CODER.md" \
    "Start coding now. Prefer a NEW task if any (rename to WIP on start); otherwise continue an existing WIP to UNTESTED. Implement in this repo (app/, routes/, resources/js/, tests/, database/ as applicable). Use only real repository-relative paths (e.g. agents/tasks/, scripts/); never invent a path/to/ or path/to/scripts/ prefix. Do your job."
}

step_tester() {
  sync_repo
  echo "-----> testing <----"
  run_agent_jarvys "testing" \
    "test -n \"\$(find \"$TASKDIR\" -maxdepth 1 -name 'UNTESTED-*.md' 2>/dev/null)\"" \
    "003-tester/TESTER.md" \
    "Start testing now. Pick up an UNTESTED task if any. Do your job."
}

step_closing_review() {
  sync_repo
  echo "-----> closing reviewer (CLOSED in tasks/) <----"
  run_agent_jarvys "closing" \
    "test -n \"\$(find \"$TASKDIR\" -maxdepth 1 -name 'CLOSED-*.md' 2>/dev/null)\"" \
    "004-closing-reviewer/CLOSING-REVIEWER-PROMPT.md" \
    "Start closing review now. Process CLOSED-*.md in agents/tasks/; prepend summary; move to done/YYYY/MM/DD with scripts/move-agent-task-to-done.sh when done. Do your job."
}

step_committer() {
  sync_repo
  echo "-----> committer (changelog + commit) <----"
  run_agent_jarvys "committer (changelog + commit)" \
    "cd \"$REPO_ROOT\" && { ! git diff --quiet 2>/dev/null || ! git diff --staged --quiet 2>/dev/null; }" \
    "007-committer/COMMITTER.md" \
    "Check this repo for uncommitted changes on the integration branch (default agentdevelop; override with AGENT_GIT_BRANCH). Update CHANGELOG.md and root package.json per project rules; commit. Push origin. Merge to master only per GLOBAL_RULES.md (2h batch, big prod change, production-urgent issue, or explicit user ask)."
}

run_full_cycle() {
  echo "$(date)"
  step_log_reviewer
  local i
  for i in 1 2 3 4 5; do
    step_feat
  done
  step_coder
  step_tester
  step_closing_review
  step_committer
}

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [COMMAND]

  (no args)       Run full agent cycle every ${AGENT_LOOP_SLEEP_MINUTES:-5} minutes (loop).

  Single run:
    log, log-reviewer, 001   Log / incident reviewer (001; runs first in full cycle)
    feat, feature   Feature coder (FEAT-*.md in agents/tasks/)
    coder           Coder (NEW-*.md or WIP-*.md)
    tester          Tester (UNTESTED-*.md)
    closing-review  Closing reviewer (CLOSED-*.md still in agents/tasks/)
    committer       Changelog + commit when repo has local changes

    ollama-check   Verify Ollama (GET /api/tags + POST /api/generate hello); may auto-start SSH tunnel if JARVYS_AUTO_SSH_TUNNEL=1

    help, -h, --help   Show this help

Environment:
  AGENT_LOOP_SLEEP_MINUTES   Sleep between full cycles when looping (default: 5).
  AGENT_GIT_SYNC             If 0, skip git fetch/pull before each step (default: 1).
  AGENT_GIT_BRANCH           Integration branch (default: agentdevelop).
  OLLAMA_API_BASE            Ollama base URL (default: http://127.0.0.1:11434).
  JARVYS_OLLAMA_MODEL        Model tag for aider (default: qwen3:latest).
  JARVYS_REPO_ROOT           When script is not under agents/, repo root (default: same dir as script).
  JARVYS_AIDER               Full path to aider binary (optional; else PATH or ./.venv/bin/aider).
  JARVYS_AUTO_SSH_TUNNEL     If 1, try ssh -f -L before Aider when /api/tags fails (default: 0 = local Ollama only).
  JARVYS_TUNNEL_STYLE        amvara8_local (SSH amvara8→127.0.0.1:11434) or amvara4_forward (SSH amvara4→IP amvara8:11434).
  JARVYS_SSH_PROXYJUMP       Con amvara8_local: ProxyJump (ej. amvara4 o root@host:60022).
  JARVYS_OLLAMA_REMOTE_HOST  Con amvara4_forward: host/IP de amvara8 alcanzable DESDE amvara4.
  JARVYS_SSH_BATCHMODE       If 0, allow password prompts (default 1 = fail fast without key).

Aider is invoked with --no-show-model-warnings and --no-show-release-notes (non-interactive; no doc URLs in browser).

Git: each step runs scripts/git-sync-agent-branch.sh first (fetch + checkout + pull --rebase --autostash).

Prompt files live under agents/ (e.g. 002-coder/CODER.md). See README.md.
EOF
}

if [[ -n "${1:-}" ]]; then
  case "$1" in
    help | -h | --help)
      usage
      exit 0
      ;;
    ollama-check) cmd_ollama_check ;;
    log | log-reviewer | 001) step_log_reviewer ;;
    feat | feature) step_feat ;;
    coder) step_coder ;;
    tester) step_tester ;;
    closing-review | closing-closed) step_closing_review ;;
    committer) step_committer ;;
    *)
      usage
      exit 1
      ;;
  esac
  exit 0
fi

if ! have_aider; then
  echo "aider not found on PATH. Install: pip install aider-chat (or pipx)." >&2
  echo "Loop aborted. Single commands will no-op until aider is available." >&2
  exit 1
fi

while true; do
  run_full_cycle
  echo "----- sleeping ${sleepminutes}m (${sleepseconds}s)"
  sleep "$sleepseconds"
done
