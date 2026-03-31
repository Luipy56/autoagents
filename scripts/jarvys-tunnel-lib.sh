# shellcheck shell=bash
# Shared SSH LocalForward for Ollama (sourced by jarvys-agent-loop.sh and start-ollama-tunnel.sh).
# Set all JARVYS_SSH_* / JARVYS_OLLAMA_REMOTE_HOST values in .env — no real hosts are hardcoded here.
#
# jarvys_fill_ssh_tunnel_argv ARRAY_NAME FOREGROUND
#   FOREGROUND=1 → ssh -N (blocking); else → ssh -f -N (background).
jarvys_fill_ssh_tunnel_argv() {
  local -n _jarvys_ssh_out="$1"
  local _fg="${2:-0}"
  _jarvys_ssh_out=()

  local style="${JARVYS_TUNNEL_STYLE:-direct_local}"
  local local_p="${JARVYS_SSH_LOCAL_PORT:-11434}"
  local proxy="${JARVYS_SSH_PROXYJUMP:-}"

  _jarvys_ssh_out+=(ssh)
  [[ "$_fg" != 1 ]] && _jarvys_ssh_out+=( -f )
  _jarvys_ssh_out+=(
    -N
    -o ExitOnForwardFailure=yes
    -o ServerAliveInterval=30
    -o ServerAliveCountMax=4
  )
  [[ "${JARVYS_SSH_BATCHMODE:-1}" == "1" ]] && _jarvys_ssh_out+=( -o BatchMode=yes )

  case "$style" in
    amvara8_local | direct | direct_local | "")
      [[ -n "$proxy" ]] && _jarvys_ssh_out+=( -o "ProxyJump=${proxy}" )
      local host port user
      host="${JARVYS_SSH_TUNNEL_HOST:-}"
      port="${JARVYS_SSH_TUNNEL_PORT:-}"
      user="${JARVYS_SSH_TUNNEL_USER:-}"
      if [[ -z "$host" || -z "$port" || -z "$user" ]]; then
        echo "jarvys: JARVYS_TUNNEL_STYLE=${style} requires JARVYS_SSH_TUNNEL_HOST, JARVYS_SSH_TUNNEL_PORT, and JARVYS_SSH_TUNNEL_USER in .env (no defaults; see docs/jarvys-network.md)." >&2
        return 1
      fi
      _jarvys_ssh_out+=( -L "${local_p}:127.0.0.1:11434" -p "${port}" "${user}@${host}" )
      ;;
    amvara4_forward | via_amvara4)
      local bh bp bu remote
      bh="${JARVYS_SSH_BASTION_HOST:-}"
      bp="${JARVYS_SSH_BASTION_PORT:-}"
      bu="${JARVYS_SSH_BASTION_USER:-}"
      remote="${JARVYS_OLLAMA_REMOTE_HOST:-}"
      if [[ -z "$bh" || -z "$bp" || -z "$bu" ]]; then
        echo "jarvys: JARVYS_TUNNEL_STYLE=${style} requires JARVYS_SSH_BASTION_HOST, JARVYS_SSH_BASTION_PORT, and JARVYS_SSH_BASTION_USER in .env." >&2
        return 1
      fi
      if [[ -z "$remote" ]]; then
        echo "jarvys: JARVYS_TUNNEL_STYLE=${style} requires JARVYS_OLLAMA_REMOTE_HOST (Ollama host reachable from the bastion)." >&2
        return 1
      fi
      _jarvys_ssh_out+=( -L "${local_p}:${remote}:11434" -p "${bp}" "${bu}@${bh}" )
      ;;
    *)
      echo "jarvys: unknown JARVYS_TUNNEL_STYLE=${style} (use amvara8_local, amvara4_forward, or direct)" >&2
      return 1
      ;;
  esac
  return 0
}

jarvys_tunnel_describe() {
  local style="${JARVYS_TUNNEL_STYLE:-direct_local}"
  case "$style" in
    amvara8_local | direct | direct_local | "")
      if [[ -n "${JARVYS_SSH_TUNNEL_HOST:-}" && -n "${JARVYS_SSH_TUNNEL_USER:-}" ]]; then
        echo "ssh tunnel: ${JARVYS_SSH_TUNNEL_USER}@${JARVYS_SSH_TUNNEL_HOST}:${JARVYS_SSH_TUNNEL_PORT:-?} → local :${JARVYS_SSH_LOCAL_PORT:-11434}${JARVYS_SSH_PROXYJUMP:+, ProxyJump ${JARVYS_SSH_PROXYJUMP}}"
      else
        echo "ssh tunnel: (set JARVYS_SSH_TUNNEL_HOST, JARVYS_SSH_TUNNEL_PORT, JARVYS_SSH_TUNNEL_USER in .env)"
      fi
      ;;
    amvara4_forward | via_amvara4)
      if [[ -n "${JARVYS_SSH_BASTION_HOST:-}" ]]; then
        echo "ssh tunnel: bastion ${JARVYS_SSH_BASTION_USER:-?}@${JARVYS_SSH_BASTION_HOST}:${JARVYS_SSH_BASTION_PORT:-?} → ${JARVYS_OLLAMA_REMOTE_HOST:-"(set JARVYS_OLLAMA_REMOTE_HOST)"}:11434"
      else
        echo "ssh tunnel: (set JARVYS_SSH_BASTION_* and JARVYS_OLLAMA_REMOTE_HOST in .env)"
      fi
      ;;
    *)
      echo "style=${style}"
      ;;
  esac
}
