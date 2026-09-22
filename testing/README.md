# agents/testing/

Home for **verification**. Standing rule: always test after runtime changes.

## Workflow

1. Pick **one** file under `agents/tasks/` named `UNTESTED-…` (only that file).
2. Move/rename to `agents/testing/active/TESTING-…` (same basename after the prefix).
3. Run verification from the task body (project test commands / listed greps / manual steps).
4. Append a `## Test report` section (UTC date, commands, pass/fail, evidence).
5. Move outcome back under `agents/tasks/`:
   - `CLOSED-…` if acceptance criteria pass
   - `WIP-…` if blocked, failed, or needs follow-up (say why in the report)

Do **not** leave `TESTING-*` in `agents/tasks/`. Do not delete history inside the file; append reports.

Also skim logs related to the change (`AGENT_DOCKER_CONTAINERS` / `agents/log-monitor/` when configured).

## Files

- Role prompt: [`../020-test.md`](../020-test.md)
- [`active/`](active/) — in-flight `TESTING-*` only
