# Sample finding (reference — not an active task)

This file shows what agent **008** might queue after a preflight run. **Do not** treat this as a live task; copy the structure into **`agents/tasks/FEAT-0-…md`** when scheduling work. Rewrite paths/hosts for the host project (see **IFNEWMUST.md**).

---

## Example: Schedule daily demo data reset

**Preflight signal:** `demo_daily_reset_not_scheduled`

**Proposed task filename:** `FEAT-0-20260712-1811-schedule-daily-demo-data-reset.md`

```markdown
# Schedule daily demo data reset (demo tenant)

## GitHub Issues
- **Issue:** (none — enhancement reviewer)
- **0**

## Problem / goal
Demo / seed data drifts without a documented daily reset on the demo environment.

## Evidence (008 preflight / review)
- SIGNAL: demo_daily_reset_not_scheduled
- No documented cron / scheduled job for demo reset

## High-level instructions for coder
- Locate or create an idempotent reset script under the project’s seeds/scripts tree
- Document the production/demo schedule in `docs/`
- Tester: confirm schedule is documented and dry-run of reset succeeds in the documented environment
```
