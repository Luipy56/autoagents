# Task workflow (autoagents)

Tasks move through a single pipeline from creation to closure. See project agent-loop docs (if present) for roles, GitHub Issues labels, and branch rules. **Before renaming or editing task files**, sync the **integration branch** with **`./scripts/git-sync-development.sh`** (or the project equivalent; **`agent-loop.sh`** does this each step).

## Filename pattern

`<STATUS>-<GITHUB-ISSUE-NUMBER>-<YYYYMMDD-HHMM>-<slug>.md`

Examples: `NEW-1234-20260323-1030-haproxy-503-on-orders.md`, `CLOSED-1234-20260323-1200-fix-login-banner.md`

The **`<YYYYMMDD>`** segment (8 digits after the first `-`) is used to place archived tasks under **`done/YYYY/MM/DD/`** (see below). When renaming a task to **`CLOSED-…`**, use the **calendar day that work finished** (UTC or your team convention) in `YYYYMMDD` so each day’s folder reflects tasks completed that day.

## Statuses

| Status       | Meaning |
|--------------|--------|
| **new**      | Task is defined and not yet started. |
| **feat**     | Feature-sized task (optional parallel queue). |
| **wip**      | Work in progress until implemented. When implemented rename **WIP*.md** to **UNTESTED*.md** |
| **untested** | Implementation done; **Testing instructions** appended; waiting for tester. |
| **testing**  | Tester is running verification. Lives under **`agents/testing/active/`**, not `agents/tasks/`. |
| **closed**   | Verified; ready for closing reviewer to archive. |

## Flow

```text
  new   ─┐
         ├─→  wip  →  untested  →  testing/active/TESTING-…  →  closed  →  done/YYYY/MM/DD/
  feat  ─┘
```

Do not skip statuses. On test failure: **testing → wip** (coder fixes), then **wip → untested** again when ready.

**Tester home:** see **`agents/testing/README.md`**. Move **`UNTESTED-…`** → **`agents/testing/active/TESTING-…`** when verification starts; on outcome move to **`agents/tasks/CLOSED-…`** or **`WIP-…`**. Do not leave **`TESTING-*`** in **`agents/tasks/`**.

## Archiving closed tasks (`done/` layout)

Closed tasks are **not** kept in a single flat **`done/`** directory. After the closing reviewer prepends the **Closing summary**, the file is moved to:

```text
agents/tasks/done/<YYYY>/<MM>/<DD>/<same-filename>.md
```

- **`<YYYY>`**, **`<MM>`**, and **`<DD>`** come from the **8-digit date in the filename** (`YYYYMMDD` right after the status prefix), not from “today” when you run the script.  
  Example: `CLOSED-20260323-1200-slug.md` → **`agents/tasks/done/2026/03/23/CLOSED-20260323-1200-slug.md`**
- **Same basename** as in **`agents/tasks/`**; only the directory changes.
- One folder per **calendar day**; all tasks whose `CLOSED-` stamp shares that day live in the same **`DD`** folder.

**Helper (recommended):** from repo root,

```bash
./scripts/move-agent-task-to-done.sh agents/tasks/CLOSED-20260323-1200-example-slug.md
```

The script creates **`done/YYYY/MM/DD`** if needed and moves the file. It only accepts **`CLOSED-`** filenames.

When Redmine is configured (`REDMINE_API_KEY`, `REDMINE_ISSUE_ID` in `agents/autoagents.env`), the move script also posts an English Textile closing summary **and** a `time_entry` (hours) via `agents/redmine_sync.py`.

See **`done/README.md`** for a short index of the archive tree (when present).

## Rules of thumb

- **new → wip** / **feat → wip** when work starts.
- **wip → untested** when implementation is complete and **Testing instructions** are at the end of the task file.
- **untested → testing** when the tester starts: move into **`agents/testing/active/TESTING-…`**.
- **testing → closed** when verification passes: move **`TESTING-…`** → **`agents/tasks/CLOSED-…`** (keep the same **`YYYYMMDD-HHMM-slug`**; only change the status prefix). On failure, **testing → wip** under **`agents/tasks/`**.
- **closed → done/YYYY/MM/DD/** after the closing summary is added (use **`move-agent-task-to-done.sh`** or an equivalent `mkdir` + `mv`).

**Standing rules:** always test after runtime changes; always skim related logs (`AGENT_DOCKER_CONTAINERS` / optional **`agents/log-monitor/`**).
