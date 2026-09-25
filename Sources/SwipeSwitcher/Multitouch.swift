import AppKit
import CMultitouch
import Synchronization

// Settings written by the menu (main thread) and read by the multitouch thread.
// `Atomic` ≈ Java's AtomicInteger: thread-safe without a lock, a relaxed load is a plain memory read.
let fingerSetting = Atomic<Int>(4)
let thresholdPercent = Atomic<Int>(10)
let maxStepsSetting = Atomic<Int>(1)

/// Called on the main thread for each step and when the fingers lift. Set once at launch.
var onSwipe: (SwipeEvent) -> Void = { _ in }

/// `state` value of a finger that is firmly on the trackpad (see CMultitouch.h).
/// ponytail: hardware calibration knob — if swipes get missed, also accept 3 (making) and 5 (breaking).
private let touchingState: Int32 = 4

// ponytail: one detector for all trackpads; assumes the framework delivers frames on one thread.
// Use a detector per device if two trackpads touched at the same time ever matters.
private var detector = SwipeDetector()
private var devices: CFArray?

// A C function pointer can't capture context (unlike a Kotlin lambda), so it only touches globals.
// Runs on the framework's own thread for EVERY frame while any finger touches the trackpad
// (~90–120 Hz during normal cursor movement and scrolling), so it must stay cheap.
private let contactCallback: MTContactCallback = { _, touches, count, timestamp, _ in
    let need = fingerSetting.load(ordering: .relaxed)
    // Hot path: normal 1–2 finger use exits here — no lock, no allocation, no thread hop.
    if count < need && !detector.isTracking { return 0 }
    guard let touches else { return 0 }

    var fingers = 0
    var sumX: Float = 0, sumY: Float = 0
    for i in 0..<Int(count) where touches[i].state == touchingState {
        fingers += 1
        sumX += touches[i].normalized.position.x
        sumY += touches[i].normalized.position.y
    }
    let n = Float(max(fingers, 1))
    let wasTracking = detector.isTracking
    let result = detector.update(
        fingers: fingers, x: sumX / n, y: sumY / n, time: timestamp, need: need,
        threshold: Float(thresholdPercent.load(ordering: .relaxed)) / 100,
        maxSteps: maxStepsSetting.load(ordering: .relaxed)
    )
    // Once per gesture (fingers land / lift): start/stop swallowing their scroll events.
    if detector.isTracking != wasTracking {
        gestureActive.store(detector.isTracking, ordering: .relaxed)
        if detector.isTracking { DispatchQueue.main.async { enableScrollBlocking() } }
    }
    guard let event = result else { return 0 }

    // Checked only when a step fires, not per frame: thumb-click + drag isn't a swipe.
    if case .step = event, CGEventSource.buttonState(.combinedSessionState, button: .left) { return 0 }
    // Only UI thread (≈ Android main looper) may touch AppKit, so hop there — once per step.
    DispatchQueue.main.async { onSwipe(event) }
    return 0
}

func startMultitouch() {
    guard devices == nil else { return }
    let list = MTDeviceCreateList()
    for i in 0..<CFArrayGetCount(list) {
        let device = UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(list, i))
        MTRegisterContactFrameCallback(device, contactCallback)
        MTDeviceStart(device, 0)
    }
    devices = list // keeps the devices alive (the array retains them)
}

func stopMultitouch() {
    guard let list = devices else { return }
    for i in 0..<CFArrayGetCount(list) {
        let device = UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(list, i))
        MTUnregisterContactFrameCallback(device, contactCallback)
        MTDeviceStop(device)
    }
    devices = nil
}

/// `enum` with associated values ≈ a Kotlin sealed class.
enum SwipeEvent: Equatable {
    case step(Int) // +1 right, -1 left
    case end       // fingers lifted after at least one step
}

/// Pure gesture logic (no framework calls) so it can be unit-tested with fake frames.
/// `struct` = value type like a Kotlin data class that is copied on assignment; `mutating` marks
/// methods that change it.
struct SwipeDetector {
    static let flickerGrace = 0.10 // s a finger may briefly lift/land without cancelling the swipe
    static let cooldown = 0.25     // s minimum between two triggers
    static let dominance: Float = 1.25 // horizontal must beat vertical by this ratio

    private var last: SIMD2<Float>?
    private var moved = SIMD2<Float>.zero
    private var steps = 0
    private var mismatchSince: Double?
    private var lastFire = -Double.infinity

    var isTracking: Bool { last != nil }

    /// `.step(±1)` each time the fingers travel `threshold` (fraction of trackpad width) sideways,
    /// `.end` when they lift after a step.
    mutating func update(
        fingers: Int, x: Float, y: Float, time: Double,
        need: Int, threshold: Float, maxSteps: Int
    ) -> SwipeEvent? {
        let point = SIMD2(x, y)
        guard fingers == need else {
            guard last != nil else { return nil }
            if abs(fingers - need) != 1 { return end() }
            if let since = mismatchSince {
                if time - since > Self.flickerGrace { return end() }
            } else {
                mismatchSince = time
            }
            return nil
        }
        guard let previous = last, mismatchSince == nil else {
            // New gesture, or back from a flicker: the centroid jumped, so re-anchor without moving.
            if last == nil { moved = .zero }
            last = point
            mismatchSince = nil
            return nil
        }
        moved += point - previous
        last = point

        guard steps < maxSteps, time - lastFire >= Self.cooldown,
              abs(moved.x) >= threshold, abs(moved.x) > abs(moved.y) * Self.dominance
        else { return nil }
        steps += 1
        lastFire = time
        let direction = moved.x > 0 ? 1 : -1
        moved = .zero // multi-step: the next app needs another full threshold of travel
        return .step(direction)
    }

    private mutating func end() -> SwipeEvent? {
        let hadSteps = steps > 0
        last = nil
        mismatchSince = nil
        steps = 0
        return hadSteps ? .end : nil
    }
}
