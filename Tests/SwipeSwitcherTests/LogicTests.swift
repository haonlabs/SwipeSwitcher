import Testing
@testable import SwipeSwitcher

/// Feeds a straight swipe of `frames` frames from x=0.3 to `toX` at 100 Hz.
private func swipe(_ d: inout SwipeDetector, fingers: Int = 4, toX: Float, toY: Float = 0.5,
                   start: Double = 0, frames: Int = 20, maxSteps: Int = 1) -> [Int] {
    var fired: [Int] = [] // step directions
    for i in 0...frames {
        let f = Float(i) / Float(frames)
        if let dir = d.update(fingers: fingers, x: 0.3 + (toX - 0.3) * f, y: 0.5 + (toY - 0.5) * f,
                              time: start + Double(i) * 0.01, need: 4, threshold: 0.15, maxSteps: maxSteps) {
            if case .step(let n) = dir { fired.append(n) }
        }
    }
    return fired
}

@Test func detectorDirectionAndThreshold() {
    var d = SwipeDetector()
    #expect(swipe(&d, toX: 0.6) == [1])
    d = SwipeDetector()
    #expect(swipe(&d, toX: 0.0) == [-1])
    d = SwipeDetector()
    #expect(swipe(&d, toX: 0.4).isEmpty) // 10% < 15% threshold
}

@Test func detectorIgnoresWrongFingerCountAndVertical() {
    var d = SwipeDetector()
    #expect(swipe(&d, fingers: 3, toX: 0.9).isEmpty)
    d = SwipeDetector()
    #expect(swipe(&d, toX: 0.5, toY: 0.9).isEmpty) // mostly vertical (Mission Control)
}

@Test func detectorMultiStep() {
    var d = SwipeDetector()
    // 0.3 → 1.0 over 1 s: 70% travel = 4 thresholds, capped by maxSteps.
    #expect(swipe(&d, toX: 1.0, frames: 100, maxSteps: 1) == [1])
    d = SwipeDetector()
    #expect(swipe(&d, toX: 1.0, frames: 100, maxSteps: 3) == [1, 1, 1])
    d = SwipeDetector()
    #expect(swipe(&d, toX: 1.0, frames: 100, maxSteps: .max) == [1, 1, 1, 1])
}

@Test func detectorCooldownLimitsFastSwipes() {
    var d = SwipeDetector()
    // Same 70% travel in 0.1 s: cooldown (250 ms) allows only one trigger.
    #expect(swipe(&d, toX: 1.0, frames: 10, maxSteps: .max) == [1])
}

/// Deliberately cross each threshold by a little to avoid floating-point boundary ambiguity.
private func frame(_ d: inout SwipeDetector, _ x: Float, _ time: Double,
                   maxSteps: Int = 1, fingers: Int = 4) -> SwipeEvent? {
    d.update(fingers: fingers, x: x, y: 0.5, time: time,
             need: 4, threshold: 0.10, maxSteps: maxSteps)
}

@Test(arguments: [1, -1]) func detectorReversesAtLimit(direction: Int) {
    var d = SwipeDetector()
    let sign = Float(direction)
    #expect(frame(&d, 0.5, 0) == nil)
    #expect(frame(&d, 0.5 + sign * 0.11, 0.3) == .step(direction))
    // Further travel at the limit must not prevent a single step back from the turn.
    #expect(frame(&d, 0.5 + sign * 0.30, 0.6) == nil)
    #expect(frame(&d, 0.5 + sign * 0.19, 0.9) == .step(-direction))
    // Net position is zero, but the open HUD still needs its end event.
    #expect(frame(&d, 0, 1.0, fingers: 0) == .end)
    #expect(!d.isTracking)
}

@Test func detectorCanCorrectAndAdvanceAgain() {
    var d = SwipeDetector()
    #expect(frame(&d, 0.20, 0, maxSteps: 3) == nil)
    #expect(frame(&d, 0.31, 0.3, maxSteps: 3) == .step(1))
    #expect(frame(&d, 0.42, 0.6, maxSteps: 3) == .step(1))
    #expect(frame(&d, 0.53, 0.9, maxSteps: 3) == .step(1))
    #expect(frame(&d, 0.64, 1.2, maxSteps: 3) == nil)
    #expect(frame(&d, 0.53, 1.5, maxSteps: 3) == .step(-1))
    #expect(frame(&d, 0.42, 1.8, maxSteps: 3) == .step(-1))
    #expect(frame(&d, 0.53, 2.1, maxSteps: 3) == .step(1))
    #expect(frame(&d, 0.64, 2.4, maxSteps: 3) == .step(1))
    #expect(frame(&d, 0.75, 2.7, maxSteps: 3) == nil)
}

@Test func detectorReversalStillNeedsThresholdAndCooldown() {
    var d = SwipeDetector()
    #expect(frame(&d, 0.30, 0) == nil)
    #expect(frame(&d, 0.41, 0.3) == .step(1))
    #expect(frame(&d, 0.30, 0.4) == nil) // reversed far enough, but still in cooldown
    #expect(frame(&d, 0.30, 0.6) == .step(-1))
    #expect(frame(&d, 0.35, 0.9) == nil) // half a threshold is not a step
}

@Test func detectorPreservesInitialTravelThroughJitter() {
    var d = SwipeDetector()
    #expect(frame(&d, 0.30, 0) == nil)
    #expect(frame(&d, 0.38, 0.1) == nil)
    #expect(frame(&d, 0.37, 0.2) == nil)
    #expect(frame(&d, 0.41, 0.3) == .step(1))
}

