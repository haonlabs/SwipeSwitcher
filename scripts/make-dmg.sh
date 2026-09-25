#!/bin/sh
# Packs the built SwipeSwitcher.app into SwipeSwitcher-<version>.dmg, with an Applications
# shortcut so users install by dragging. Run ./build.sh first. Uses only built-in hdiutil.
set -e
cd "$(dirname "$0")/.."
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' SwipeSwitcher.app/Contents/Info.plist)
STAGE=$(mktemp -d)
ditto SwipeSwitcher.app "$STAGE/SwipeSwitcher.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "SwipeSwitcher $VERSION" -srcfolder "$STAGE" -format UDZO -ov "SwipeSwitcher-$VERSION.dmg"
rm -rf "$STAGE"
echo "Built SwipeSwitcher-$VERSION.dmg"
