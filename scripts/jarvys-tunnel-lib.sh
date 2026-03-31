# shellcheck shell=bash
# Shared SSH LocalForward for Ollama (sourced by jarvys-agent-loop.sh and start-ollama-tunnel.sh).
# Topology:
#   amvara8 — Ollama en Docker (host 127.0.0.1:11434 / 0.0.0.0:11434).
#   amvara4 — acceso de red a Ollama de amvara8 (IP privada / interna).
#
# jarvys_fill_ssh_tunnel_argv ARRAY_NAME FOREGROUND
#   FOREGROUND=1 → ssh -N (bloqueante); else → ssh -f -N (fondo).
jarvys_fill_ssh_tunnel_argv() {
  local -n _jarvys_ssh_out="$1"
  local _fg="${2:-0}"
  _jarvys_ssh_out=()

  local style="${JARVYS_TUNNEL_STYLE:-amvara8_local}"
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
    amvara8_local | direct | "")
      # PC → (opcional ProxyJump amvara4) → SSH amvara8 → Ollama en 127.0.0.1:11434 del host amvara8
      [[ -n "$proxy" ]] && _jarvys_ssh_out+=( -o "ProxyJump=${proxy}" )
      local host port user
      host="${JARVYS_SSH_TUNNEL_HOST:-178.63.8.217}"
      port="${JARVYS_SSH_TUNNEL_PORT:-60022}"
      user="${JARVYS_SSH_TUNNEL_USER:-yoel}"
      _jarvys_ssh_out+=( -L "${local_p}:127.0.0.1:11434" -p "${port}" "${user}@${host}" )
      ;;
    amvara4_forward | via_amvara4)
      # Tu PC → SSH solo a amvara4 → TCP a amvara8:11434 por red privada (firewall Hetzner)
      local bh bp bu remote
      # Defaults alineados con `ssh -G amvara4` en el entorno verificado (root, 60022, 162.55.45.216).
      bh="${JARVYS_SSH_BASTION_HOST:-162.55.45.216}"
      bp="${JARVYS_SSH_BASTION_PORT:-60022}"
      bu="${JARVYS_SSH_BASTION_USER:-root}"
      remote="${JARVYS_OLLAMA_REMOTE_HOST:-}"
      if [[ -z "$remote" ]]; then
        echo "jarvys: JARVYS_TUNNEL_STYLE=${style} requires JARVYS_OLLAMA_REMOTE_HOST (IP/hostname de amvara8 alcanzable DESDE amvara4, p. ej. red privada Hetzner)." >&2
        return 1
      fi
      _jarvys_ssh_out+=( -L "${local_p}:${remote}:11434" -p "${bp}" "${bu}@${bh}" )
      ;;
    *)
      echo "jarvys: unknown JARVYS_TUNNEL_STYLE=${style} (use amvara8_local or amvara4_forward)" >&2
      return 1
      ;;
  esac
  return 0
}

jarvys_tunnel_describe() {
  local style="${JARVYS_TUNNEL_STYLE:-amvara8_local}"
  case "$style" in
    amvara8_local | direct | "")
      echo "amvara8_local: ${JARVYS_SSH_TUNNEL_USER:-yoel}@${JARVYS_SSH_TUNNEL_HOST:-178.63.8.217}:${JARVYS_SSH_TUNNEL_PORT:-60022} → 127.0.0.1:11434 (en amvara8)${JARVYS_SSH_PROXYJUMP:+, ProxyJump ${JARVYS_SSH_PROXYJUMP}}"
      ;;
    amvara4_forward | via_amvara4)
      echo "amvara4_forward: ${JARVYS_SSH_BASTION_USER:-root}@${JARVYS_SSH_BASTION_HOST:-162.55.45.216}:${JARVYS_SSH_BASTION_PORT:-60022} → ${JARVYS_OLLAMA_REMOTE_HOST:-"(set JARVYS_OLLAMA_REMOTE_HOST)"}:11434"
      ;;
    *)
      echo "style=${style}"
      ;;
  esac
}
