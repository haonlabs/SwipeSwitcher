import Foundation

/// Quick gestures commit without flashing the HUD. A delayed callback belongs to exactly one
/// session, so ending a gesture also prevents its preview from appearing over the next app.
final class PreviewDelay {
    static let delay = 0.15

    private let schedule: (Double, @escaping () -> Void) -> Void
    private let show: () -> Void
    private let hide: () -> Void
    private var session: UUID?
    private var visible = false

    init(schedule: @escaping (Double, @escaping () -> Void) -> Void = { delay, action in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }, show: @escaping () -> Void, hide: @escaping () -> Void) {
        self.schedule = schedule
        self.show = show
        self.hide = hide
    }

    func update() {
        if visible { show(); return }
        guard session == nil else { return } // further steps do not postpone the preview
        let id = UUID()
        session = id
        schedule(Self.delay) { [weak self] in
            guard let self, session == id else { return }
            visible = true
            show()
        }
    }

    func end() {
        session = nil
        if visible { hide() }
        visible = false
    }
}
