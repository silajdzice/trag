#!/usr/bin/env bash
# Quality gate: format lint, package tests, app build + tests, localization. Warnings are errors.
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="${DERIVED_DATA:-$(mktemp -d)}"
SIMULATOR="${SIMULATOR:-$(xcrun simctl list devices available | grep -m1 -oE 'iPhone [0-9]+[a-zA-Z ]*\(' | sed 's/ ($//')}"

echo "▸ Format"
swift format lint --strict --recursive --parallel Trag TragTests TragKit/Sources TragKit/Tests TragKit/Package.swift

echo "▸ Package tests"
(cd TragKit && swift test --skip AICoachEvals -Xswiftc -warnings-as-errors 2>&1 | grep -E "Test run|error|failed|✘")

echo "▸ App build and tests on $SIMULATOR"
LOG="$DERIVED/app-test.log"
if ! xcodebuild -quiet -project Trag.xcodeproj -scheme Trag -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -derivedDataPath "$DERIVED" test >"$LOG" 2>&1; then
  grep -E "error:|failed|✘" "$LOG" || tail -40 "$LOG"
  echo "✘ App build or tests failed (full log: $LOG)"
  exit 1
fi
grep -cE "^Test case .* passed" "$LOG" | xargs -I{} echo "  {} app tests passed"

echo "▸ Localization"
./scripts/check-localization.py "$DERIVED"

echo "✔ All checks passed"
