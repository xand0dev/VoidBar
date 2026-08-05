#!/usr/bin/env swift
// Renders Resources/AppIcon.icns from code — no design tool in the loop.
// Usage: swift Scripts/make-icon.swift <output.icns>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("VoidBar.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func draw(size s: CGFloat) -> NSBitmapImageRep {
    let px = Int(s)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let k = s / 1024  // everything below is authored on a 1024 canvas

    // Rounded-square body, macOS proportions.
    let body = CGRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185 * k, cornerHeight: 185 * k, transform: nil)
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            CGColor(red: 0.27, green: 0.27, blue: 0.30, alpha: 1),
            CGColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: body.midX, y: body.maxY),
        end: CGPoint(x: body.midX, y: body.minY),
        options: []
    )

    // The notch itself, cut into the top edge.
    let notchW = 330 * k, notchH = 86 * k, r = 34 * k
    let nx = body.midX - notchW / 2, ny = body.maxY - notchH
    let notch = CGMutablePath()
    notch.move(to: CGPoint(x: nx, y: body.maxY))
    notch.addLine(to: CGPoint(x: nx, y: ny + r))
    notch.addQuadCurve(to: CGPoint(x: nx + r, y: ny), control: CGPoint(x: nx, y: ny))
    notch.addLine(to: CGPoint(x: nx + notchW - r, y: ny))
    notch.addQuadCurve(to: CGPoint(x: nx + notchW, y: ny + r), control: CGPoint(x: nx + notchW, y: ny))
    notch.addLine(to: CGPoint(x: nx + notchW, y: body.maxY))
    notch.closeSubpath()
    ctx.addPath(notch)
    ctx.setFillColor(CGColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1))
    ctx.fillPath()

    // Eye
    let cx = body.midX, cy = body.midY - 40 * k
    let ew = 460 * k, eh = 250 * k
    let lens = CGMutablePath()
    lens.move(to: CGPoint(x: cx - ew / 2, y: cy))
    lens.addQuadCurve(to: CGPoint(x: cx + ew / 2, y: cy), control: CGPoint(x: cx, y: cy + eh))
    lens.addQuadCurve(to: CGPoint(x: cx - ew / 2, y: cy), control: CGPoint(x: cx, y: cy - eh))
    lens.closeSubpath()
    ctx.addPath(lens)
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.95))
    ctx.fillPath()

    ctx.addPath(lens)
    ctx.clip()
    ctx.setFillColor(CGColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1))
    ctx.fillEllipse(in: CGRect(x: cx - 78 * k, y: cy - 78 * k, width: 156 * k, height: 156 * k))
    ctx.setFillColor(CGColor(gray: 1, alpha: 0.9))
    ctx.fillEllipse(in: CGRect(x: cx + 12 * k, y: cy + 26 * k, width: 40 * k, height: 40 * k))
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for (size, name) in [
    (16, "icon_16x16"), (32, "icon_16x16@2x"), (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"), (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x")
] {
    let data = draw(size: CGFloat(size)).representation(using: .png, properties: [:])!
    try data.write(to: iconset.appendingPathComponent("\(name).png"))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", outPath]
try task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "wrote \(outPath)" : "iconutil failed")
