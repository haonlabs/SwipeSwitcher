import AppKit

/// The ⌘-Tab-style preview: a floating panel with one icon per app, the selection highlighted.
/// Built once and reused; hidden (orderOut) between gestures, so it costs nothing while idle.
///
/// The panel covers the whole screen with an almost-invisible layer: scroll/click events go to
/// the window under the pointer, so while the preview is open they land here (and are dropped)
/// instead of scrolling the app behind it. No event tap, so no Accessibility permission.
final class SwitcherHUD {
    private static let iconSize: CGFloat = 64
    private static let cellSize: CGFloat = 84

    // NSPanel = a window that never becomes the "main" window; `.nonactivatingPanel` means showing
    // it doesn't steal focus from the app you're in.
    private let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: true)
    private let icons = NSStackView()
    private let name = NSTextField(labelWithString: "")
    private var shown: [NSRunningApplication] = []

    init() {
        panel.level = .popUpMenu
        panel.isOpaque = false
        // Alpha 0 would let events fall through; 0.001 is invisible but still catches them.
        panel.backgroundColor = NSColor(white: 0, alpha: 0.001)
        panel.hasShadow = false
        // Appear on whichever desktop is active, including over full-screen apps.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        // The system HUD blur material, same family as ⌘-Tab.
        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 20

        icons.spacing = 4
        name.font = .systemFont(ofSize: 13, weight: .medium)
        name.alignment = .center
        name.lineBreakMode = .byTruncatingTail // long names must not widen the panel
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let column = NSStackView(views: [icons, name]) // ≈ Flutter Column
        column.orientation = .vertical
        column.spacing = 6
        column.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 12, right: 14)
        column.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(column)
        background.translatesAutoresizingMaskIntoConstraints = false
        let screenLayer = NSView() // full-screen, event-catching; the HUD box sits in its center
        screenLayer.addSubview(background)
        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            column.topAnchor.constraint(equalTo: background.topAnchor),
            column.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            background.centerXAnchor.constraint(equalTo: screenLayer.centerXAnchor),
            background.centerYAnchor.constraint(equalTo: screenLayer.centerYAnchor),
        ])
        panel.contentView = screenLayer
    }

    func show(_ apps: [NSRunningApplication], selected: Int) {
        if apps != shown { rebuild(apps) }
        for (i, cell) in icons.arrangedSubviews.enumerated() {
            cell.layer?.backgroundColor = i == selected ? NSColor.white.withAlphaComponent(0.22).cgColor : nil
        }
        name.stringValue = apps[selected].localizedName ?? ""
        if !panel.isVisible {
            // Cover the screen under the pointer (where the user is looking and scrolling).
            let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            if let frame = screen?.frame { panel.setFrame(frame, display: false) }
            panel.orderFrontRegardless() // show without activating our app
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func rebuild(_ apps: [NSRunningApplication]) {
        shown = apps
        icons.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for app in apps {
            let image = (app.icon?.copy() as? NSImage) ?? NSImage()
            image.size = NSSize(width: Self.iconSize, height: Self.iconSize)
            let cell = NSImageView(image: image)
            cell.imageScaling = .scaleNone // icon keeps 64pt, the extra space is the highlight margin
            cell.wantsLayer = true
            cell.layer?.cornerRadius = 14
            cell.widthAnchor.constraint(equalToConstant: Self.cellSize).isActive = true
            cell.heightAnchor.constraint(equalToConstant: Self.cellSize).isActive = true
            icons.addArrangedSubview(cell)
        }
    }
}
