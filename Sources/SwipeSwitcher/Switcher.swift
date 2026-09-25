import AppKit

/// Most-recently-used app list, pure logic (testable). `pid_t` = process id, the stable handle
/// for a running app during its lifetime.
struct MRU {
    private(set) var pids: [pid_t] // most recent first

    init(_ pids: [pid_t]) { self.pids = pids }

    /// An app became frontmost (click, ⌘-Tab, Dock, or our own switch).
    mutating func activated(_ pid: pid_t) {
        pids.removeAll { $0 == pid }
        pids.insert(pid, at: 0)
    }

    mutating func removed(_ pid: pid_t) {
        pids.removeAll { $0 == pid }
    }
}

/// Where the selection lands after one step, like ⌘-Tab: index 0 is the current app, so the
/// first right step picks the previously used app. `nil` = nothing selected yet.
func carouselIndex(from index: Int?, step: Int, count: Int) -> Int {
    guard let index else { return step > 0 ? 0 : count - 1 }
    return (index + step + count) % count
}

/// Glue between `MRU` and the system. Everything here runs on the main thread.
final class AppSwitcher {
    private var mru: MRU

    init() {
        mru = MRU(Self.initialOrder())
        // NSWorkspace's NotificationCenter ≈ an Android BroadcastReceiver for app lifecycle events.
        // Event-driven: costs nothing while no app changes.
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = Self.app(from: note), app.activationPolicy == .regular else { return }
            self?.mru.activated(app.processIdentifier)
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = Self.app(from: note) else { return }
            self?.mru.removed(app.processIdentifier)
        }
        center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            lastSpaceChange = ProcessInfo.processInfo.systemUptime
            if !candidates.isEmpty { scheduleRefresh() } // desktop changed under an open preview
        }
    }

    // One gesture = one session (≈ holding ⌘ during ⌘-Tab): steps move the selection in the
    // preview, lifting the fingers switches.
    private var candidates: [NSRunningApplication] = []
    private var selected: Int?
    private lazy var hud = SwitcherHUD() // `lazy`: built on first use, then reused

    // While the desktop-switch animation runs, windows of BOTH desktops count as on screen.
    // ponytail: fixed settle time; tune if the animation is slower (e.g. Reduce Motion off + slow Mac).
    private static let spaceSettle = 0.6
    private var lastSpaceChange = -Double.infinity

    func handle(_ event: SwipeEvent) {
        switch event {
        case .step(let direction):
            if candidates.isEmpty && !beginSession() { return }
            selected = carouselIndex(from: selected, step: direction, count: candidates.count)
            hud.show(candidates, selected: selected!)
        case .end:
            hud.hide()
            // `.end` can arrive without a session (e.g. only one app on this desktop), so check the index.
            if let selected, candidates.indices.contains(selected),
               candidates[selected] != NSWorkspace.shared.frontmostApplication {
                activate(candidates[selected])
            }
            candidates = []
            selected = nil
        }
    }

    /// Snapshot of switchable apps: those with a window on this desktop, most recent first.
    private func beginSession() -> Bool {
        candidates = switchableApps()
        if ProcessInfo.processInfo.systemUptime - lastSpaceChange < Self.spaceSettle { scheduleRefresh() }
        let front = NSWorkspace.shared.frontmostApplication
        selected = candidates.first == front ? 0 : nil
        // A single app is still shown (confirms the gesture was read); lifting then does nothing.
        if candidates.isEmpty { selected = nil }
        return !candidates.isEmpty
    }

    private func switchableApps() -> [NSRunningApplication] {
        let here = Self.appsOnCurrentDesktop() // one window-list query
        return mru.pids.filter(here.contains).compactMap { NSRunningApplication(processIdentifier: $0) }
    }

    /// Re-reads the list once the desktop switch has settled, keeping the selected app selected.
    private func scheduleRefresh() {
        let delay = lastSpaceChange + Self.spaceSettle - ProcessInfo.processInfo.systemUptime
        DispatchQueue.main.asyncAfter(deadline: .now() + max(delay, 0)) { [weak self] in
            guard let self, let selected, candidates.indices.contains(selected) else { return } // gesture over
            let fresh = switchableApps()
            guard !fresh.isEmpty else { return }
            let kept = candidates[selected]
            candidates = fresh
            self.selected = fresh.firstIndex(of: kept) ?? 0
            hud.show(candidates, selected: self.selected!)
        }
    }

    private func activate(_ app: NSRunningApplication) {
        // No .activateAllWindows: that could pull in (or jump to) the app's windows on other desktops.
        // macOS 14+ may refuse activation requested by a background app; opening the bundle
        // (like a Dock click) always brings it forward.
        if !app.activate(), let url = app.bundleURL {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    /// Apps with a normal window visible on the current desktop. `.optionOnScreenOnly` excludes
    /// other Spaces and minimized windows, so no private Spaces API is needed.
    /// ponytail: size filter skips invisible helper windows; tune if some app is wrongly skipped.
    private static func appsOnCurrentDesktop() -> Set<pid_t> {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[CFString: Any]] ?? []
        var pids = Set<pid_t>()
        for window in list {
            guard (window[kCGWindowLayer] as? Int) == 0,
                  let pid = window[kCGWindowOwnerPID] as? pid_t,
                  let bounds = window[kCGWindowBounds] as? [String: CGFloat],
                  (bounds["Width"] ?? 0) >= 100, (bounds["Height"] ?? 0) >= 100
            else { continue }
            pids.insert(pid)
        }
        return pids
    }

    private static func app(from note: Notification) -> NSRunningApplication? {
        note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }

    /// Best guess of recency at launch: frontmost app, then apps by on-screen window order
    /// (front to back), then the rest. Runs once; needs no Screen Recording permission.
    private static func initialOrder() -> [pid_t] {
        let regular = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map(\.processIdentifier)
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[CFString: Any]] ?? []
        let byWindow = windows.compactMap { ($0[kCGWindowLayer] as? Int) == 0 ? $0[kCGWindowOwnerPID] as? pid_t : nil }
        let front = NSWorkspace.shared.frontmostApplication.map { [$0.processIdentifier] } ?? []
        var seen = Set<pid_t>()
        return (front + byWindow + regular).filter { regular.contains($0) && seen.insert($0).inserted }
    }
}
