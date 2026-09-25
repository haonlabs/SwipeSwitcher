// Renders AppIcon.icns: `swift scripts/render-icon.swift` (run from the project root).
// Draws the icon in code (macOS icon grid: 824pt rounded square on a 1024pt canvas),
// writes every size into an .iconset folder, then `iconutil` packs it into one .icns.
import AppKit

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(pixels) / 1024 // design in 1024-unit space

    // Background: rounded square with a blue → indigo gradient and a soft drop shadow.
    let square = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: square, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10 * s)
    shadow.shadowBlurRadius = 20 * s
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: NSColor(red: 0.30, green: 0.62, blue: 1.00, alpha: 1),
               ending: NSColor(red: 0.33, green: 0.24, blue: 0.86, alpha: 1))!
        .draw(in: shape, angle: -90)

    // Foreground: white SF Symbol of a hand swiping.
    let config = NSImage.SymbolConfiguration(pointSize: 480 * s, weight: .regular)
        .applying(.init(paletteColors: [.white]))
    let symbol = NSImage(systemSymbolName: "hand.draw.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    let size = symbol.size
    symbol.draw(in: NSRect(x: (CGFloat(pixels) - size.width) / 2, y: (CGFloat(pixels) - size.height) / 2,
                           width: size.width, height: size.height))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
let iconutil = try Process.run(URL(fileURLWithPath: "/usr/bin/iconutil"), arguments: ["-c", "icns", iconset.path, "-o", "AppIcon.icns"])
iconutil.waitUntilExit()
try FileManager.default.removeItem(at: iconset)
print(iconutil.terminationStatus == 0 ? "Wrote AppIcon.icns" : "iconutil failed")
