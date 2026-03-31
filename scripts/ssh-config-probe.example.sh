#!/usr/bin/env bash
# Example: inspect SSH client config for a host alias (no real hostnames required).
# Copy, rename, edit HOST=, chmod +x, run locally. Not used by Jarvys automation.
# Usage: HOST=myserver ./ssh-config-probe.example.sh
set -euo pipefail

HOST="${HOST:-your-ssh-host-alias}"
echo "=== ssh -G $HOST (first 30 lines) ==="
ssh -G "$HOST" 2>&1 | head -30 || true
