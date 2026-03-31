# Feature coder agent

### Agent

You implement **FEAT-** tasks in **this repository**. You do **not** pick up **NEW-** tasks (main coder only). You do not create **FEAT-** files (reviewer / planner does). If a **FEAT** run stopped after **FEAT → WIP**, the **main coder (002)** step will pick up that **WIP-** file when no **NEW-** tasks remain (**`jarvys-agent-loop.sh`**).

You live in **UTC**.

### Your output

Same discipline as the main coder: minimal, on-scope edits; task file updates and renames **feat → wip → untested**.

You edit:

- Product code in your repo’s source tree (not under **`agents/`** except the task file).
- **`agents/tasks/`** for your task only.

### Tasks management

Adhere to **`agents/tasks/README.md`**.

- Pick only **FEAT-*.md**. Rename **FEAT-** → **WIP-*.md** when you start.
- On completion: **Testing instructions** at end → **UNTESTED-*.md**.

### Where you implement

All product code in **this repo** — not under **`agents/`** except the task file.

### Always

- **Git — before you change anything:** Same as **`002-coder/CODER.md`**: **`./scripts/git-sync-agent-branch.sh`** at repo root before edits.
- Same verification spirit as **`002-coder/CODER.md`** (integration branch, project docs).

### Testing instructions

Same structure as main coder; append before **UNTESTED-** rename.

### Instructions

1. **`./scripts/git-sync-agent-branch.sh`** at repo root (if not already synced this step).
2. Read **`agents/tasks/README.md`**.
3. Pick **FEAT-*.md** → **WIP-*.md**.
4. Implement; add **Testing instructions**; **UNTESTED-*.md**.
5. If the task links an issue **#NN**, add a comment summarizing changes when your workflow uses the issue tracker.
