import Foundation

// MultitouchSupport only *reads* touches, it can't stop macOS from also acting on them.
// So instead of blocking live (event tap: needs Accessibility and sees every event), we move
// macOS's own "swipe between desktops" off our finger count, once, with the user's consent.
//
// macOS keeps each trackpad gesture in three places (built-in, Bluetooth, per-host global);
// System Settings writes all of them, so we do too. Values: 0 off, 1 swipe pages, 2 desktops.

private let trackpadDomains = ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"]

private func trackpadKey(_ fingers: Int) -> String {
    fingers == 3 ? "TrackpadThreeFingerHorizSwipeGesture" : "TrackpadFourFingerHorizSwipeGesture"
}

private func globalKey(_ fingers: Int) -> String {
    fingers == 3 ? "com.apple.trackpad.threeFingerHorizSwipeGesture" : "com.apple.trackpad.fourFingerHorizSwipeGesture"
}

private func horizontalSwipe(_ fingers: Int) -> Int {
    CFPreferencesCopyAppValue(trackpadKey(fingers) as CFString, trackpadDomains[0] as CFString) as? Int ?? 0
}

/// True when macOS already does something with a horizontal swipe of `fingers` fingers.
func systemUsesHorizontalSwipe(fingers: Int) -> Bool {
    horizontalSwipe(fingers) != 0
}

/// Frees `fingers` for SwipeSwitcher; desktops move to the other finger count if that is unused.
func freeHorizontalSwipe(fingers: Int) {
    let other = fingers == 3 ? 4 : 3
    let desktopsWereHere = horizontalSwipe(fingers) == 2
    setHorizontalSwipe(fingers, 0)
    if desktopsWereHere && horizontalSwipe(other) == 0 { setHorizontalSwipe(other, 2) }
    // Makes running processes (Dock) reload trackpad settings without logging out.
    let activate = URL(fileURLWithPath: "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings")
    try? Process.run(activate, arguments: ["-u"]).waitUntilExit()
}

private func setHorizontalSwipe(_ fingers: Int, _ value: Int) {
    for domain in trackpadDomains {
        CFPreferencesSetValue(trackpadKey(fingers) as CFString, value as CFNumber, domain as CFString,
                              kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        CFPreferencesSynchronize(domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }
    CFPreferencesSetValue(globalKey(fingers) as CFString, value as CFNumber, kCFPreferencesAnyApplication,
                          kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
    CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
}
