# Jarvys: Ollama connectivity (generic)

This document describes **patterns only**. Put real hostnames, IPs, and users in **`.env`** (never commit `.env` to git).

## Local Ollama

1. Run Ollama on the same machine as Jarvys (or wherever `curl` can reach it).
2. Set in **`.env`**:

   ```bash
   OLLAMA_API_BASE=http://127.0.0.1:11434
   JARVYS_AUTO_SSH_TUNNEL=0
   ```

3. Smoke: `./jarvys-agent-loop.sh ollama-check`

## Remote Ollama via SSH port forward

Typical flow: your machine opens an SSH session to a host that runs Ollama on `127.0.0.1:11434`, and you map that to a local port.

Example (manual, replace placeholders):

```bash
ssh -N -L 11434:127.0.0.1:11434 -p 22 deploy@your-ollama-host.example
```

Then:

```bash
export OLLAMA_API_BASE=http://127.0.0.1:11434
curl -sS "$OLLAMA_API_BASE/api/tags"
```

Jarvys can start a background forward when **`JARVYS_AUTO_SSH_TUNNEL=1`**, using **`scripts/start-ollama-tunnel.sh`** and **`scripts/jarvys-tunnel-lib.sh`**. You must set **all** SSH-related variables in **`.env`**; there are **no** built-in hostnames or IPs in the scripts.

### Style: direct SSH to Ollama host (`amvara8_local` / `direct`)

Set:

- `JARVYS_TUNNEL_STYLE=amvara8_local` (name is historical; it means “SSH to one host and forward its local Ollama”).
- `JARVYS_SSH_TUNNEL_HOST` — hostname or IP
- `JARVYS_SSH_TUNNEL_PORT` — SSH port (e.g. `22`)
- `JARVYS_SSH_TUNNEL_USER` — SSH user
- Optional: `JARVYS_SSH_PROXYJUMP` — `ProxyJump` target (often a `Host` alias from `~/.ssh/config`)
- `JARVYS_SSH_LOCAL_PORT` — local port (default `11434`)

### Style: bastion + private Ollama host (`amvara4_forward`)

Use when Ollama is only reachable from an internal network after SSHing to a bastion.

Set:

- `JARVYS_TUNNEL_STYLE=amvara4_forward`
- `JARVYS_SSH_BASTION_HOST`, `JARVYS_SSH_BASTION_PORT`, `JARVYS_SSH_BASTION_USER`
- `JARVYS_OLLAMA_REMOTE_HOST` — address of the Ollama machine **as seen from the bastion** (e.g. `10.x.x.x`)
- `JARVYS_SSH_LOCAL_PORT` — local port on your machine

### Auto tunnel

With **`JARVYS_AUTO_SSH_TUNNEL=1`**, `jarvys-agent-loop.sh` may run **`ssh -f -N -L …`** when **`GET $OLLAMA_API_BASE/api/tags`** fails, then retry.

## API checks

```bash
curl -sS "${OLLAMA_API_BASE:-http://127.0.0.1:11434}/api/tags"

curl -sS "${OLLAMA_API_BASE:-http://127.0.0.1:11434}/api/generate" \
  -H "Content-Type: application/json" \
  -d '{"model":"<your-model-from-tags>","prompt":"Hello","stream":false}'
```

## Security

- Do not commit **`.env`**, API keys, or internal infrastructure details.
- Prefer SSH keys (`BatchMode`) over passwords for automation.
