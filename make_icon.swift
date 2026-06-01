#!/usr/bin/swift
// Generates AppIcon.icns from AppNameIcon.webp — run once: swift make_icon.swift
import AppKit

guard let sourceImage = NSImage(contentsOfFile: "AppNameIcon.webp") else {
    print("✗ Could not load AppNameIcon.webp")
    exit(1)
}

func resized(_ image: NSImage, to size: Int) -> Data? {
    let s = CGFloat(size)
    let dest = NSImage(size: NSSize(width: s, height: s))
    dest.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: s, height: s),
               from: .zero, operation: .copy, fraction: 1)
    dest.unlockFocus()
    guard let tiff = dest.tiffRepresentation,
          let bmp  = NSBitmapImageRep(data: tiff)
    else { return nil }
    return bmp.representation(using: .png, properties: [:])
}

let entries: [(name: String, logical: Int, scale: Int)] = [
    ("icon_16x16",      16,  1),
    ("icon_16x16@2x",   16,  2),
    ("icon_32x32",      32,  1),
    ("icon_32x32@2x",   32,  2),
    ("icon_128x128",    128, 1),
    ("icon_128x128@2x", 128, 2),
    ("icon_256x256",    256, 1),
    ("icon_256x256@2x", 256, 2),
    ("icon_512x512",    512, 1),
    ("icon_512x512@2x", 512, 2),
]

let iconset = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

for e in entries {
    if let data = resized(sourceImage, to: e.logical * e.scale) {
        try? data.write(to: URL(fileURLWithPath: "\(iconset)/\(e.name).png"))
        print("  \(e.name).png")
    }
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset]
try? p.run()
p.waitUntilExit()

if FileManager.default.fileExists(atPath: "AppIcon.icns") {
    try? FileManager.default.removeItem(atPath: iconset)
    print("✓ AppIcon.icns")
} else {
    print("✗ iconutil failed")
}
