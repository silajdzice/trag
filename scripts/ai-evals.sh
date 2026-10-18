#!/usr/bin/env bash
# Scores Apple Intelligence (both chat strategies) on this Mac with the shared EvalSuite.
# Downloaded models are scored on the phone in the app's AI lab, so nothing is downloaded here.
set -euo pipefail
cd "$(dirname "$0")/../TragKit"
xcodebuild -skipMacroValidation -scheme TragKit-Package -destination 'platform=macOS' \
  -derivedDataPath "${DERIVED_DATA:-$(mktemp -d)}" test -only-testing:AICoachEvals 2>&1 \
  | grep -E "^EVAL|  ✗|✔ Test run|✘ Test run" || true
