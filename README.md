# autoagents (agents/)

Stack-agnostic agent-ops package. Install as **`agents/`** at the host repo root. Adapt with **[IFNEWMUST.md](IFNEWMUST.md)**.

## Standing rules (always)

1. **Always test** after a runtime change (project test commands / task verification). Use the tester role and [`testing/`](testing/) for in-flight work.
2. **Always read logs** after start/restart or failed behaviour (Docker containers from `AGENT_DOCKER_CONTAINERS`, and/or `AGENT_LOG_PATH` via [`log-monitor/`](log-monitor/) when configured).

## What lives here

| Path | Purpose |
|------|---------|
| [`agent-loop.sh`](agent-loop.sh) | Orchestrator (`./agents/agent-loop.sh`) |
| [`tasks/`](tasks/) | Queue: `NEW-` / `FEAT-` / `WIP-` / `UNTESTED-` / `CLOSED-` → `done/YYYY/MM/DD/` |
| [`testing/`](testing/) | Tester home + in-flight `TESTING-*` under `testing/active/` |
| [`log-monitor/`](log-monitor/) | Optional read-only app-log scanner → findings in `agents-tasks/` |
| [`agents-tasks/`](agents-tasks/) | Log findings (`log-NNN-*.md`) and scan summaries |
| [`007-quality-monitor/`](007-quality-monitor/) | Optional weekly repo hygiene (root clutter, dead scaffolding) |
| [`workspace/`](workspace/) | Session `todo.md` / `lessons.md` |
| `001` … `040` prompt files | Pipeline roles (see `agent-loop.sh help`) |
| [`TASKS-README.md`](TASKS-README.md) | Filename statuses and archive layout |
| [`IFNEWMUST.md`](IFNEWMUST.md) | Install / adaptation checklist |

## What does **not** live here

| Item | Notes |
|------|--------|
| Product skills for one framework/language | Keep in the host project (or runtime skill dirs), not in this package |
| Host `scripts/` helpers | Copy from [`host-scripts/`](host-scripts/) into the host repo |
| Secrets | `autoagents.env` only (gitignored); start from `autoagents.env.example` |

## Quick start (host project)

```bash
cp agents/autoagents.env.example agents/autoagents.env   # fill AGENT_GH_REPO, branches, APP_CODE_DIRS
./agents/agent-loop.sh help
./agents/agent-loop.sh          # full cycle loop
```
