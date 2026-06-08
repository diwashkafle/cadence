#!/bin/bash
# Builds Cadence.app from the Swift package — no Xcode required.
set -e
cd "$(dirname "$0")"

APP="Cadence.app"
BIN="Cadence"

echo "==> Building (release)…"
swift build -c release

echo "==> Assembling $APP…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/$BIN" "$APP/Contents/MacOS/$BIN"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Cadence</string>
    <key>CFBundleDisplayName</key>     <string>Cadence</string>
    <key>CFBundleExecutable</key>      <string>Cadence</string>
    <key>CFBundleIdentifier</key>      <string>com.cadence.app</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>14.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>LSApplicationCategoryType</key> <string>public.app-category.productivity</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Cadence reads the active tab's address from your browser to count time on your work websites.</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing (so permissions persist)…"
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || \
    echo "   (codesign skipped — app still runs, but TCC grants may re-prompt)"

echo "==> Done: $(pwd)/$APP"
echo "    Run it with:  open $APP"
