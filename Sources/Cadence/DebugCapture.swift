import SwiftUI

#if DEBUG
  import AppKit

  private struct DebugCaptureView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
      let view = NSView(frame: .zero)
      guard let path = ProcessInfo.processInfo.environment["CADENCE_CAPTURE_PATH"] else {
        return view
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak view] in
        let sheet = NSApp.windows.first { $0.isVisible && $0.sheetParent != nil }
        guard
          let contentView = sheet?.contentView ?? NSApp.keyWindow?.contentView
            ?? view?.window?.contentView
        else { return }
        guard let data = capture(contentView) else { return }
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
      }

      return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    /// Layer rendering is used when available because SwiftUI content lives in
    /// its own layer tree that `cacheDisplay` does not pick up for sheets.
    private func capture(_ view: NSView) -> Data? {
      let bounds = view.bounds
      guard let image = view.bitmapImageRepForCachingDisplay(in: bounds) else { return nil }

      if let layer = view.layer, let context = NSGraphicsContext(bitmapImageRep: image) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.cgContext.fill(bounds)
        layer.render(in: context.cgContext)
        NSGraphicsContext.restoreGraphicsState()
      } else {
        view.cacheDisplay(in: bounds, to: image)
      }

      return image.representation(using: .png, properties: [:])
    }
  }
#endif

extension View {
  @ViewBuilder
  func debugCaptureIfRequested() -> some View {
    #if DEBUG
      background(DebugCaptureView().frame(width: 0, height: 0))
    #else
      self
    #endif
  }
}
