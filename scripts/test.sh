#!/usr/bin/env bash
# Run the test suite. XCTest is not available with only the Command Line Tools,
# so point the toolchain at the Swift Testing framework shipped inside them.
cd "$(dirname "$0")/.." || exit 1
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks; exec swift test -Xswiftc -F$F -Xlinker -F$F -Xlinker -rpath -Xlinker $F "$@"
