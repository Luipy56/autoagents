# agents-tasks

Log findings from [`../log-monitor/`](../log-monitor/) (`log-NNN-topic.md`). Optional manual notes may live here too.

**Log path:** set `AGENT_LOG_PATH` in `autoagents.env` (do not truncate the live log from this folder).

## Summary

| Id | Topic | Status | Created (UTC) | Summary |
|----|-------|--------|---------------|---------|
| *(none yet)* | | | | |

## Finding format

- **Filename:** `log-NNN-kebab-topic.md` (next free `NNN`)
- **Body:** UTC created, signature / greps, short summary, suggested follow-up (`NEW-` / `FEAT-` only if actionable and not already queued)
- **Dedupe:** same ERROR signature within 24h → do not open a second file
