import AppKit
import Synchronization

// Moving N fingers also produces scroll events, and macOS "latches" a scroll to the window that
// got its first event — so once it started, the preview overlay can't take it over. Dropping
// those events needs an active event tap (Accessibility permission).
//
// Energy: the tap is disabled except from the moment the gesture fingers land until the
// swallowed scroll's momentum is over. Normal scrolling never passes through this process.

/// True while the gesture fingers are on the trackpad. Written by the multitouch thread.
let gestureActive = Atomic<Bool>(false)

private var scrollTap: CFMachPort? // main thread only

private let scrollTapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if gestureActive.load(ordering: .relaxed), let scrollTap { CGEvent.tapEnable(tap: scrollTap, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    if gestureActive.load(ordering: .relaxed) { return nil } // drop: scroll from the gesture fingers
    // Fingers lift one by one, so the swallowed scroll keeps going (phase "changed"/"ended")
    // and then coasts (momentum) after our gesture ended. Drop all of it.
    if event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0 { return nil }
    let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
    if phase == 2 || phase == 4 || phase == 8 { return nil } // changed, ended, cancelled
    // A new scroll (began / may-begin) or a mouse wheel (no phase): step out of the event path.
    if let scrollTap { CGEvent.tapEnable(tap: scrollTap, enable: false) }
    return Unmanaged.passUnretained(event)
}

/// Called on the main thread when the gesture fingers land. No-op without Accessibility permission.
func enableScrollBlocking() {
    if scrollTap == nil {
        guard AXIsProcessTrusted() else { return }
        scrollTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(1) << CGEventType.scrollWheel.rawValue,
            callback: scrollTapCallback, userInfo: nil)
        guard let scrollTap else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, scrollTap, 0), .commonModes)
    }
    if let scrollTap { CGEvent.tapEnable(tap: scrollTap, enable: true) }
}

/// Shows the system "allow Accessibility" prompt if not granted yet; returns current state.
@discardableResult
func requestScrollBlockingPermission(prompt: Bool) -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
