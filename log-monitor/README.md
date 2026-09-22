# agents/log-monitor/

Home for **reading application logs** (file-based). Standing rule: always skim logs after runtime changes or failed behaviour.

For **Docker** log heuristics, the **001** reviewer still uses `AGENT_DOCKER_CONTAINERS`. This folder is for an optional **on-disk** log (e.g. `debug.log`, `var/log/app.log`).

## Config

In `agents/autoagents.env`:

```bash
AGENT_ENABLE_LOG_MONITOR=1
AGENT_LOG_PATH=/path/to/app.log   # or relative to host repo root
```

## Rules

1. Read only the configured log (tail / recent window unless asked for a deeper scan).
2. Find **ERROR**, panic, crash loops, and recurring **WARN** that look product-owned.
3. For each distinct new issue, create **one** finding under `agents/agents-tasks/` as `log-NNN-topic.md` (next free NNN). Include UTC time and a short summary.
4. Update the summary table in `agents/agents-tasks/README.md`.
5. Deduplicate: same signature within 24h → do not open a second file.
6. **Do not** truncate, delete, or rename the live log. The app owns rotation.
7. Optionally queue a `NEW-` / `FEAT-` task only when the finding is actionable and not already in the pipeline.

## Ignore (benign noise)

Document recurring false positives in this README as they appear. Prefer fixing product bugs over expanding the ignore list.

## Prompt

Follow [PROMPT.md](PROMPT.md) when running as the log-monitor agent.
