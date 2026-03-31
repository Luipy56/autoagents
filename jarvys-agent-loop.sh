#!/usr/bin/env bash
# Jarvys Team agent loop — same orchestration as laravel-ecommerce-agent-loop.sh;
# run_agent uses Aider + Ollama instead of cursor-agent.
#
# Run from repo root (if this file lives under agents/):
#   ./agents/jarvys-agent-loop.sh [COMMAND]
# Or from this package root:
#   ./jarvys-agent-loop.sh [COMMAND]
#
# Nested install: when this directory is named jarvys-team/ (or JARVYS_BUNDLE_DIRNAME),
# the application git root defaults to the parent directory. Override with JARVYS_REPO_ROOT.
#
# Requires: aider on PATH (pip install aider-chat), Ollama reachable via OLLAMA_API_BASE.
# Task dir: agents/tasks/ (sibling of agents/ when script is under agents/).

set -euo pipefail

SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"

AGENTS_LAYOUT=0
if [[ "$(basename "$SCRIPTDIR")" == "agents" ]]; then
  AGENTS_LAYOUT=1
  TASKDIR="${SCRIPTDIR}/tasks"
  AGENT_PROMPT_ROOT="${SCRIPTDIR}"
else
  TASKDIR="${SCRIPTDIR}/agents/tasks"
  AGENT_PROMPT_ROOT="${SCRIPTDIR}/agents"
fi

# Values exported in the invoking shell win over the same keys in .env (one-off overrides).
if [[ -n ${JARVYS_OLLAMA_MODEL+x} ]]; then _jarvys_cli_model="$JARVYS_OLLAMA_MODEL"; fi
if [[ -n ${OLLAMA_API_BASE+x} ]]; then _jarvys_cli_ollama_base="$OLLAMA_API_BASE"; fi
if [[ -n ${AGENT_GIT_SYNC+x} ]]; then _jarvys_cli_git_sync="$AGENT_GIT_SYNC"; fi
if [[ -n ${JARVYS_REPO_ROOT+x} ]]; then _jarvys_cli_repo="$JARVYS_REPO_ROOT"; fi
if [[ -n ${JARVYS_BUNDLE_DIRNAME+x} ]]; then _jarvys_cli_bundle="$JARVYS_BUNDLE_DIRNAME"; fi

# Directory for the first .env file (parent app when nested). Uses only pre-.env shell state.
jarvys_first_dotenv_root() {
  if [[ "$AGENTS_LAYOUT" == 1 ]]; then
    (cd "${SCRIPTDIR}/.." && pwd)
    return
  fi
  if [[ -n "${_jarvys_cli_repo:-}" ]]; then
    (cd "${_jarvys_cli_repo}" && pwd)
    return
  fi
  if [[ -e "$SCRIPTDIR/.git" ]]; then
    printf '%s' "$SCRIPTDIR"
    return
  fi
  local parent bundle
  parent="$(cd "${SCRIPTDIR}/.." && pwd)"
  if [[ "$parent" != "$SCRIPTDIR" && -e "$parent/.git" ]]; then
    printf '%s' "$parent"
    return
  fi
  bundle="${_jarvys_cli_bundle:-${JARVYS_BUNDLE_DIRNAME:-jarvys-team}}"
  if [[ "$(basename "$SCRIPTDIR")" == "$bundle" ]]; then
    printf '%s' "$parent"
    return
  fi
  printf '%s' "$SCRIPTDIR"
}

