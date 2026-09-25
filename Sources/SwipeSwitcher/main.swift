import AppKit
import ServiceManagement

// AppDelegate ≈ Android's Application class: receives app lifecycle callbacks.
// `NSObject` + `@objc` are needed because AppKit menus call methods by selector (Objective-C runtime).
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let switcher = AppSwitcher()
    private let defaults = UserDefaults.standard // ≈ SharedPreferences
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
    private let scrollItem = NSMenuItem(title: "Block Scrolling During Gesture (Accessibility)", action: #selector(askScrollPermission), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["fingers": 4, "threshold": 10, "maxSteps": Int.max])
        applySettings()

        statusItem.button?.image = NSImage(systemSymbolName: "hand.draw", accessibilityDescription: "SwipeSwitcher")
        statusItem.menu = makeMenu()

        onSwipe = { [switcher] in switcher.handle($0) }
        startMultitouch()
        // Trackpad callbacks die across sleep; stopping first also means zero work while asleep.
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in stopMultitouch() }
        center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in startMultitouch() }
        resolveGestureConflict()
    }

    /// Asks once (per launch or finger change) to free our swipe from macOS's desktop switching.
    private func resolveGestureConflict() {
        let fingers = defaults.integer(forKey: "fingers")
        guard systemUsesHorizontalSwipe(fingers: fingers) else { return }
        let alert = NSAlert()
        alert.messageText = "macOS already uses the \(fingers)-finger horizontal swipe"
        alert.informativeText = "It switches desktops, so both would happen at once. "
            + "Move desktop switching to \(fingers == 3 ? 4 : 3) fingers (if that is free) so the \(fingers)-finger swipe only switches apps? "
            + "You can change this back anytime in System Settings › Trackpad › More Gestures."
        alert.addButton(withTitle: "Fix Automatically")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        freeHorizontalSwipe(fingers: fingers)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        addChoices(to: menu, title: "Fingers", key: "fingers", [
            ("4 fingers", 4),
            ("3 fingers", 3),
        ])
        addChoices(to: menu, title: "Swipe Distance per Step", key: "threshold", [
            ("Short (10% of trackpad width)", 10), ("Medium (15%)", 15), ("Long (25%)", 25),
        ])
        addChoices(to: menu, title: "Steps per Gesture", key: "maxSteps", [
            ("1 app", 1), ("Up to 3 apps", 3), ("Unlimited", Int.max),
        ])
        menu.addItem(.separator())
        scrollItem.target = self
        menu.addItem(scrollItem)
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit SwipeSwitcher", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private func addChoices(to menu: NSMenu, title: String, key: String, _ choices: [(String, Int)]) {
        menu.addItem(.sectionHeader(title: title))
        for (label, value) in choices {
            let item = NSMenuItem(title: label, action: #selector(choose(_:)), keyEquivalent: "")
            item.target = self
            item.tag = value
            item.representedObject = key
            menu.addItem(item)
        }
    }

    // NSMenuDelegate: refresh checkmarks right before the menu opens (no observers needed).
    func menuNeedsUpdate(_ menu: NSMenu) {
        for item in menu.items {
            guard let key = item.representedObject as? String else { continue }
            item.state = defaults.integer(forKey: key) == item.tag ? .on : .off
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        scrollItem.state = requestScrollBlockingPermission(prompt: false) ? .on : .off
    }

    // Permission is granted (or revoked) in System Settings; the tap is created on the next gesture.
    @objc private func askScrollPermission() {
        if requestScrollBlockingPermission(prompt: true) {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }

    @objc private func choose(_ item: NSMenuItem) {
        guard let key = item.representedObject as? String else { return }
        defaults.set(item.tag, forKey: key)
        applySettings()
        if key == "fingers" { resolveGestureConflict() }
    }

    private func applySettings() {
        fingerSetting.store(defaults.integer(forKey: "fingers"), ordering: .relaxed)
        thresholdPercent.store(defaults.integer(forKey: "threshold"), ordering: .relaxed)
        maxStepsSetting.store(defaults.integer(forKey: "maxSteps"), ordering: .relaxed)
    }

    // SMAppService (macOS 13+) registers the app bundle itself as a login item — no helper app.
    // Only works when running from a real .app bundle (./build.sh), not from `swift run`.
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSApp.activate() // a menu bar app has no window; come forward so the alert is visible
            NSAlert(error: error).runModal()
        }
    }
}

// Entry point (≈ `void main() => runApp(...)`). `.accessory` = no Dock icon, same as
// LSUIElement in Info.plist; set here too so `swift run` behaves like the bundled app.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
