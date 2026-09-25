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
# Sign with a stable certificate if the keychain has one (SIGN_IDENTITY, or the first code-signing
# identity), so macOS keeps the Accessibility permission across rebuilds. An ad-hoc signature is
# identified by the binary hash, which changes every build.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -p codesigning | awk '/^ *1\)/ { print $2; exit }')}"
if [ -n "$IDENTITY" ]; then
  codesign --force --sign "$IDENTITY" "$APP"
else
  codesign --force --sign - "$APP" # ad-hoc: runs locally, but permissions reset on every rebuild
  echo "note: signed ad-hoc; create a code-signing certificate in Keychain Access to keep permissions across rebuilds"
fi
echo "Built $APP"
