// Renders the DMG window background (660×400 pt, @1x + @2x in one TIFF):
//   swift scripts/render-dmg-background.swift <output.tiff>
// Layout matches scripts/make-dmg.sh: app icon centered at (165, 185), Applications at (495, 185),
// measured from the top-left of the window.
import AppKit

let width: CGFloat = 660, height: CGFloat = 400
let blue = NSColor(red: 0.30, green: 0.62, blue: 1.00, alpha: 1)   // same as the app icon
let indigo = NSColor(red: 0.33, green: 0.24, blue: 0.86, alpha: 1)

func text(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerY fromTop: CGFloat) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributed = NSAttributedString(string: string, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: paragraph,
    ])
    let h = attributed.size().height
    attributed.draw(in: NSRect(x: 0, y: height - fromTop - h / 2, width: width, height: h))
}

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height) // points; pixel count carries the scale
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Soft light background (Finder draws icon labels in dark text on top of it).
    NSGradient(starting: NSColor(red: 0.97, green: 0.98, blue: 0.99, alpha: 1),
               ending: NSColor(red: 0.91, green: 0.93, blue: 0.97, alpha: 1))!
        .draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: -90)

    text("SwipeSwitcher", size: 22, weight: .semibold, color: NSColor(white: 0.12, alpha: 1), centerY: 44)
    text("Drag the app onto Applications to install", size: 13, weight: .regular,
         color: NSColor(white: 0.40, alpha: 1), centerY: 72)

    // Arrow between the two icons, in the app icon's gradient.
    let y = height - 185
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 410, y: y))
    head.line(to: NSPoint(x: 384, y: y + 20))
    head.line(to: NSPoint(x: 384, y: y - 20))
    head.close()
    // Shaft and head as one filled shape so they share a single gradient.
    let shape = NSBezierPath(roundedRect: NSRect(x: 251, y: y - 4, width: 140, height: 8), xRadius: 4, yRadius: 4)
    shape.append(head)
    NSGradient(starting: blue, ending: indigo)!.draw(in: shape, angle: 0)

    text("First launch: System Settings › Privacy & Security › Open Anyway", size: 11, weight: .regular,
         color: NSColor(white: 0.50, alpha: 1), centerY: height - 28)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let output = CommandLine.arguments.dropFirst().first ?? "background.tiff"
let image = NSImage(size: NSSize(width: width, height: height))
image.addRepresentation(render(scale: 1))
image.addRepresentation(render(scale: 2)) // Retina
try image.tiffRepresentation(using: .lzw, factor: 1)!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
