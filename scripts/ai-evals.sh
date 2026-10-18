#!/usr/bin/env bash
# Runs the on-device model evals (needs a Mac with Apple Intelligence enabled). Prints scores.
set -euo pipefail
cd "$(dirname "$0")/../TragKit"
swift test --filter AICoachEvals 2>&1 | grep -E "EVAL|  →|  •|expected|✔|✘|skipped" || true
