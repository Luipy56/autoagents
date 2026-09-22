# Quality monitor (optional)

Standing role: catch **repo-root clutter** and **dead scaffolding** before a human has to ask.

This is **repo hygiene**, not product UI polish and not the enhancement idea sweep (**008**). Do **not** copy host-project skills for a single framework or language into this package.

## Schedule

Optional weekly (or when `AGENT_ENABLE_007=1` in the loop). Host projects may wire a cron/schedule separately.

## Entrypoints

| Item | Path |
|------|------|
| Prompt | [PROMPT.md](PROMPT.md) |
| Scanner | `python3 agents/007-quality-monitor/scan_repo_quality.py` |

## Prompt

Follow [PROMPT.md](PROMPT.md) when running as the quality-monitor agent.
