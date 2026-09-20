// Rebuild with: swift scripts/generate-icon.swift
// Native vector drawing keeps every icon resolution sharp and reproducible.
import AppKit

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
func rounded(_ rect: NSRect, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}
func gradient(_ path: NSBezierPath, _ top: NSColor, _ bottom: NSColor) {
    NSGradient(starting: bottom, ending: top)!.draw(in: path, angle: 90)
}
func drawIcon() {
    let tile = rounded(NSRect(x: 60, y: 60, width: 904, height: 904), 204)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0.08, 0.19, 0.27, 0.22)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    gradient(tile, color(0.98, 0.995, 1), color(0.79, 0.88, 0.93))
    NSGraphicsContext.restoreGraphicsState()
    color(1, 1, 1, 0.85).setStroke()
    tile.lineWidth = 3
    tile.stroke()

    // Folder back and tab: the same cyan palette as the in-app folder glyph.
    let back = rounded(NSRect(x: 183, y: 251, width: 658, height: 470), 52)
    gradient(rounded(NSRect(x: 183, y: 652, width: 272, height: 127), 38), color(0.53, 0.82, 0.95), color(0.27, 0.63, 0.81))
    gradient(back, color(0.45, 0.78, 0.93), color(0.23, 0.58, 0.78))

    // Three familiar document cards gathering into the folder.
    for (x, y, angle, tint) in [
        (275.0, 466.0, 9.0, color(0.94, 0.36, 0.38)),
        (408.0, 486.0, -2.0, color(0.36, 0.51, 0.87)),
        (537.0, 458.0, -12.0, color(0.27, 0.64, 0.51))
    ] {
        NSGraphicsContext.saveGraphicsState()
        let transform = AffineTransform(translationByX: x, byY: y)
        var rotation = transform
        rotation.rotate(byDegrees: angle)
        (rotation as NSAffineTransform).concat()
        let paper = rounded(NSRect(x: 0, y: 0, width: 183, height: 296), 22)
        NSGraphicsContext.saveGraphicsState()
        let paperShadow = NSShadow()
        paperShadow.shadowColor = color(0.08, 0.23, 0.34, 0.20)
        paperShadow.shadowBlurRadius = 14
        paperShadow.shadowOffset = NSSize(width: 0, height: -7)
        paperShadow.set()
        NSColor.white.setFill(); paper.fill()
        NSGraphicsContext.restoreGraphicsState()
        tint.setFill()
        rounded(NSRect(x: 23, y: 248, width: 137, height: 15), 6).fill()
        tint.withAlphaComponent(0.25).setFill()
        for line in 0..<3 {
            NSBezierPath(rect: NSRect(x: 26, y: 160 - line * 22, width: 131, height: 7)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    let front = rounded(NSRect(x: 165, y: 235, width: 694, height: 369), 56)
    NSGraphicsContext.saveGraphicsState()
    let folderShadow = NSShadow()
    folderShadow.shadowColor = color(0.08, 0.29, 0.42, 0.25)
    folderShadow.shadowBlurRadius = 28
    folderShadow.shadowOffset = NSSize(width: 0, height: -18)
    folderShadow.set()
    gradient(front, color(0.57, 0.85, 0.97), color(0.22, 0.62, 0.82))
    NSGraphicsContext.restoreGraphicsState()
    color(1, 1, 1, 0.5).setStroke()
    front.lineWidth = 3
    front.stroke()
    // Restrained lower reflection gives the folder its glass finish.
    gradient(rounded(NSRect(x: 196, y: 258, width: 632, height: 12), 6), color(1, 1, 1, 0.03), color(1, 1, 1, 0.17))
}

let output = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        drawIcon()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
