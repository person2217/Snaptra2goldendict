#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-run}"
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/goldendict-lite-clang"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/goldendict-lite-swift"
swift build --disable-sandbox
APP="$PWD/dist/GoldenDictLite.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/StatusBarIcon.png "$APP/Contents/Resources/StatusBarIcon.png"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp .build/debug/GoldenDictLite "$APP/Contents/MacOS/GoldenDictLite"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>GoldenDictLite</string>
<key>CFBundleIdentifier</key><string>local.goldendict.lookuphelper</string>
<key>CFBundleName</key><string>GoldenDict 取词</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSScreenCaptureUsageDescription</key><string>识别鼠标下方的单词并在 GoldenDict-ng 中查询。</string>
</dict></plist>
PLIST
codesign --force --sign - "$APP" >/dev/null
case "$MODE" in
  --build-only) echo "$APP" ;;
  run) /usr/bin/open -n "$APP" ;;
  --verify) /usr/bin/open -n "$APP"; sleep 2; pgrep -x GoldenDictLite ;;
  --debug) lldb -- "$APP/Contents/MacOS/GoldenDictLite" ;;
  --logs) /usr/bin/open -n "$APP"; /usr/bin/log stream --info --style compact --predicate 'process == "GoldenDictLite"' ;;
  --telemetry) /usr/bin/open -n "$APP"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "local.goldendict.lookuphelper"' ;;
  *) echo "usage: $0 [--build-only|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
