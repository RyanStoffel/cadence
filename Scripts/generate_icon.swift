import AppKit
import Foundation

let output = CommandLine.arguments.dropFirst().first ?? "Cadence-1024.png"
let size = 1_024

guard
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
  ), let context = NSGraphicsContext(bitmapImageRep: bitmap)
else {
  fatalError("Could not create icon canvas")
}

bitmap.size = NSSize(width: size, height: size)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

let bounds = NSRect(x: 0, y: 0, width: size, height: size)
NSColor.clear.setFill()
bounds.fill()

// Flat rounded-square background in warm amber/gold, no gradients.
let tileRect = bounds.insetBy(dx: 42, dy: 42)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 220, yRadius: 220)
NSColor(red: 0.851, green: 0.635, blue: 0.290, alpha: 1).setFill()
tile.fill()

let border = NSBezierPath(roundedRect: tileRect.insetBy(dx: 3, dy: 3), xRadius: 217, yRadius: 217)
NSColor.white.withAlphaComponent(0.08).setStroke()
border.lineWidth = 6
border.stroke()

// Simple three-bar rhythm / pulse mark, centered, near-white glyph.
let barWidth: CGFloat = 108
let barSpacing: CGFloat = 64
let barCornerRadius: CGFloat = 54
let barHeights: [CGFloat] = [340, 560, 420]
let totalWidth = barWidth * 3 + barSpacing * 2
let startX = (size - Int(totalWidth)) / 2
let centerY = CGFloat(size) / 2

let glyphColor = NSColor(red: 0.99, green: 0.97, blue: 0.93, alpha: 1)
glyphColor.setFill()

for (index, height) in barHeights.enumerated() {
  let x = CGFloat(startX) + CGFloat(index) * (barWidth + barSpacing)
  let rect = NSRect(x: x, y: centerY - height / 2, width: barWidth, height: height)
  let bar = NSBezierPath(roundedRect: rect, xRadius: barCornerRadius, yRadius: barCornerRadius)
  bar.fill()
}

NSGraphicsContext.restoreGraphicsState()

let destination = URL(fileURLWithPath: output)
try FileManager.default.createDirectory(
  at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
  fatalError("Could not encode icon")
}
try data.write(to: destination, options: .atomic)
