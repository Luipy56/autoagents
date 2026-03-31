# Jarvys smoke task

**Goal:** Prove Jarvys (Aider + Ollama) can apply a tiny change in this repo.

## Requirements

1. Create a directory **`jarvys-smoke/`** at the repository root (if it does not exist).
2. Add **`jarvys-smoke/hello.txt`** containing exactly this single line (no extra blank lines):  
   `Jarvys smoke test OK`
3. This clone has **no `origin/agentdevelop`** yet — **do not** run `./scripts/git-sync-agent-branch.sh`; it will fail.

## Handoff

When the file exists and matches, append **Testing instructions** at the end of this task file, then rename this file **NEW-** → **WIP-** → **UNTESTED-** per `agents/tasks/README.md`.

### Testing instructions (template for you to fill after implementation)

- Verify: `test -f jarvys-smoke/hello.txt && grep -q 'Jarvys smoke test OK' jarvys-smoke/hello.txt && wc -l < jarvys-smoke/hello.txt | grep -q '^1$'`
