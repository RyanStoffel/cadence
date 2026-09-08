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

let tileRect = bounds.insetBy(dx: 42, dy: 42)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 220, yRadius: 220)
NSColor(red: 0.200, green: 0.278, blue: 0.400, alpha: 1).setFill()
tile.fill()

let glyphColor = NSColor(red: 0.965, green: 0.973, blue: 0.984, alpha: 1)
glyphColor.setFill()
glyphColor.setStroke()

let center = NSPoint(x: CGFloat(size) / 2, y: 486)
let ringRadius: CGFloat = 292
let ringWidth: CGFloat = 62

let ring = NSBezierPath()
ring.appendArc(
  withCenter: center, radius: ringRadius, startAngle: 0, endAngle: 360)
ring.lineWidth = ringWidth
ring.stroke()

let stemWidth: CGFloat = 128
let stemHeight: CGFloat = 96
let stemRect = NSRect(
  x: center.x - stemWidth / 2,
  y: center.y + ringRadius + ringWidth / 2 - 34,
  width: stemWidth,
  height: stemHeight
)
NSBezierPath(roundedRect: stemRect, xRadius: 34, yRadius: 34).fill()

let handAngle = CGFloat.pi / 4
let handLength: CGFloat = 176
let hand = NSBezierPath()
hand.move(to: center)
hand.line(
  to: NSPoint(
    x: center.x + sin(handAngle) * handLength,
    y: center.y + cos(handAngle) * handLength
  ))
hand.lineWidth = 46
hand.lineCapStyle = .round
hand.stroke()

let hubRadius: CGFloat = 30
NSBezierPath(
  ovalIn: NSRect(
    x: center.x - hubRadius,
    y: center.y - hubRadius,
    width: hubRadius * 2,
    height: hubRadius * 2
  )
).fill()

NSGraphicsContext.restoreGraphicsState()

let destination = URL(fileURLWithPath: output)
try FileManager.default.createDirectory(
  at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
guard let data = bitmap.representation(using: .png, properties: [:]) else {
  fatalError("Could not encode icon")
}
try data.write(to: destination, options: .atomic)
