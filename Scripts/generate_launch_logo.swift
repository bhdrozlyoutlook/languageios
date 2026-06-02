#!/usr/bin/env swift
import AppKit
import Foundation

// Generates LaunchLogo (a rounded icon tile matching AppIcon) at 1x/2x/3x into
// App/Assets.xcassets/LaunchLogo.imageset, used by the OS launch screen and mirrored by
// the SwiftUI SplashView. Run:  swift Scripts/generate_launch_logo.swift

func drawTile(px: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(px) / 1024.0                       // scale from the 1024 reference
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
        NSRect(x: x * s, y: y * s, width: w * s, height: h * s)
    }

    // Rounded teal tile (transparent outside the corners).
    let tile = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: CGFloat(px), height: CGFloat(px)),
                            xRadius: 230 * s, yRadius: 230 * s)
    tile.addClip()
    NSGradient(colors: [
        NSColor(red: 0.30, green: 0.62, blue: 0.62, alpha: 1),
        NSColor(red: 0.52, green: 0.74, blue: 0.74, alpha: 1),
    ])?.draw(in: NSRect(x: 0, y: 0, width: CGFloat(px), height: CGFloat(px)), angle: -90)

    // Cream speech bubble + tail.
    let cream = NSColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
    cream.setFill()
    NSBezierPath(roundedRect: R(200, 300, 624, 460), xRadius: 96 * s, yRadius: 96 * s).fill()
    let tail = NSBezierPath()
    tail.move(to: NSPoint(x: 360 * s, y: 320 * s))
    tail.line(to: NSPoint(x: 300 * s, y: 190 * s))
    tail.line(to: NSPoint(x: 470 * s, y: 320 * s))
    tail.close()
    tail.fill()

    // "Aa" wordmark.
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 300 * s, weight: .black),
        .foregroundColor: NSColor(red: 0.05, green: 0.05, blue: 0.04, alpha: 1),
    ]
    let mark = NSAttributedString(string: "Aa", attributes: attrs)
    let ts = mark.size()
    let bubble = R(200, 300, 624, 460)
    mark.draw(at: NSPoint(x: bubble.midX - ts.width / 2, y: bubble.midY - ts.height / 2 + 8 * s))

    // Coral accent dot.
    NSColor(red: 1.0, green: 0.48, blue: 0.42, alpha: 1).setFill()
    NSBezierPath(ovalIn: R(690, 650, 78, 78)).fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = FileManager.default.currentDirectoryPath + "/App/Assets.xcassets/LaunchLogo.imageset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

// Point size 180 → 1x=180, 2x=360, 3x=540.
for (scale, px) in [(1, 180), (2, 360), (3, 540)] {
    try! drawTile(px: px).write(to: URL(fileURLWithPath: "\(dir)/launch-logo@\(scale)x.png"))
}

let contents = """
{
  "images" : [
    { "idiom" : "universal", "filename" : "launch-logo@1x.png", "scale" : "1x" },
    { "idiom" : "universal", "filename" : "launch-logo@2x.png", "scale" : "2x" },
    { "idiom" : "universal", "filename" : "launch-logo@3x.png", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try! contents.write(to: URL(fileURLWithPath: "\(dir)/Contents.json"), atomically: true, encoding: .utf8)
print("LaunchLogo generated (180pt @1x/2x/3x)")
