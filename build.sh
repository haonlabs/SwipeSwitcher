#!/bin/sh
# Builds SwipeSwitcher.app (a .app is just a folder: Contents/Info.plist + Contents/MacOS/<binary>).
set -e
cd "$(dirname "$0")"
# Universal binary: runs natively on Apple silicon and Intel Macs.
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
APP=SwipeSwitcher.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/SwipeSwitcher" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp AppIcon.icns "$APP/Contents/Resources/" # regenerate with: swift scripts/render-icon.swift
codesign --force --sign - "$APP" # ad-hoc signature: enough to run locally, not to distribute
echo "Built $APP"
