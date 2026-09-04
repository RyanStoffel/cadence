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
        let bounds = contentView.bounds
        guard let image = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
        contentView.cacheDisplay(in: bounds, to: image)
        guard let data = image.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
      }

      return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
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
