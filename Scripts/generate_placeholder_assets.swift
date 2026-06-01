#!/usr/bin/env swift
import AppKit
import Foundation

// Generates simple PLACEHOLDER PNGs into App/Assets.xcassets so the layered-artwork
// pipeline can be seen end-to-end. Replace these with the real layered art using the
// same asset names (see docs/assets-naming.md). Run:  swift Scripts/generate_placeholder_assets.swift

let catalog = FileManager.default.currentDirectoryPath + "/App/Assets.xcassets"

func makePNG(_ draw: (NSSize) -> Void) -> Data {
    let size = NSSize(width: 256, height: 256)
    let image = NSImage(size: size)
    image.lockFocus()
    NSColor.clear.set()
    NSBezierPath.fill(NSRect(origin: .zero, size: size))
    draw(size)
    image.unlockFocus()
    let tiff = image.tiffRepresentation!
    return NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
}

func save(_ data: Data, imageset name: String) {
    let dir = "\(catalog)/\(name).imageset"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let contents = "{\"images\":[{\"filename\":\"\(name).png\",\"idiom\":\"universal\"}],\"info\":{\"author\":\"xcode\",\"version\":1}}"
    try? contents.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
    try? data.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
}

// Base landmass.
save(makePNG { size in
    NSColor(red: 0.55, green: 0.78, blue: 0.5, alpha: 1).setFill()
    let blob = NSBezierPath(roundedRect: NSRect(x: size.width * 0.1, y: size.height * 0.2,
                                                width: size.width * 0.8, height: size.height * 0.55),
                            xRadius: 56, yRadius: 56)
    blob.fill()
    NSColor(red: 0.4, green: 0.62, blue: 0.34, alpha: 1).setStroke()
    blob.lineWidth = 7
    blob.stroke()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 44),
        .foregroundColor: NSColor.white
    ]
    NSAttributedString(string: "CA", attributes: attrs).draw(at: NSPoint(x: size.width * 0.4, y: size.height * 0.42))
}, imageset: "englishUS_california_base")

// Layer 1: a little house.
save(makePNG { size in
    NSColor(red: 0.85, green: 0.5, blue: 0.4, alpha: 1).setFill()
    NSRect(x: size.width * 0.28, y: size.height * 0.34, width: size.width * 0.22, height: size.height * 0.2).fill()
    let roof = NSBezierPath()
    roof.move(to: NSPoint(x: size.width * 0.26, y: size.height * 0.54))
    roof.line(to: NSPoint(x: size.width * 0.52, y: size.height * 0.54))
    roof.line(to: NSPoint(x: size.width * 0.39, y: size.height * 0.66))
    roof.close()
    NSColor(red: 0.6, green: 0.32, blue: 0.26, alpha: 1).setFill()
    roof.fill()
}, imageset: "englishUS_california_l1")

// Layer 2: a tree.
save(makePNG { size in
    NSColor(red: 0.45, green: 0.3, blue: 0.2, alpha: 1).setFill()
    NSRect(x: size.width * 0.63, y: size.height * 0.32, width: size.width * 0.04, height: size.height * 0.14).fill()
    NSColor(red: 0.3, green: 0.55, blue: 0.3, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: size.width * 0.56, y: size.height * 0.42,
                                width: size.width * 0.18, height: size.width * 0.18)).fill()
}, imageset: "englishUS_california_l2")

print("Generated placeholder assets in \(catalog)")