@Test func detectorEndsAfterLeftSwipe() {
    var d = SwipeDetector()
    #expect(frame(&d, 0.50, 0) == nil)
    #expect(frame(&d, 0.39, 0.3) == .step(-1))
    #expect(frame(&d, 0, 0.4, fingers: 0) == .end)
}

@Test func detectorSurvivesFingerFlicker() {
    var d = SwipeDetector()
    var fired: [SwipeEvent] = []
    let frames: [(Int, Float)] = [(4, 0.30), (4, 0.36), (3, 0.50), (4, 0.40), (4, 0.47)]
    for (i, (fingers, x)) in frames.enumerated() {
        if let dir = d.update(fingers: fingers, x: x, y: 0.5, time: Double(i) * 0.01,
                              need: 4, threshold: 0.15, maxSteps: 1) { fired.append(dir) }
    }
    // 0.06 before + 0.07 after the flicker; the centroid jump during the flicker is not counted.
    #expect(fired == [])
    #expect(d.update(fingers: 4, x: 0.50, y: 0.5, time: 0.05, need: 4, threshold: 0.15, maxSteps: 1) == .step(1))
    // Lifting all fingers after a step ends the gesture (commits the switch)...
    #expect(d.update(fingers: 0, x: 0, y: 0, time: 0.06, need: 4, threshold: 0.15, maxSteps: 1) == .end)
    #expect(!d.isTracking)
    // ...but a touch without any step ends silently.
    _ = d.update(fingers: 4, x: 0.3, y: 0.5, time: 1, need: 4, threshold: 0.15, maxSteps: 1)
    #expect(d.update(fingers: 0, x: 0, y: 0, time: 1.01, need: 4, threshold: 0.15, maxSteps: 1) == nil)
}

@Test func mruOrder() {
    var m = MRU([1, 2, 3])
    m.activated(3)
    #expect(m.pids == [3, 1, 2])
    m.removed(1)
    #expect(m.pids == [3, 2])
}

@Test func carouselLikeCommandTab() {
    #expect(carouselIndex(from: 0, step: 1, count: 4) == 1)   // right: previous app
    #expect(carouselIndex(from: 0, step: -1, count: 4) == 3)  // left: least recent (wraps)
    #expect(carouselIndex(from: 3, step: 1, count: 4) == 0)   // wraps back to current
    #expect(carouselIndex(from: nil, step: 1, count: 4) == 0) // current app not on this desktop
    #expect(carouselIndex(from: nil, step: -1, count: 4) == 3)
}

@Test func candidatesMatchStepLimit() {
    let apps = [0, 1, 2, 3, 4, 5]
    #expect(gestureCandidates(apps, maxSteps: 1, includesCurrentApp: true) == [0, 1])
    #expect(gestureCandidates(apps, maxSteps: 3, includesCurrentApp: true) == [0, 1, 2, 3])
    #expect(gestureCandidates(apps, maxSteps: .max, includesCurrentApp: true) == apps)
    #expect(gestureCandidates([0, 1], maxSteps: 3, includesCurrentApp: true) == [0, 1])
    #expect(gestureCandidates([Int](), maxSteps: 3, includesCurrentApp: true).isEmpty)
    // Without the current app, the first step already selects the first candidate.
    #expect(gestureCandidates(apps, maxSteps: 1, includesCurrentApp: false) == [0])
    #expect(gestureCandidates(apps, maxSteps: 3, includesCurrentApp: false) == [0, 1, 2])
    #expect(gestureCandidates(apps, maxSteps: .max, includesCurrentApp: false) == apps)
}

@Test func quickGestureNeverFlashesPreview() {
    var actions: [() -> Void] = []
    var shown = 0, hidden = 0
    let preview = PreviewDelay(schedule: { delay, action in
        #expect(delay == 0.15)
        actions.append(action)
    }, show: { shown += 1 }, hide: { hidden += 1 })
    preview.update()
    preview.update()
    #expect(actions.count == 1) // extra steps must not restart the delay
    #expect(shown == 0)
    preview.end()
    actions[0]() // a queued callback can still run after fingers lift
    #expect(shown == 0)
    #expect(hidden == 0)
}

@Test func previewDelayKeepsSessionsSeparate() {
    var actions: [() -> Void] = []
    var shown = 0, hidden = 0
    let preview = PreviewDelay(schedule: { _, action in actions.append(action) },
                               show: { shown += 1 }, hide: { hidden += 1 })
    preview.update()
    preview.end()
    preview.update()
    actions[0]() // the first gesture must not open the second gesture's preview early
    #expect(shown == 0)
    actions[1]()
    #expect(shown == 1)
    preview.update() // after the delay, navigation updates immediately
    #expect(shown == 2)
    preview.end()
    #expect(hidden == 1)
}

@Test func scrollBlockingLastsUntilEveryFingerLifts() {
    var session = GestureScrollSession()
    session.update(contacts: 2, isTracking: false)
    #expect(!session.blocksScroll) // normal two-finger gestures are unaffected
    session.update(contacts: 4, isTracking: true)
    #expect(session.blocksScroll)
    session.update(contacts: 3, isTracking: true)
    #expect(session.blocksScroll)
    session.update(contacts: 2, isTracking: false)
    #expect(session.blocksScroll) // a new scroll/navigation phase in any app must still be dropped
    session.update(contacts: 1, isTracking: false)
    #expect(session.blocksScroll)
    session.update(contacts: 0, isTracking: false)
    #expect(!session.blocksScroll)
    session.update(contacts: 2, isTracking: false)
    #expect(!session.blocksScroll)
}
