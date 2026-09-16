#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p build
xcrun swiftc -warnings-as-errors -swift-version 5 Sources/Control.swift Tests/main.swift -o build/filter-tests
build/filter-tests
