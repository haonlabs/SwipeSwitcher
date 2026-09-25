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
