#!/bin/sh
set -eu
recur_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$recur_root"
PATH="$PATH:/opt/homebrew/bin:/usr/local/bin"
export PATH
recur_expected=$(cat .swiftlint-version)
if ! command -v swiftlint >/dev/null 2>&1; then
    echo "error: SwiftLint $recur_expected is required. Install it before building." >&2
    exit 1
fi
recur_actual=$(swiftlint version)
if [ "$recur_actual" != "$recur_expected" ]; then
    echo "error: SwiftLint $recur_expected is required; found $recur_actual." >&2
    exit 1
fi
xcrun swift format lint --strict --recursive App Sources/RecallCore Sources/RecallMath Tests/RecallCoreTests Tests/RecallMathTests Tools Scripts Package.swift
swiftlint lint --strict --quiet --no-cache
