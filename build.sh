#!/bin/sh
# Builds SwipeSwitcher.app (a .app is just a folder: Contents/Info.plist + Contents/MacOS/<binary>).
set -e
cd "$(dirname "$0")"
swift build -c release
APP=SwipeSwitcher.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/SwipeSwitcher "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP" # ad-hoc signature: enough to run locally, not to distribute
echo "Built $APP"
