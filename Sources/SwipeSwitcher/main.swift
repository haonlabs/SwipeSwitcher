import AppKit
import ServiceManagement

// AppDelegate ≈ Android's Application class: receives app lifecycle callbacks.
// `NSObject` + `@objc` are needed because AppKit menus call methods by selector (Objective-C runtime).
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let switcher = AppSwitcher()
    private let defaults = UserDefaults.standard // ≈ SharedPreferences
    private let loginItem = NSMenuItem(title: "Buka saat login", action: #selector(toggleLogin), keyEquivalent: "")
    private let scrollItem = NSMenuItem(title: "Tahan scroll saat gesture (izin Accessibility)", action: #selector(askScrollPermission), keyEquivalent: "")

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
        alert.messageText = "Swipe \(fingers) jari kiri/kanan masih dipakai macOS"
        alert.informativeText = "Saat ini macOS memakainya untuk ganti desktop, jadi keduanya akan jalan bersamaan. "
            + "Pindahkan ganti desktop ke \(fingers == 3 ? 4 : 3) jari (kalau masih kosong) supaya swipe \(fingers) jari khusus untuk pindah app? "
            + "Bisa dikembalikan kapan saja di System Settings › Trackpad › More Gestures."
        alert.addButton(withTitle: "Atur otomatis")
        alert.addButton(withTitle: "Nanti")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        freeHorizontalSwipe(fingers: fingers)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        addChoices(to: menu, title: "Jumlah jari", key: "fingers", [
            ("4 jari", 4),
            ("3 jari", 3),
        ])
        addChoices(to: menu, title: "Threshold", key: "threshold", [
            ("Pendek (10% lebar trackpad)", 10), ("Sedang (15%)", 15), ("Panjang (25%)", 25),
        ])
        addChoices(to: menu, title: "Langkah per gesture", key: "maxSteps", [
            ("1 app", 1), ("Sampai 3 app", 3), ("Tanpa batas", Int.max),
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
