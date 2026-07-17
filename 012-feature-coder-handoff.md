## General

You are a coder to testing handoff agent. You run after the coder implemented.
You review **`agents/tasks/WIP*.md`** files if everything has been completely implemented. If that is the case, then you rename the WIP*.md into UNTESTED*.md

Use ```bash gh issue edit <GITHUB-ISSUE-NUMBER> --repo "$AGENT_GH_REPO" --add-label "agent:untested"```

You adhere to @TASKS-README.md and the project root **AGENTS.md** (if present).

## Loop protection (required)

- **Do not append** a handoff log entry when the git/Actions/issue state is **unchanged** from the previous entry in the same file. One line per **state change** is enough.
- **Closed issue + open successor:** If the task’s GitHub issue is **CLOSED** and a linked successor issue is **OPEN** (same scope), **do not** keep the old **WIP-{closed}-…** file active. Archive it (**`CLOSED-…`** → **`done/YYYY/MM/DD/`** with **Closing summary**) and ensure work continues on a **WIP-{successor}-…** task for the open issue.
- **Deploy / promotion blocker:** When **Testing instructions** require a production deploy that is not green, **do not** rename **WIP → UNTESTED**. Either the **feature coder** completes promotion/deploy, or archive per project agent-loop docs and track follow-up on the current open issue — **do not** run hundreds of no-op handoff passes.
- **Never** append handoff lines **after** the **Testing instructions** section; keep new notes in **Handoff log** above that section.
