#!/usr/bin/swift
import Cocoa

let iconDir = "/Users/nicholasamaral/Developer/voicedrop/voicedrop/Assets.xcassets/AppIcon.appiconset"

let outputFiles: [(String, Int)] = [
    ("icon_16x16.png", 16),    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

func renderIcon(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bitmapFormat: [], bytesPerRow: 0, bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!

    // Clear
    NSColor.clear.setFill()
    NSBezierPath.fill(NSRect(x: 0, y: 0, width: s, height: s))

    // Clip to macOS rounded-square icon shape
    NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
        xRadius: s * 0.225, yRadius: s * 0.225
    ).setClip()

    // Background: diagonal gradient deep-indigo → vivid violet
    NSGradient(
        colors: [
            NSColor(srgbRed: 0.06, green: 0.04, blue: 0.22, alpha: 1), // #0F0A38
            NSColor(srgbRed: 0.38, green: 0.14, blue: 0.76, alpha: 1), // #6124C2
            NSColor(srgbRed: 0.68, green: 0.20, blue: 0.94, alpha: 1), // #AD33F0
        ],
        atLocations: [0, 0.5, 1.0],
        colorSpace: .sRGB
    )!.draw(in: NSRect(x: 0, y: 0, width: s, height: s), angle: 135)

    // Mic proportions (y=0 is bottom in AppKit)
    let micW         = s * 0.28
    let micH         = s * 0.30
    let micX         = (s - micW) / 2
    let micBottom    = s * 0.50
    let micCenterY   = micBottom + micH / 2   // ~65% up

    let lw = max(s * 0.042, 1.0)             // stroke width, min 1px

    // Sound waves — drawn first so they sit behind the mic body
    for i in 1 ... 2 {
        let dist  = micW / 2 + s * CGFloat(i) * 0.092
        let alpha = 0.72 - Double(i - 1) * 0.28
        let wlw   = lw * max(1.0 - CGFloat(i - 1) * 0.22, 0.6)

        for sideBase: CGFloat in [0, 180] {      // 0° = right, 180° = left
            let wave = NSBezierPath()
            wave.lineWidth = wlw
            wave.lineCapStyle = .round
            wave.appendArc(
                withCenter: NSPoint(x: s / 2, y: micCenterY),
                radius: dist,
                startAngle: sideBase - 40,
                endAngle:   sideBase + 40,
                clockwise: false
            )
            NSColor.white.withAlphaComponent(alpha).setStroke()
            wave.stroke()
        }
    }

    // Mic body (white capsule) with drop shadow
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset     = NSSize(width: 0, height: -lw * 0.5)
    shadow.shadowBlurRadius = lw * 1.5
    shadow.shadowColor      = NSColor.black.withAlphaComponent(0.40)
    shadow.set()
    NSColor.white.setFill()
    NSBezierPath(
        roundedRect: NSRect(x: micX, y: micBottom, width: micW, height: micH),
        xRadius: micW / 2, yRadius: micW / 2
    ).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Subtle top-highlight on mic body
    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(
        roundedRect: NSRect(x: micX, y: micBottom, width: micW, height: micH),
        xRadius: micW / 2, yRadius: micW / 2
    ).setClip()
    NSGradient(
        colors: [
            NSColor.white.withAlphaComponent(0.28),
            NSColor.white.withAlphaComponent(0.00),
        ],
        atLocations: [0, 1.0],
        colorSpace: .sRGB
    )!.draw(
        in: NSRect(x: micX, y: micCenterY, width: micW, height: micH / 2),
        angle: 90
    )
    NSGraphicsContext.restoreGraphicsState()

    // Stand: U-arc + vertical stem + horizontal base
    NSColor.white.setStroke()

    let arcRadius = micW * 0.70
    let arc = NSBezierPath()
    arc.lineWidth    = lw
    arc.lineCapStyle = .round
    // clockwise from 0° (east) to 180° (west) → U-shape going through south
    arc.appendArc(
        withCenter: NSPoint(x: s / 2, y: micBottom),
        radius: arcRadius,
        startAngle: 0, endAngle: 180,
        clockwise: true
    )
    arc.stroke()

    let stemTopY    = micBottom - arcRadius
    let stemBottomY = stemTopY  - s * 0.065

    let stem = NSBezierPath()
    stem.lineWidth    = lw
    stem.lineCapStyle = .round
    stem.move(to: NSPoint(x: s / 2, y: stemTopY))
    stem.line(to: NSPoint(x: s / 2, y: stemBottomY))
    stem.stroke()

    let halfBase = micW * 0.42
    let base = NSBezierPath()
    base.lineWidth    = lw
    base.lineCapStyle = .round
    base.move(to: NSPoint(x: s / 2 - halfBase, y: stemBottomY))
    base.line(to: NSPoint(x: s / 2 + halfBase, y: stemBottomY))
    base.stroke()

    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

for (filename, size) in outputFiles {
    let data = renderIcon(size: size)
    let path = "\(iconDir)/\(filename)"
    do {
        try data.write(to: URL(fileURLWithPath: path))
        print("✓  \(filename)  (\(size)px)")
    } catch {
        print("✗  \(filename): \(error)")
    }
}
print("Done.")
