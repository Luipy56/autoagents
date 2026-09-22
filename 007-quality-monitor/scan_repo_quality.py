#!/usr/bin/env python3
"""Heuristic repo-quality scan for autoagents installs (weekly quality monitor).

Exit 0 = no fails (warns allowed). Exit 1 = at least one fail.

Usage:
  # Host install (agents/ under host repo):
  python3 agents/007-quality-monitor/scan_repo_quality.py
  # Standalone autoagents package repo (this tree is the package root):
  python3 007-quality-monitor/scan_repo_quality.py

Stack-agnostic: no framework/language required paths. Host projects may fork
this script under scripts/ and tighten REQUIRED / FORBIDDEN lists.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PKG = HERE.parent  # agents/ when nested, or package repo root when freestanding

if PKG.name == "agents":
    AGENTS = PKG
    ROOT = PKG.parent
else:
    # Developing the autoagents package itself: package files live at repo root.
    AGENTS = PKG
    ROOT = PKG

# Paths that must NOT exist at host repo root (belong under agents/).
FORBIDDEN_ROOT = (
    "agents-tasks",
    "003-tester",
    "004-closing-reviewer",
    "006-feature-coder",
    "007-quality-monitor",
)

# Relative to AGENTS (package root).
REQUIRED_IN_AGENTS = (
    "README.md",
    "TASKS-README.md",
    "agent-loop.sh",
    "testing/README.md",
    "007-quality-monitor/PROMPT.md",
)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    fails: list[str] = []
    warns: list[str] = []

    if not (AGENTS / "agent-loop.sh").is_file():
        fails.append(f"expected agent-loop.sh under package root: {AGENTS}")
        report = {"fails": fails, "warns": warns, "ok": False}
        _emit(report, args.json)
        return 1

    # Forbidden paths only apply at the *host* root when package is nested as agents/.
    if PKG.name == "agents":
        for name in FORBIDDEN_ROOT:
            p = ROOT / name
            if p.exists():
                fails.append(f"forbidden root path still present: {name} (move under agents/)")

    for rel in REQUIRED_IN_AGENTS:
        if not (AGENTS / rel).is_file():
            fails.append(f"missing required file: {rel} (under {AGENTS.name}/)")

    suspicious_prefixes = (
        "UNTESTED-",
        "CLOSED-",
        "WIP-",
        "FEAT-",
        "NEW-",
        "TESTING-",
        "TESTPLAN-",
    )
    for child in ROOT.iterdir():
        if child.name.startswith(suspicious_prefixes):
            fails.append(f"task-like file at {ROOT.name}/: {child.name}")

    # TESTING-* must live under testing/active/, not tasks/
    tasks = AGENTS / "tasks"
    if tasks.is_dir():
        for p in tasks.glob("TESTING-*"):
            if p.is_file():
                fails.append(
                    f"TESTING file in tasks/ (move to testing/active/): {p.name}"
                )

    active = AGENTS / "testing" / "active"
    if not active.is_dir():
        warns.append("testing/active/ missing — create for in-flight TESTING-*")

    nm = ROOT / "node_modules"
    if nm.is_dir():
        warns.append("local node_modules/ present — safe to rm -rf if unused and gitignored")

    report = {
        "fails": fails,
        "warns": warns,
        "ok": not fails,
        "agents": str(AGENTS),
        "root": str(ROOT),
    }
    _emit(report, args.json)
    return 0 if not fails else 1


def _emit(report: dict, as_json: bool) -> None:
    if as_json:
        print(json.dumps(report, indent=2))
        return
    print(f"root={report.get('root', ROOT)}")
    print(f"agents={report.get('agents', AGENTS)}")
    fails = report["fails"]
    warns = report["warns"]
    if fails:
        print(f"FAILS ({len(fails)}):")
        for f in fails:
            print(f"  - {f}")
    else:
        print("FAILS: none")
    if warns:
        print(f"WARNS ({len(warns)}):")
        for w in warns:
            print(f"  - {w}")
    else:
        print("WARNS: none")
    print("ok" if report["ok"] else "needs_fix")


if __name__ == "__main__":
    sys.exit(main())
