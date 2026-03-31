# Jarvys Team

Portable **task-file pipeline** (same states and cycle as the Laravel ecommerce agent loop) with **Aider** + **Ollama** instead of `cursor-agent`. You keep editing in your own editor; the loop runs in a terminal.

**Scope:** this folder is **orchestration, prompts, and scripts** only. **Application code** lives in the **host repository** (the parent of `jarvys-team/` when you embed this bundle, or the directory you set with **`JARVYS_REPO_ROOT`**). This bundle does not ship a product app.

## What’s in the bundle

| Path | Purpose |
|------|--------|
| `jarvys-agent-loop.sh` | Orchestrator: same subcommands and cycle order as `laravel-ecommerce-agent-loop.sh`; `run_agent` uses Aider. |
| `agents/` | Role prompts (`001` … `007`) and **`agents/tasks/`** for task files. |
| `scripts/git-sync-agent-branch.sh` | Fetch + checkout integration branch + pull --rebase --autostash. |
| `scripts/move-agent-task-to-done.sh` | Move **`CLOSED-`** tasks to **`done/YYYY/MM/DD/`**. |
| `scripts/start-ollama-tunnel.sh` | Optional SSH **LocalForward** to remote Ollama (see `docs/jarvys-network.md`). |
| `docs/jarvys-network.md` | Remote Ollama / SSH tunnel patterns (placeholders only; no secrets in git). |
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
- **Git** repository for your application. **`jarvys-agent-loop.sh`** runs **`git-sync-agent-branch.sh`** against that repo (see **Nested install**). Use **`AGENT_GIT_SYNC=0`** to skip sync if you have no remote or no script copy yet.

## Nested install (recommended)

Place this repo as **`your-app/jarvys-team/`** (folder name **`jarvys-team`** by default, or any name if the **parent directory** is the git root). Then:

- **`REPO_ROOT`** defaults to **`your-app/`** when **`your-app/.git`** exists (nested bundle) or when the bundle folder is named **`jarvys-team`** (or **`JARVYS_BUNDLE_DIRNAME`**). If **`jarvys-team/.git`** exists (this bundle is its own repo), **`REPO_ROOT`** stays **`jarvys-team/`**. **Aider** runs with `cd` into **`REPO_ROOT`**.
- **`JARVYS_REPO_ROOT`** overrides that path if the bundle folder is renamed or lives elsewhere.
- **`JARVYS_BUNDLE_DIRNAME`** (default **`jarvys-team`**) controls which directory name triggers “parent = app root”.

**`.env` loading:** if both exist, **`your-app/.env`** is loaded first, then **`your-app/jarvys-team/.env`** (later wins on duplicate keys). Put app-wide secrets in the parent; put **`OLLAMA_API_BASE`** / **`JARVYS_*`** in either file.

**Git sync:** the loop uses **`your-app/scripts/git-sync-agent-branch.sh`** if present; otherwise **`jarvys-team/scripts/git-sync-agent-branch.sh`**, with **`JARVYS_GIT_ROOT`** set to the app root so fetch/pull runs on **`your-app`**, not inside **`jarvys-team/`** only.

Standalone clone (directory not named **`jarvys-team`**): **`REPO_ROOT`** defaults to the bundle directory unless you set **`JARVYS_REPO_ROOT`**.

## Configuration

1. Copy **`.env.example`** to **`.env`** (parent repo, `jarvys-team/`, or both; see above).

   - **`OLLAMA_API_BASE`** — Ollama HTTP root (no `/v1` suffix). Local: `http://127.0.0.1:11434`. With SSH forward to the same local port, use the matching URL.
   - **`JARVYS_OLLAMA_MODEL`** — Tag present on the server (e.g. **`qwen3:latest`**).
   - **`JARVYS_SKIP_OLLAMA_GATE=1`** — skip the fast **`GET /api/tags`** check at startup (offline only).

2. Export **`OLLAMA_API_BASE`**, **`JARVYS_OLLAMA_MODEL`**, **`AGENT_GIT_SYNC`**, **`JARVYS_REPO_ROOT`**, or **`JARVYS_BUNDLE_DIRNAME`** before running the script to override values from `.env`.

Alternate layout: copy **`agents/`** and **`scripts/`** into the app tree (or symlink) and run **`./agents/jarvys-agent-loop.sh`** from the app root; paths resolve as before.

## Publishing to GitHub

- **Never commit `.env`** (it is gitignored). Use **`.env.example`** with placeholders only.
- Do not commit internal hostnames, IPs, or SSH users in docs; keep **`docs/jarvys-network.md`** generic.

## Ollama connectivity

- **Default:** local Ollama; keep **`JARVYS_AUTO_SSH_TUNNEL=0`** in **`.env`** (copy from **`.env.example`**).
- **Remote Ollama:** set **`JARVYS_AUTO_SSH_TUNNEL=1`** and all **`JARVYS_SSH_*`** / **`JARVYS_OLLAMA_REMOTE_HOST`** values in **`.env`** (no hardcoded hosts in the repo), or run **`scripts/start-ollama-tunnel.sh`** manually. Patterns: **`docs/jarvys-network.md`**.
- Before **`log`**, **`feat`**, **`coder`**, **`tester`**, **`closing-review`**, **`committer`**, and the **no-arg loop**, the script runs a quick **`GET /api/tags`** check (unless **`JARVYS_SKIP_OLLAMA_GATE=1`**). **`ollama-check`** still runs a fuller smoke (**tags** + **generate**).

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
