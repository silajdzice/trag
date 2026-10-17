#!/usr/bin/env bash
# Quality gate: format lint, package tests (warnings as errors), app build (warnings as errors).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "▸ Format"
swift format lint --strict --recursive --parallel Trag TragKit/Sources TragKit/Tests TragKit/Package.swift

echo "▸ Package tests"
(cd TragKit && swift test -Xswiftc -warnings-as-errors 2>&1 | grep -E "Test run|error|failed|✘" )

echo "▸ App build"
DERIVED="${DERIVED_DATA:-$(mktemp -d)}"
xcodebuild -quiet -project Trag.xcodeproj -scheme Trag \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED" build

echo "✔ All checks passed"
