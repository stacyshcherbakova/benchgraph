#!/usr/bin/env bash
# Run the BenchGraphKit test suite.
#
# Swift Testing (`import Testing`) ships inside Xcode, but on machines that only
# have the Command Line Tools installed the framework and its interop dylib are
# in non-default locations. This wrapper points the compiler/linker at them so
# `swift test` works without a full Xcode install. With full Xcode present,
# plain `swift test` also works.
set -euo pipefail

CLT_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
CLT_LIBS="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

if [[ -d "$CLT_FRAMEWORKS" ]]; then
  exec swift test \
    -Xswiftc -F -Xswiftc "$CLT_FRAMEWORKS" \
    -Xlinker -F -Xlinker "$CLT_FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$CLT_FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$CLT_LIBS" \
    "$@"
else
  exec swift test "$@"
fi
