# Jarvys network: amvara8 + amvara4

**Optional:** use this page when Ollama runs on remote servers. For **local** Ollama, set **`OLLAMA_API_BASE`** and **`JARVYS_AUTO_SSH_TUNNEL=0`**; you do not need SSH.

**Topología**

| Host | Rol |
|------|-----|
| **amvara8** | Ollama en **Docker** (`openclaw-ollama`), API en el host **`127.0.0.1:11434`** (y `0.0.0.0:11434`). |
| **amvara4** | Tiene **acceso de red directo** al puerto Ollama de amvara8 (suele ser IP **privada** Hetzner; el firewall puede limitar `11434` solo desde amvara4). |

**Jarvys (`.env`) — elige un modo**

1. **`JARVYS_TUNNEL_STYLE=amvara8_local`**  
   Tu PC abre SSH hacia **amvara8** (`178.63.8.217:60022`, usuario `yoel`) y reenvía **`127.0.0.1:11434` en amvara8**. Opcional: **`JARVYS_SSH_PROXYJUMP=amvara4`** (usa el `Host amvara4` de `~/.ssh/config`; en un entorno verificado: **root@162.55.45.216:60022**).

2. **`JARVYS_TUNNEL_STYLE=amvara4_forward`**  
   Tu PC solo SSH a **amvara4** y reenvía **`JARVYS_OLLAMA_REMOTE_HOST:11434`**. Por defecto en código: **root@162.55.45.216:60022** (sobrescribe con `JARVYS_SSH_BASTION_*` o usa alias vía config). No uses `ProxyJump` en este modo.

Los scripts **`jarvys-agent-loop.sh`**, **`start-ollama-tunnel.sh`** y **`scripts/jarvys-tunnel-lib.sh`** comparten la misma lógica.

Verified from the planning environment (SSH to **amvara8**). **amvara4** was not reachable from that environment; run the checks below on your own network.

## amvara8 (Ollama host)

| Item | Value |
|------|--------|
| SSH | `178.63.8.217`, port **60022**, user `yoel` (example: `ssh -G amvara8` in `~/.ssh/config`) |
| Ollama | Docker container **`openclaw-ollama`**, host bind **`0.0.0.0:11434` → 11434** |
| API on the server | `http://127.0.0.1:11434` — `GET /api/tags` OK; `POST /api/generate` tested with **`qwen3:latest`** |

**Note:** `ollama` is **not** guaranteed to be on the host `PATH` in non-interactive shells. Prefer:

```bash
sudo docker exec openclaw-ollama ollama list
sudo docker exec openclaw-ollama ollama pull qwen3:8b
```

Only pull tags that exist in the registry; **`qwen3:8b`** may need an explicit pull. **`qwen3:latest`** was present and API-tested.

## Public HTTP

`http://178.63.8.217:11434` may **time out** from the public Internet (firewall/route). Do **not** rely on reaching Ollama by public IP from arbitrary clients. Use **SSH port forwarding** or **private network** (e.g. amvara4 → amvara8).

### Hetzner firewall vs SSH tunnel

A strict firewall may allow **Ollama TCP 11434** only from **amvara4**’s private IP. That still works with Jarvys on your **laptop**: you do **not** open `178.63.8.217:11434` from the internet. You open an **SSH session to port 60022** (or whatever `sshd` uses). Inside that encrypted session, the server forwards to **`127.0.0.1:11434` on amvara8**, which is local to the host. No change on amvara8/amvara4 is required for that pattern.

If **SSH to amvara8 is impossible** from your PC but **amvara4 reaches amvara8:11434** on a private IP, switch to **`JARVYS_TUNNEL_STYLE=amvara4_forward`** and set **`JARVYS_OLLAMA_REMOTE_HOST`**. If you **can** SSH to amvara8 but want the hop explicitly, keep **`amvara8_local`** and set **`JARVYS_SSH_PROXYJUMP=user@amvara4`**. Key-based SSH is strongly recommended (`JARVYS_SSH_BATCHMODE=0` only if you must use a password).

### Auto tunnel (Jarvys)

With **`JARVYS_AUTO_SSH_TUNNEL=1`**, **`jarvys-agent-loop.sh`** runs **`ssh -f -N -L …`** when **`GET /api/tags`** fails, then retries. The default in **`.env.example`** is **`0`** (local Ollama only). Verify anytime:

```bash
./jarvys-agent-loop.sh ollama-check
```

## SSH tunnel (option A: laptop or runner with SSH to amvara8)

Keep a dedicated terminal open:

```bash
ssh -N -L 11434:127.0.0.1:11434 -p 60022 yoel@178.63.8.217
```

Then on the same machine:

```bash
export OLLAMA_API_BASE=http://127.0.0.1:11434
curl -sS http://127.0.0.1:11434/api/tags
```

Alternative local port (e.g. **12799**):

```bash
ssh -N -L 12799:127.0.0.1:11434 -p 60022 yoel@178.63.8.217
export OLLAMA_API_BASE=http://127.0.0.1:12799
```

Use **`scripts/start-ollama-tunnel.sh`** to wrap the `ssh -L` command using **`JARVYS_TUNNEL_STYLE`** and related variables in **`.env`** (see **`.env.example`** comments).

## amvara4 → amvara8 (option B: internal route)

**Not verified** from the planning environment (SSH to amvara4 timed out). On **amvara4**, after SSH login:

```bash
ip -4 addr
curl -sS --connect-timeout 3 "http://<PRIVATE_IP_AMVARA8>:11434/api/tags" || true
```

If `curl` fails, check routing, firewall, and security groups; note the **IP and port** that work and set `OLLAMA_API_BASE` accordingly for Jarvys when the runner lives on amvara4 (no tunnel from a laptop).

## Smoke checks

```bash
# List models
curl -sS "${OLLAMA_API_BASE:-http://127.0.0.1:11434}/api/tags"

# Inference smoke (replace model with one from /api/tags)
curl -sS "${OLLAMA_API_BASE:-http://127.0.0.1:11434}/api/generate" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3:latest","prompt":"Reply with exactly: Hello world","stream":false}'
```
