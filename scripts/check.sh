#!/usr/bin/env bash
# Quality gate: format lint, package tests, app build + tests, localization. Warnings are errors.
# xcodebuild (not `swift test`) because MLX compiles Metal shaders; -skipMacroValidation trusts the pinned MLX macros.
set -euo pipefail
cd "$(dirname "$0")/.."

DERIVED="${DERIVED_DATA:-$(mktemp -d)}"
SIMULATOR="${SIMULATOR:-$(xcrun simctl list devices available | grep -m1 -oE 'iPhone [0-9]+[a-zA-Z ]*\(' | sed 's/ ($//')}"

run() {
  local name="$1" log="$DERIVED/$2.log"; shift 2
  if ! "$@" >"$log" 2>&1; then
    grep -E "error:|✘|failed" "$log" | grep -v "\.dia" | head -30 || tail -40 "$log"
    echo "✘ $name failed (full log: $log)"
    exit 1
  fi
}

echo "▸ Format"
swift format lint --strict --recursive --parallel Trag TragTests TragKit/Sources TragKit/Tests TragKit/Package.swift

echo "▸ Package tests (macOS)"
run "Package tests" package-test bash -c "cd TragKit && xcodebuild -skipMacroValidation -scheme TragKit-Package \
  -destination 'platform=macOS' -derivedDataPath '$DERIVED/package' test -skip-testing:AICoachEvals"
grep -E "Test run with" "$DERIVED/package-test.log" | sed 's/^/  /'

echo "▸ App build and tests on $SIMULATOR"
run "App build or tests" app-test xcodebuild -quiet -skipMacroValidation -project Trag.xcodeproj -scheme Trag \
  -destination "platform=iOS Simulator,name=$SIMULATOR" -derivedDataPath "$DERIVED" test
grep -cE "^Test case .* pass" "$DERIVED/app-test.log" | xargs -I{} echo "  {} app tests passed"
if grep -E "warning:" "$DERIVED/app-test.log" | grep -vE "checkouts|SourcePackages|\.dia" | grep -q .; then
  echo "✘ Warnings in Trag sources"; exit 1
fi

echo "▸ Localization"
./scripts/check-localization.py "$DERIVED"

echo "✔ All checks passed"
