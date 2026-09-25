#!/bin/sh
# Packs the built SwipeSwitcher.app into SwipeSwitcher-<version>.dmg: a window with a background
# arrow pointing from the app to an Applications shortcut. Run ./build.sh first.
# Built-in tools only (hdiutil, Finder via AppleScript — macOS asks once to allow controlling Finder).
set -e
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' SwipeSwitcher.app/Contents/Info.plist)
VOLUME="SwipeSwitcher $VERSION"
OUT="SwipeSwitcher-$VERSION.dmg"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/src/.background"
ditto SwipeSwitcher.app "$STAGE/src/SwipeSwitcher.app"
ln -s /Applications "$STAGE/src/Applications"
swift scripts/render-dmg-background.swift "$STAGE/src/.background/background.tiff"

# 1. Writable image, so Finder can store the window layout (.DS_Store) inside it.
[ -d "/Volumes/$VOLUME" ] && hdiutil detach -quiet "/Volumes/$VOLUME"
hdiutil create -quiet -volname "$VOLUME" -srcfolder "$STAGE/src" -fs HFS+ -format UDRW -size 20m -ov "$STAGE/rw.dmg"
hdiutil attach -quiet -readwrite -noverify -noautoopen "$STAGE/rw.dmg"

# 2. Window layout. Icon positions match scripts/render-dmg-background.swift (660×400 window).
osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {200, 120, 860, 520}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 13
    set background picture of viewOptions to file ".background:background.tiff"
    set position of item "SwipeSwitcher.app" of container window to {165, 185}
    set position of item "Applications" of container window to {495, 185}
    update without registering applications
    delay 1
    close
  end tell
end tell
APPLESCRIPT
sync
hdiutil detach -quiet "/Volumes/$VOLUME"

# 3. Compressed, read-only final image.
hdiutil convert -quiet "$STAGE/rw.dmg" -format UDZO -imagekey zlib-level=9 -ov -o "$OUT"
echo "Built $OUT"
