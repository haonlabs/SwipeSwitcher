# Changelog

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
