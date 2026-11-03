#!/bin/sh
set -eu
recur_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$recur_root"
Scripts/lint.sh
Scripts/test.sh
node Scripts/check_math.cjs
swift Scripts/check_renderer.swift
xcodebuild -project MathRecall.xcodeproj -scheme MathRecall \
    -destination 'generic/platform=iOS' -derivedDataPath /tmp/recur-quality-build \
    CODE_SIGNING_ALLOWED=NO build
