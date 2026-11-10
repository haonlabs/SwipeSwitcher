# Changelog

## Unreleased

### Fixed
- The selected app now has a neutral, appearance-aware background and outline that remain visible in
  both light and dark appearances.
- The app name is positioned below the selected icon instead of centered below the whole preview.
- The preview now respects Steps per Gesture, showing the current app plus only the reachable
  recent apps. Unlimited still shows all switchable apps.
- Reversing a swipe moves back through the selection without lifting fingers, including after
  reaching the step limit. Returning to the current app and lifting closes the preview.
- Quick gestures commit immediately without flashing the preview. The preview appears only
  if the gesture continues for 150 ms after the first step.
- Scroll blocking now lasts until every finger lifts, including when only two fingers remain
  and the app underneath might otherwise start a navigation gesture. The protection applies
  to all apps, including browsers and native apps. Empty contact frames also end
  the gesture correctly.
- The scroll filter is prepared at launch when Accessibility access is available, avoiding
  filter creation during the first gesture. It remains disabled while idle.

## 1.0.2

### Fixed
- Right after switching desktops, the preview listed apps from both the old and the new
  desktop. The list is now refreshed once the desktop switch has finished, keeping the
  selected app selected.

## 1.0.1

### Fixed
- Scrolling leaked into the app under the pointer while the preview was open (noticeable in
  VS Code). As the fingers lift one by one, the remaining fingers keep scrolling, and that
  scroll and its momentum were passed through. They are now blocked until a new scroll starts.
- The Accessibility permission was lost after every rebuild or update, which silently disabled
  scroll blocking. Builds are now signed with a stable certificate, so the permission persists.

### Changed
- Menus and dialogs are now in English.
- `build.sh` signs with the first code-signing certificate in the keychain (or `SIGN_IDENTITY`)
  and falls back to ad-hoc signing.

## 1.0.0

First public release: four-finger (or three-finger) swipe with a ⌘-Tab style preview, MRU
order limited to the current desktop, automatic gesture-conflict fix, optional scroll blocking,
launch at login.
