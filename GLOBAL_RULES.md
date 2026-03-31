# Jarvys Team — global rules

Portable rules for any repository where you attach this bundle. Replace stack-specific checks (e.g. `php artisan test`) in prompts with your project’s commands.

## Git

- Work on the **integration branch** (`AGENT_GIT_BRANCH`, default **`agentdevelop`**). Run **`scripts/git-sync-agent-branch.sh`** (or equivalent fetch + checkout + `git pull --rebase --autostash`) **before** editing so concurrent agents and humans integrate cleanly.
- **Do not** merge the integration branch to **`main`** / **`master`** unless one of these applies: ~2-hour batch cadence, large production-impacting change, **production-urgent** issue, or explicit request from the project owner.
- Routine work: **commit and push** the integration branch; promotion to production follows your release process.

## Tasks

- Filename pattern: **`<STATUS>-<YYYYMMDD-HHMM>-<slug>.md`** (see **`agents/tasks/README.md`**).
- **Do not skip statuses** in the pipeline (`NEW` / `FEAT` → `WIP` → `UNTESTED` → `TESTING` → `CLOSED` → archive under **`done/YYYY/MM/DD/`**).
- When renaming to **`CLOSED-`**, keep the same date-time slug; use the calendar day that reflects completion per team convention (often UTC).
- Archive with **`scripts/move-agent-task-to-done.sh`** from the **repository root**.

## Security

- **Never commit secrets** (API keys, tokens, `.env` with real credentials). Use `.env.example` and secret managers.
- Prefer **least privilege** for any shell or tool the executor runs; review what the CLI can execute before enabling “yolo”-style automation in unfamiliar environments.

## Verification

- After substantive changes: run the **tests and smoke checks** appropriate to the stack (unit/integration tests, build, lint, manual checks). Document the exact commands in role prompts or project **`AGENTS.md`**.
- Failures: move tasks back in the pipeline per **`agents/tasks/README.md`** (e.g. testing → wip).

## Attribution

- **No** `Co-authored-by:` or automated tool branding in commit messages unless your organization explicitly requires it.
