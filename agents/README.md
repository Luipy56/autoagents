# Agent prompts (Jarvys Team)

Markdown prompts for **Aider** + **Ollama** (see **`jarvys-agent-loop.sh`**). Paths are relative to **`agents/`**.

| # | File | Role |
|---|------|------|
| 001 | [001-log-reviewer/LOG-REVIEWER-PROMPT.md](001-log-reviewer/LOG-REVIEWER-PROMPT.md) | Backlog / log reviewer → task files |
| 002 | [002-coder/CODER.md](002-coder/CODER.md) | Implement **NEW-** and **WIP-** tasks |
| 003 | [003-tester/TESTER.md](003-tester/TESTER.md) | Verify **UNTESTED-** tasks |
| 004 | [004-closing-reviewer/CLOSING-REVIEWER-PROMPT.md](004-closing-reviewer/CLOSING-REVIEWER-PROMPT.md) | Archive **CLOSED-** → **`tasks/done/YYYY/MM/DD/`** |
| 006 | [006-feature-coder/FEATURE-CODER.md](006-feature-coder/FEATURE-CODER.md) | Implement **FEAT-** tasks only |
| 007 | [007-committer/COMMITTER.md](007-committer/COMMITTER.md) | Changelog + version + git on integration branch |

Workflow: **`GLOBAL_RULES.md`**. Task rules: **`tasks/README.md`**.

**Git:** Before editing the repo, sync with **`./scripts/git-sync-agent-branch.sh`**. **`jarvys-agent-loop.sh`** runs it at the start of each step unless **`AGENT_GIT_SYNC=0`**. Branch: **`AGENT_GIT_BRANCH`** (default **`agentdevelop`**).

**Executor:** [Aider](https://aider.chat/) with **`ollama_chat/<model>`** and **`OLLAMA_API_BASE`** pointing at your Ollama instance (see **`docs/jarvys-network.md`**).