load_env_files() {
  local first_root
  first_root="$(jarvys_first_dotenv_root)"
  if [[ -f "$first_root/.env" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$first_root/.env"
    set +a
  fi
  if [[ -f "$SCRIPTDIR/.env" && "$SCRIPTDIR" != "$first_root" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$SCRIPTDIR/.env"
    set +a
  fi
}

load_env_files

if [[ -n ${_jarvys_cli_model+x} ]]; then export JARVYS_OLLAMA_MODEL="$_jarvys_cli_model"; fi
if [[ -n ${_jarvys_cli_ollama_base+x} ]]; then export OLLAMA_API_BASE="$_jarvys_cli_ollama_base"; fi
if [[ -n ${_jarvys_cli_git_sync+x} ]]; then export AGENT_GIT_SYNC="$_jarvys_cli_git_sync"; fi
if [[ -n ${_jarvys_cli_repo+x} ]]; then export JARVYS_REPO_ROOT="$_jarvys_cli_repo"; fi
if [[ -n ${_jarvys_cli_bundle+x} ]]; then export JARVYS_BUNDLE_DIRNAME="$_jarvys_cli_bundle"; fi
unset _jarvys_cli_model _jarvys_cli_ollama_base _jarvys_cli_git_sync _jarvys_cli_repo _jarvys_cli_bundle

jarvys_resolve_repo_root() {
  if [[ "$AGENTS_LAYOUT" == 1 ]]; then
    REPO_ROOT="$(cd "${SCRIPTDIR}/.." && pwd)"
    return
  fi
  if [[ -n "${JARVYS_REPO_ROOT:-}" ]]; then
    REPO_ROOT="$(cd "$JARVYS_REPO_ROOT" && pwd)"
    return
  fi
  if [[ -e "$SCRIPTDIR/.git" ]]; then
    REPO_ROOT="$SCRIPTDIR"
    return
  fi
  local parent bundle
  parent="$(cd "${SCRIPTDIR}/.." && pwd)"
  if [[ "$parent" != "$SCRIPTDIR" && -e "$parent/.git" ]]; then
    REPO_ROOT="$parent"
    return
  fi
  bundle="${JARVYS_BUNDLE_DIRNAME:-jarvys-team}"
  if [[ "$(basename "$SCRIPTDIR")" == "$bundle" ]]; then
    REPO_ROOT="$parent"
    return
  fi
  REPO_ROOT="$SCRIPTDIR"
}

jarvys_resolve_repo_root

# Bundle helpers always live next to this script (not the parent app's scripts/).
JARVYS_BUNDLE_SCRIPTS_DIR="${SCRIPTDIR}/scripts"
# shellcheck source=/dev/null
if [[ -f "${JARVYS_BUNDLE_SCRIPTS_DIR}/jarvys-tunnel-lib.sh" ]]; then
  source "${JARVYS_BUNDLE_SCRIPTS_DIR}/jarvys-tunnel-lib.sh"
else
  echo "ERROR: missing ${JARVYS_BUNDLE_SCRIPTS_DIR}/jarvys-tunnel-lib.sh" >&2
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

# Lightweight gate before sync/Aider (GET /api/tags only). Skipped for help and ollama-check.
jarvys_gate_ollama_or_exit() {
  [[ "${JARVYS_SKIP_OLLAMA_GATE:-0}" == "1" ]] && return 0
  if ! ollama_reachable; then
    echo "ERROR: Ollama not reachable at $(ollama_tags_url) (set OLLAMA_API_BASE in .env or export before running; JARVYS_SKIP_OLLAMA_GATE=1 to skip)." >&2
    exit 1
  fi
  echo "-----> Ollama gate OK ($(ollama_base_norm)/api/tags)"
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
    echo "Jarvys: SSH tunnel failed. Check keys, JARVYS_TUNNEL_STYLE, and required JARVYS_SSH_* variables in .env. See docs/jarvys-network.md" >&2
    return 1
  fi
  sleep 2
  if ollama_reachable; then
    echo "-----> Jarvys: Ollama reachable after tunnel." >&2
    return 0
  fi
  echo "Jarvys: Tunnel started but GET /api/tags still failed. Match OLLAMA_API_BASE to local port ${local_p}; for amvara4_forward set JARVYS_OLLAMA_REMOTE_HOST to the Ollama host as seen from the bastion." >&2
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
  local sync_script=""
  if [[ -f "${REPO_ROOT}/scripts/git-sync-agent-branch.sh" ]]; then
    sync_script="${REPO_ROOT}/scripts/git-sync-agent-branch.sh"
  elif [[ -f "${SCRIPTDIR}/scripts/git-sync-agent-branch.sh" ]]; then
    sync_script="${SCRIPTDIR}/scripts/git-sync-agent-branch.sh"
  fi
  if [[ -z "$sync_script" ]]; then
    echo "ERROR: missing git-sync-agent-branch.sh (tried \$REPO_ROOT/scripts and jarvys-team/scripts). Copy from the bundle or set AGENT_GIT_SYNC=0." >&2
    exit 1
  fi
  echo "-----> git sync agent branch $(date "+%Y-%m-%d %H:%M:%S") <----"
  if ! JARVYS_GIT_ROOT="$REPO_ROOT" bash "$sync_script"; then
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
  JARVYS_REPO_ROOT           Application git root when bundle is nested (overrides auto parent-of-jarvys-team).
  JARVYS_BUNDLE_DIRNAME      Directory name that triggers nested mode (default: jarvys-team).
  JARVYS_SKIP_OLLAMA_GATE    If 1, skip the startup GET /api/tags check (default: 0).
  JARVYS_AIDER               Full path to aider binary (optional; else PATH or ./.venv/bin/aider).
  JARVYS_AUTO_SSH_TUNNEL     If 1, try ssh -f -L before Aider when /api/tags fails (default: 0 = local Ollama only).
  JARVYS_TUNNEL_STYLE        amvara8_local (SSH to host, forward remote 127.0.0.1:11434) or amvara4_forward (bastion + private Ollama host). All SSH hosts/ports must be set in .env (no baked-in defaults).
  JARVYS_SSH_PROXYJUMP       Optional ProxyJump for amvara8_local (e.g. ~/.ssh/config Host name).
  JARVYS_OLLAMA_REMOTE_HOST  For amvara4_forward: Ollama hostname/IP as reachable from the bastion.
  JARVYS_SSH_BATCHMODE       If 0, allow password prompts (default 1 = fail fast without key).

Aider is invoked with --no-show-model-warnings and --no-show-release-notes (non-interactive; no doc URLs in browser).

Git: each step runs git-sync-agent-branch.sh on the app root (JARVYS_GIT_ROOT / REPO_ROOT; see README).

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
    log | log-reviewer | 001)
      jarvys_gate_ollama_or_exit
      step_log_reviewer
      ;;
    feat | feature)
      jarvys_gate_ollama_or_exit
      step_feat
      ;;
    coder)
      jarvys_gate_ollama_or_exit
      step_coder
      ;;
    tester)
      jarvys_gate_ollama_or_exit
      step_tester
      ;;
    closing-review | closing-closed)
      jarvys_gate_ollama_or_exit
      step_closing_review
      ;;
    committer)
      jarvys_gate_ollama_or_exit
      step_committer
      ;;
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

jarvys_gate_ollama_or_exit

while true; do
  run_full_cycle
  echo "----- sleeping ${sleepminutes}m (${sleepseconds}s)"
  sleep "$sleepseconds"
done
