# Jarvys Team

Portable **task-file pipeline** (same states and cycle as the Laravel ecommerce agent loop) with **Aider** + **Ollama** instead of `cursor-agent`. You keep editing in your own editor; the loop runs in a terminal.

**Scope:** this folder is **orchestration, prompts, and scripts** only. **Application code** belongs in whatever **Git repository** you point Jarvys at (`JARVYS_REPO_ROOT` or copy `agents/` + `scripts/` into that repo). This bundle does not ship a product app.

## What’s in the bundle

| Path | Purpose |
|------|--------|
| `jarvys-agent-loop.sh` | Orchestrator: same subcommands and cycle order as `laravel-ecommerce-agent-loop.sh`; `run_agent` uses Aider. |
| `agents/` | Role prompts (`001` … `007`) and **`agents/tasks/`** for task files. |
| `scripts/git-sync-agent-branch.sh` | Fetch + checkout integration branch + pull --rebase --autostash. |
| `scripts/move-agent-task-to-done.sh` | Move **`CLOSED-`** tasks to **`done/YYYY/MM/DD/`**. |
| `scripts/start-ollama-tunnel.sh` | Optional SSH **LocalForward** to remote Ollama (see `docs/jarvys-network.md`). |
| `docs/jarvys-network.md` | Optional remote topology (amvara8/amvara4), tunnel, smoke `curl` commands. |
| `GLOBAL_RULES.md` | Git, tasks, security, verification, no co-author branding. |

The loop passes **`--no-show-model-warnings`** and **`--no-show-release-notes`** to Aider so scripted runs do not open browser tabs for [model warnings](https://aider.chat/docs/llms/warnings.html) or [release notes](https://aider.chat/HISTORY.html#release-notes).

## Verify the bundle

From this directory:

```bash
chmod +x scripts/verify-jarvys.sh   # once, if you get “Permission denied”
./scripts/verify-jarvys.sh
# or without execute bit:
bash scripts/verify-jarvys.sh
```

This checks shell syntax and prints **`aider --version`** if a venv or `PATH` provides it.

## Prerequisites

- **Python** with **Aider**: `pip install aider-chat` (or `pipx install aider-chat`), or create a venv in this directory:

  ```bash
  python3 -m venv .venv
  .venv/bin/pip install aider-chat
  ```

  The loop uses **`aider` on `PATH`**, or **`./.venv/bin/aider`** if present, or **`JARVYS_AIDER`** to point to a binary. See [Ollama · Aider](https://aider.chat/docs/llms/ollama.html).
- **Ollama** on the same machine at **`OLLAMA_API_BASE`** (default `http://127.0.0.1:11434`). For a **remote** Ollama, set **`JARVYS_AUTO_SSH_TUNNEL=1`** and the tunnel variables in `.env`, or run **`scripts/start-ollama-tunnel.sh`** — see **`docs/jarvys-network.md`**.
- **Git** repository at **`JARVYS_REPO_ROOT`** (see below) with **`scripts/`** from this bundle at the repo root, unless you set **`AGENT_GIT_SYNC=0`** to skip sync.

## Configuration

1. Copy **`.env.example`** to **`.env`** in this directory (or export variables in your shell).

   - **`OLLAMA_API_BASE`** — Ollama HTTP root (no `/v1` suffix). Local: `http://127.0.0.1:11434`. With SSH forward to the same local port, use the matching URL.
   - **`JARVYS_OLLAMA_MODEL`** — Tag present on the server (e.g. **`qwen3:latest`**; see `docs/jarvys-network.md`).

2. **Repo root:** If you run **`./jarvys-agent-loop.sh`** from **this** directory (not from `…/agents/`), the script treats **this folder** as the Git root unless you set:

   ```bash
   export JARVYS_REPO_ROOT=/path/to/your/application
   ```

   To attach Jarvys to an existing app, copy **`agents/`** and **`scripts/`** into that app’s tree (or symlink) so **`REPO_ROOT/scripts/git-sync-agent-branch.sh`** exists.

## Ollama connectivity

- **Default:** local Ollama; keep **`JARVYS_AUTO_SSH_TUNNEL=0`** (see **`.env.example`**).
- **Remote Ollama:** set **`JARVYS_AUTO_SSH_TUNNEL=1`** and tunnel settings, or start **`scripts/start-ollama-tunnel.sh`** manually. Topology examples (**amvara8** / **amvara4**): **`docs/jarvys-network.md`**.
- Smoke: **`./jarvys-agent-loop.sh ollama-check`**.

## Usage

From the directory that contains **`jarvys-agent-loop.sh`**:

```bash
# Confirm Ollama (with JARVYS_AUTO_SSH_TUNNEL=1, may start SSH tunnel if /api/tags fails)
./jarvys-agent-loop.sh ollama-check

# One-off steps (after Ollama reachable + .env)
./jarvys-agent-loop.sh log          # 001 log / issue reviewer
./jarvys-agent-loop.sh feat         # 006 feature coder (FEAT-*)
./jarvys-agent-loop.sh coder        # 002 coder (NEW-* / WIP-*)
./jarvys-agent-loop.sh tester       # 003 tester (UNTESTED-*)
./jarvys-agent-loop.sh closing-review
./jarvys-agent-loop.sh committer    # 007 changelog / commit

# Loop forever (sleep between cycles)
./jarvys-agent-loop.sh              # default 5 min; override AGENT_LOOP_SLEEP_MINUTES
```

If the script lives under **`agents/`** (same layout as the ecommerce repo), run **`./agents/jarvys-agent-loop.sh`** from the **repository root**; paths resolve automatically.

**Skip git** (no remote / dry tests):

```bash
export AGENT_GIT_SYNC=0
```

## Optional: SSH tunnel to remote Ollama

Only if Ollama runs on another host. In a **separate terminal**:

```bash
chmod +x scripts/start-ollama-tunnel.sh
./scripts/start-ollama-tunnel.sh
```

Then verify:

```bash
curl -sS "$OLLAMA_API_BASE/api/tags"
```

Full smoke (**tags** + **generate**): **`./scripts/smoke-ollama.sh`**. Details: **`docs/jarvys-network.md`**.

## Acceptance checks (operator)

1. Ollama reachable at **`OLLAMA_API_BASE`** (local or tunneled); **`curl $OLLAMA_API_BASE/api/tags`** returns JSON; **`POST /api/generate`** returns a normal completion for your model.
2. **`coder`** step with a **`NEW-…`** smoke task: Aider runs against **`JARVYS_REPO_ROOT`** and respects git (with sync enabled).
3. Task renames follow **`agents/tasks/README.md`**.
4. Another operator can follow this README and **`docs/jarvys-network.md`** without this chat.

## Aider model string

The loop exports **`OLLAMA_API_BASE`** and invokes:

`aider --model ollama_chat/<JARVYS_OLLAMA_MODEL> --yes --message-file …`

See [Aider Ollama docs](https://aider.chat/docs/llms/ollama.html) if you need **`OLLAMA_API_KEY`** or context tweaks.
