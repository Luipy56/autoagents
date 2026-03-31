#!/usr/bin/env bash
# Run from your PC: tests SSH aliases amvara4 and amvara8, writes results next to this script.
set -euo pipefail
OUT="$(cd "$(dirname "$0")/.." && pwd)/ssh-amvara-probe.log"
{
  date
  echo "=== ssh -G amvara4 (first 25 lines) ==="
  ssh -G amvara4 2>&1 | head -25 || true
  echo "=== ssh -G amvara8 (first 25 lines) ==="
  ssh -G amvara8 2>&1 | head -25 || true
  echo "=== ssh amvara4 hostname ==="
  ssh -o BatchMode=yes -o ConnectTimeout=25 amvara4 hostname 2>&1 || echo "EXIT:$?"
  echo "=== ssh amvara8 hostname ==="
  ssh -o BatchMode=yes -o ConnectTimeout=25 amvara8 hostname 2>&1 || echo "EXIT:$?"
  echo "=== done ==="
} | tee "$OUT"
echo "Log: $OUT"
