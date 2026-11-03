#!/bin/sh
set -eu
# Some Command Line Tools releases omit this plugin from SwiftPM's automatic search paths.
recall_swiftc=$(xcrun --find swiftc)
recall_plugin="$(dirname "$recall_swiftc")/../lib/swift/host/plugins/testing/libTestingMacros.dylib"
if [ -f "$recall_plugin" ]; then
    swift test -Xswiftc -warnings-as-errors -Xswiftc -load-plugin-library -Xswiftc "$recall_plugin" "$@"
else
    swift test -Xswiftc -warnings-as-errors "$@"
fi
