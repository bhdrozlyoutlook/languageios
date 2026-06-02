#!/usr/bin/env swift
import AppKit
import Foundation

// Generates the 1024×1024 app icon into App/Assets.xcassets/AppIcon.appiconset.
// Draws straight into a 1024px bitmap (not NSImage) so the output is exactly 1024×1024
// regardless of the Mac's display scale. Run:  swift Scripts/generate_app_icon.swift

let px = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let size = NSSize(width: px, height: px)

// Teal gradient background (icons must be fully opaque).
NSGradient(colors: [
    NSColor(red: 0.30, green: 0.62, blue: 0.62, alpha: 1),
    NSColor(red: 0.52, green: 0.74, blue: 0.74, alpha: 1)
])?.draw(in: NSRect(origin: .zero, size: size), angle: -90)

// Cream speech bubble.
let cream = NSColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
let bubble = NSRect(x: 200, y: 300, width: 624, height: 460)
cream.setFill()
NSBezierPath(roundedRect: bubble, xRadius: 96, yRadius: 96).fill()

let tail = NSBezierPath()
tail.move(to: NSPoint(x: 360, y: 320))
tail.line(to: NSPoint(x: 300, y: 190))
tail.line(to: NSPoint(x: 470, y: 320))
tail.close()
cream.setFill()
tail.fill()

// "Aa" wordmark.
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 300, weight: .black),
    .foregroundColor: NSColor(red: 0.05, green: 0.05, blue: 0.04, alpha: 1)
]
let wordmark = NSAttributedString(string: "Aa", attributes: attrs)
let textSize = wordmark.size()
wordmark.draw(at: NSPoint(x: bubble.midX - textSize.width / 2, y: bubble.midY - textSize.height / 2 + 8))

// Coral accent dot.
NSColor(red: 1.0, green: 0.48, blue: 0.42, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 690, y: 650, width: 78, height: 78)).fill()

NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
let dir = FileManager.default.currentDirectoryPath + "/App/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
try! png.write(to: URL(fileURLWithPath: "\(dir)/icon-1024.png"))
print("App icon generated (\(px)×\(px))")
