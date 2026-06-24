#!/usr/bin/env bash
# Build BenchGraph.app — a double-clickable macOS app bundle.
#
# SwiftPM produces a bare executable; this wraps it in the .app bundle layout
# macOS needs (Info.plist + Contents/MacOS) so it launches from Finder. For a
# distributable build you would additionally code-sign and notarize with your
# Apple Developer ID (V1 packaging work, see docs/product/mvp-roadmap.md).
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/BenchGraph.app"

echo "Building BenchGraphApp ($CONFIG)..."
swift build -c "$CONFIG" --product BenchGraphApp

BIN="$ROOT/.build/$CONFIG/BenchGraphApp"
[[ -x "$BIN" ]] || { echo "error: built binary not found at $BIN"; exit 1; }

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/BenchGraph"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>             <string>BenchGraph</string>
    <key>CFBundleDisplayName</key>      <string>BenchGraph</string>
    <key>CFBundleIdentifier</key>       <string>com.benchgraph.app</string>
    <key>CFBundleVersion</key>          <string>0.1.0</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>CFBundleExecutable</key>       <string>BenchGraph</string>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
    <key>NSHighResolutionCapable</key>  <true/>
    <key>NSPrincipalClass</key>         <string>NSApplication</string>
</dict>
</plist>
PLIST

# Ad-hoc sign so Gatekeeper lets the local build run without "damaged" errors.
codesign --force --deep --sign - "$APP" 2>/dev/null || \
  echo "note: ad-hoc codesign skipped (codesign unavailable)"

echo "Done: $APP"
echo "Launch it with:  open \"$APP\"    (or double-click in Finder)"
