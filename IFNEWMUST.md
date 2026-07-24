# IFNEWMUST — Adapt autoagents to a new host project

**Purpose:** Use this file as the **system / adaptation prompt** when installing or copying this `agents/` (autoagents) tree into a **new repository**. The base package is stack-agnostic; every install must rewrite project-specific assumptions so agents do useful work instead of chasing the previous product’s paths.

**How to use:** Paste this entire document (or `@agents/IFNEWMUST.md`) into an agent session in the **target repo**, then say: *“Adapt autoagents to this project following IFNEWMUST.”* The adapting agent must inspect the host repo and apply the checklist below.

---

## 0. Non-negotiables (do not invent)

1. **Install location:** This package lives as **`agents/`** at the **host repo root** (sibling of app code, `scripts/`, `docs/`). Repo root = parent of `agents/`.
2. **Orchestrator name:** **`agents/agent-loop.sh`** (never `pos-*-loop`, `*-cursor-loop`, or product-prefixed names).
3. **Task pipeline** statuses and filenames stay standard (`FEAT-` / `NEW-` / `WIP-` / `UNTESTED-` / `TESTING-` / `CLOSED-` → `done/YYYY/MM/DD/`). See `agents/TASKS-README.md`.
4. **No secrets** in prompts or committed env. Use `agents/autoagents.env` (gitignored) from `agents/autoagents.env.example`.
5. **Do not hardcode** old product names, org names, Docker container names, production hosts, or absolute home paths (`~/projects/…`). Replace with values discovered in **this** repo.

---

## 1. Discover the host project (read first)

Before editing prompts, gather:

| Fact | Where to look | Write into |
|------|----------------|------------|
| GitHub `owner/repo` | `git remote -v`, `gh repo view` | `AGENT_GH_REPO` |
| Integration branch | `AGENTS.md`, CI, default branch rules | `AGENT_INTEGRATION_BRANCH` |
| Production branch | same | `AGENT_PRODUCTION_BRANCH` |
| App code directories | monorepo layout (`apps/`, `src/`, `backend/`, …) | `APP_CODE_DIRS` |
| Docker service / container names | `docker compose ps`, `docker-compose*.yml` | `AGENT_DOCKER_CONTAINERS` |
| How to start the stack | `README`, `Makefile`, `package.json`, `run.sh` | note in `AGENTS.md` / prompts |
| How to test | `docs/testing.md`, CI, compose exec recipes | `020-test.md` |
| Deploy / prod URL | CI workflows, docs | `020-test.md` (deploy wait section) |
| Changelog / version files | `CHANGELOG.md`, `package.json`, `pyproject.toml` | `040-committer.md` |
| Git sync helper | `scripts/git-sync-*.sh` or invent thin wrapper | loop + all agents |
| Satellite / sibling repos | org repos, marketing sites, microfrontends | enable **005** or set `AGENT_ENABLE_005=0` |
| Demo/seed tooling | seeds, fixtures, cron docs | **008** or disable |

If a host script is missing (`git-sync-development.sh`, `move-agent-task-to-done.sh`, `link-commit-to-github-issues.sh`, preflights), either **port/adapt** from a known install or **document a minimal equivalent** and update agent prompts to call what exists.

---

## 2. Config file (required every install)

1. Copy `agents/autoagents.env.example` → `agents/autoagents.env`.
2. Fill at least:

```bash
AGENT_GH_REPO=owner/repo
AGENT_INTEGRATION_BRANCH=development   # or main / develop — match the project
AGENT_PRODUCTION_BRANCH=master         # or main
APP_CODE_DIRS="path1/ path2/"          # real trees agents may edit
AGENT_DOCKER_CONTAINERS="c1 c2 c3"     # empty string disables 001 Docker log pass
AGENT_ENABLE_005=0                     # 1 only if satellite repos are in scope
AGENT_ENABLE_008=1                     # 0 if no weekly enhancement role
```

3. Ensure `.gitignore` includes `agents/autoagents.env` (and keep the example committed).
4. Confirm `agent-loop.sh` sources `autoagents.env` (base already does).

---

## 3. File-by-file adaptation map

### `agents/agent-loop.sh`

| Knob | Action |
|------|--------|
| `AGENT_GH_REPO` | Must be set via env |
| `AGENT_DOCKER_CONTAINERS` | Match real container names |
| `AGENT_ENABLE_005` / `008` | Disable unused steps |
| Committer allowlist paths | Keep under `agents/…` stamp files only |
| Preflight scripts | Paths under `REPO_ROOT/scripts/…` — create stubs or gate steps if missing |
| Integration branch hardcoding | Prefer env / project sync script; do not leave foreign branch names |

### Prompt roles (rewrite product-specific sentences)

| File | Must replace |
|------|----------------|
| `001-gh-reviewer.md` | Repo name, issue URLs, APP_CODE_DIRS “do not touch” list |
| `005-marketing-repos-reviewer.md` | Entire role: org, naming pattern, manifest paths, deploy commands — or disable via env |
| `008-enhancement-reviewer.md` | Demo/seed commands, production host names, preflight script paths |
| `010-feature-coder.md` | APP_CODE_DIRS, satellite prefix rules, debug log containers |
| `012-feature-coder-handoff.md` | Deploy blocker rules for **this** CI |
| `020-test.md` | Compose files, `BASE_URL`, health endpoints, deploy workflow names |
| `030-closing-reviewer.md` | Paths stay `agents/tasks/…`; archive script path |
| `040-committer.md` | Version files, changelog presence, branch names |
| `issue_checker_agent.py` | Uses `AGENT_GH_REPO` — no hardcoded owner/repo |
| `TASKS-README.md` | Keep pipeline; only adjust helper script paths if different |

