#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p build
xcrun swiftc -warnings-as-errors -swift-version 5 Sources/Settings.swift TestsUI/main.swift -o build/ui-tests
build/ui-tests