### Host repo companions (outside `agents/`, create if missing)

- `scripts/git-sync-development.sh` (or rename consistently and update all references)
- `scripts/move-agent-task-to-done.sh` — prefer the copy in **`host-scripts/move-agent-task-to-done.sh`** (includes Redmine note + `time_entry` hook)
- Optional: `scripts/link-commit-to-github-issues.sh`
- Optional: `scripts/marketing-repos-preflight.sh`, `scripts/enhancement-reviewer-preflight.sh`
- GitHub labels: `agent:planned`, `agent:wip`, `agent:untested`, `agent:testing` (create if used)
- Root `AGENTS.md` pointer: how to run `./agents/agent-loop.sh`, env file, branch policy

### Redmine (optional)

Set in `agents/autoagents.env`:

```bash
REDMINE_BASE_URL=https://redmine.amvara.de
REDMINE_API_KEY=...
REDMINE_ISSUE_ID=7103
REDMINE_ACTIVITY_ID=10
```

Requires `agents/redmine_sync.py`, `agents/lib/redmine_actions.py`, and a move script that calls `redmine_sync.py note` before `mv` (see `host-scripts/`).

---

## 4. Naming standard (what “generic” means)

| Legacy / forbidden in new installs | Standard |
|------------------------------------|----------|
| `pos-cursor-loop.sh`, `pos-agent-loop.sh` | `agent-loop.sh` |
| `agents2/` | `agents/` |
| Hardcoded `satisfecho/pos`, `~/projects/pos2` | `AGENT_GH_REPO`, repo root relative paths |
| Hardcoded `pos-front`, `pos-back`, … | `AGENT_DOCKER_CONTAINERS` |
| “this POS repo” in prompts | “this repository” + APP_CODE_DIRS |
| Product deploy hostnames in base copy | Host-project values only after adaptation |

Keep role numbers (`001`, `010`, `020`, …) — they are the pipeline identity, not product branding.

---

## 5. Adaptation procedure (for the installing agent)

Execute in order:

1. **Inventory** host repo (section 1). Write findings as a short “Install profile” at the top of a scratch note or PR description.
2. **Place** autoagents under `agents/` (merge carefully if a partial agents tree already exists).
3. **Create** `autoagents.env` from the example; set flags for 005/008.
4. **Rewrite** every prompt that still mentions foreign products, absolute paths, or wrong containers.
5. **Wire** host scripts (sync, archive, link-issues). Update prompts if script names differ.
6. **Smoke-check:**
   - `bash agents/agent-loop.sh help`
   - `AGENT_GH_REPO=… bash agents/agent-loop.sh log` (or `001`) with `gh` auth
   - Confirm task globs resolve under `agents/tasks/`
7. **Document** in host `AGENTS.md`: how to start the loop, required env, which roles are enabled.
8. **Do not** leave `IFNEWMUST.md` unfinished placeholders in runtime prompts — either fill them or delete obsolete optional roles.

---

## 6. Minimal vs full install

### Minimal (most apps)

- Roles: **001**, **010**, **012**, **020**, **030**, **040** (+ optional **002** main coder if present)
- `AGENT_ENABLE_005=0`
- `AGENT_ENABLE_008=0` or keep 008 with project-tuned signals
- Docker containers + `AGENT_GH_REPO` + integration branch sync

### Full (orchestration / multi-repo)

- Enable **005** and rewrite it for the real satellite naming + deploy pipeline
- Enable **008** with real preflight + seed/demo checks
- Provide preflight scripts under `scripts/`

---

## 7. Prompt contract for the adapting session

When you (the adapting agent) run against a new project, your deliverable is:

1. A filled `agents/autoagents.env` (local; do not commit secrets).
2. Updated agent `*.md` files with **only** this project’s facts.
3. Working references to host scripts (or new minimal scripts).
4. A short summary: what was mapped (repo, branches, containers, enabled roles) and what was disabled.

**Success criterion:** A human can run `./agents/agent-loop.sh` (or a single step) and agents never look for the previous product’s paths, containers, or GitHub org.

---

## 8. Quick reference — env vars

| Variable | Meaning |
|----------|---------|
| `AGENT_GH_REPO` | `owner/repo` for issues |
| `AGENT_DOCKER_CONTAINERS` | Space-separated names for log heuristics |
| `AGENT_INTEGRATION_BRANCH` | Day-to-day branch (often `development`) |
| `AGENT_PRODUCTION_BRANCH` | Release branch |
| `APP_CODE_DIRS` | Trees coders may edit |
| `AGENT_ENABLE_005` | `0`/`1` satellite reviewer |
| `AGENT_ENABLE_008` | `0`/`1` enhancement reviewer |
| `AGENT_LOOP_SLEEP_MINUTES` | Loop interval |
| `AGENT_GIT_SYNC` | `0` skips sync |
| `AGENT_*_TIMEOUT_MINUTES` | Per-step cursor-agent walls |

See `agents/agent-loop.sh help` for the full list.

---

## 9. Anti-patterns

- Copying prompts from another product without rewriting APP_CODE_DIRS / containers / GH repo.
- Renaming the loop back to a product prefix.
- Keeping `agents2/` path strings.
- Enabling 005 “just in case” without a satellite inventory.
- Putting tokens in `autoagents.env.example` or committing `autoagents.env`.
- Skipping GitHub label creation and then failing every `gh issue edit --add-label`.

---

*End of IFNEWMUST. After a successful install, keep this file in `agents/` so the next project can repeat the same adaptation.*
