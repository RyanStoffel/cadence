#if DEBUG
import AppKit
import Foundation
import SwiftUI
import CadenceCore

/// Explicit, in-process QA. Never uses Accessibility or screen-recording APIs.
@MainActor
enum CadenceUISmoke {
  static func validateEnvironment() {
    let environment = ProcessInfo.processInfo.environment
    guard let directory = environment["CADENCE_UI_SMOKE_DIR"] else { return }
    let root = URL(fileURLWithPath: directory).standardizedFileURL.resolvingSymlinksInPath()
    guard directory.hasPrefix("/"),
      let state = environment["CADENCE_STATE_PATH"], state.hasPrefix("/"),
      URL(fileURLWithPath: state).standardizedFileURL.resolvingSymlinksInPath()
        .deletingLastPathComponent().path == root.path,
      !FileManager.default.fileExists(atPath: state),
      environment["CADENCE_PREVIEW_DATA"] == nil,
      environment["CADENCE_PREVIEW_SCREEN"] == nil,
      environment["CADENCE_CAPTURE_PATH"] == nil,
      !root.path.hasPrefix(FileManager.default.urls(for: .applicationSupportDirectory,
        in: .userDomainMask)[0].path)
    else {
      fputs("UI smoke requires a fresh CADENCE_STATE_PATH directly inside its isolated output directory.\n", stderr)
      exit(2)
    }
  }

  static func runIfRequested() {
    guard let directory = ProcessInfo.processInfo.environment["CADENCE_UI_SMOKE_DIR"] else { return }
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(1))
      let visible = NSApp.windows.filter { $0.isVisible && $0.title == "Cadence" }
      var assertions: [[String: Any]] = [
        ["name": "no_main_window_on_launch", "passed": visible.isEmpty,
         "actual": visible.count],
        ["name": "accessory_on_launch", "passed": NSApp.activationPolicy() == .accessory,
         "actual": NSApp.activationPolicy().rawValue]
      ]
      do {
        let root = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        func check(_ name: String, _ passed: Bool, _ actual: Any) {
          assertions.append(["name": name, "passed": passed, "actual": actual])
        }
        check("focus_menu_installed", NSApp.mainMenu?.items.contains { $0.title == "Focus" } == true,
          NSApp.mainMenu?.items.map(\.title) ?? [])
        let controller = MainWindowController.shared
        let model = AppDelegate.model
        check("lazy_window_not_created", controller.windowController == nil, controller.windowController != nil)
        check("empty_isolated_log", model.sessions.isEmpty, model.sessions.count)
        controller.openMainWindow()
        try await Task.sleep(for: .milliseconds(400))
        guard let window = controller.windowController?.window, let content = window.contentView else {
          throw SmokeError.missingWindow
        }
        check("opens_key_window", window.isVisible && window.isKeyWindow, window.isKeyWindow)
        window.performClose(nil)
        try await Task.sleep(for: .milliseconds(150))
        check("close_hides_window", !window.isVisible, window.isVisible)
        controller.openMainWindow()
        try await Task.sleep(for: .milliseconds(400))
        check("reopens_same_key_window", controller.windowController?.window === window && window.isKeyWindow && window.isVisible, window.isKeyWindow)
        check("accessory_after_reopen", NSApp.activationPolicy() == .accessory, NSApp.activationPolicy().rawValue)
        check("active_after_reopen", NSApp.isActive, NSApp.isActive)
        window.setContentSize(window.contentMinSize)
        try await Task.sleep(for: .milliseconds(250))
        for (placeholder, value, isNote) in [
          ("What are you working on?", "UI smoke stopwatch", false),
          ("Optional detail for your log", "Typed after reopening", true)
        ] {
          let field = descendants(content).compactMap { $0 as? NSTextField }
            .first { $0.placeholderString == placeholder && $0.isEditable }
          let focused = field.map { window.makeFirstResponder($0) } ?? false
          if focused, let editor = window.firstResponder as? NSTextView {
            editor.selectAll(nil)
            editor.insertText(value, replacementRange: editor.selectedRange())
            window.makeFirstResponder(nil)
          }
          try await Task.sleep(for: .milliseconds(100))
          let actual = isNote ? model.currentNote : model.currentLabel
          check(isNote ? "note_input_after_reopen" : "label_input_after_reopen", focused && actual == value, actual)
        }
        check("native_toolbar_present", window.toolbar != nil, window.toolbar?.items.map { $0.itemIdentifier.rawValue } ?? [])
        check("minimum_content_size", content.bounds.size == NSSize(width: 860, height: 600),
          ["width": content.bounds.width, "height": content.bounds.height])
        try capture(content, to: root.appendingPathComponent("main-minimum.png"))
        if let frameView = content.superview {
          try capture(frameView, to: root.appendingPathComponent("main-window-toolbar.png"))
        }
        let panel = NSHostingView(rootView: MenuBarPanel().environmentObject(model))
        let panelWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 288, height: 460),
          styleMask: [.borderless], backing: .buffered, defer: false)
        panelWindow.contentView = panel
        panelWindow.setContentSize(panel.fittingSize)
        panelWindow.orderFront(nil)
        try await Task.sleep(for: .milliseconds(300))
        try capture(panel, to: root.appendingPathComponent("menu-pomodoro.png"))
        panelWindow.orderOut(nil)
        model.selectKind(.stopwatch)
        model.toggleStopwatch()
        try await Task.sleep(for: .milliseconds(1300))
        check("stopwatch_started", model.isStopwatchRunning && !model.isRunning, model.isStopwatchRunning)
        check("stopwatch_status_shows_elapsed", ActiveTimerCommands.statusText(model) == model.stopwatchTimeText,
          ActiveTimerCommands.statusText(model))
        try capture(content, to: root.appendingPathComponent("main-stopwatch-running.png"))
        panelWindow.setContentSize(panel.fittingSize)
        panelWindow.orderFront(nil)
        try await Task.sleep(for: .milliseconds(300))
        try capture(panel, to: root.appendingPathComponent("menu-stopwatch-running.png"))
        panelWindow.orderOut(nil)
        // Exercise the real app-menu keyboard equivalent, not a direct model call.
        let pause = keyEquivalent("\r", code: 36, modifiers: [.command], window: window)
        check("command_return_dispatched", pause, pause)
        try await Task.sleep(for: .milliseconds(100))
        check("command_return_pauses_stopwatch", !model.isStopwatchRunning && !model.isRunning, model.isStopwatchRunning)
        let pausedSeconds = model.stopwatchElapsedSeconds
        try await Task.sleep(for: .milliseconds(350))
        check("paused_elapsed_stable", model.stopwatchElapsedSeconds == pausedSeconds, model.stopwatchElapsedSeconds)
        let sessionsBefore = model.sessions.count
        model.stopAndLogStopwatch()
        check("stopwatch_stop_logs_once", model.sessions.count == sessionsBefore + 1 && model.sessions.last?.origin == .timer,
          model.sessions.count)
        check("stopwatch_log_keeps_typed_fields", model.sessions.last?.label == "UI smoke stopwatch" && model.sessions.last?.note == "Typed after reopening", model.sessions.last?.label ?? "")
        check("stopwatch_resets_after_log", !model.hasStartedStopwatchSession && model.stopwatchElapsedSeconds == 0, model.stopwatchElapsedSeconds)
        model.persistNow()
        let stored = try SnapshotStore(url: URL(fileURLWithPath: ProcessInfo.processInfo.environment["CADENCE_STATE_PATH"]!)).load()
        check("isolated_log_readback", stored?.sessions.count == model.sessions.count, stored?.sessions.count ?? -1)
        // The idle stopwatch reset must not mutate the inactive countdown duration.
        model.setDuration(17 * 60)
        let reset = keyEquivalent("r", code: 15, modifiers: [.command, .option], window: window)
        check("command_reset_dispatched", reset, reset)
        check("stopwatch_reset_leaves_countdown_untouched", model.timer.duration == 17 * 60, model.timer.duration)
        model.selectKind(.pomodoro)
        let start = keyEquivalent("\r", code: 36, modifiers: [.command], window: window)
        check("command_return_starts_countdown", start && model.isRunning && !model.isStopwatchRunning, model.isRunning)
        _ = keyEquivalent("\r", code: 36, modifiers: [.command], window: window)
        check("command_return_pauses_countdown", !model.isRunning, model.isRunning)
        model.discardTimer()
        check("accessory_at_end", NSApp.activationPolicy() == .accessory, NSApp.activationPolicy().rawValue)
        window.performClose(nil)
        let passed = assertions.allSatisfy { $0["passed"] as? Bool == true }
        let data = try JSONSerialization.data(withJSONObject: ["passed": passed, "assertions": assertions], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: root.appendingPathComponent("results.json"), options: .atomic)
        exit(passed ? 0 : 1)
      } catch {
        fputs("UI smoke failed: \(error)\n", stderr)
        exit(2)
      }
    }
  }
  private static func descendants(_ view: NSView) -> [NSView] {
    [view] + view.subviews.flatMap { descendants($0) }
  }

  private static func keyEquivalent(_ characters: String, code: UInt16,
    modifiers: NSEvent.ModifierFlags, window: NSWindow) -> Bool
  {
    guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero,
      modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber, context: nil, characters: characters,
      charactersIgnoringModifiers: characters, isARepeat: false, keyCode: code)
    else { return false }
    return NSApp.mainMenu?.performKeyEquivalent(with: event) == true
  }

  private static func capture(_ view: NSView, to url: URL) throws {
    view.layoutSubtreeIfNeeded()
    view.displayIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
      throw SmokeError.captureFailed
    }
    if let layer = view.layer, let context = NSGraphicsContext(bitmapImageRep: bitmap) {
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = context
      context.cgContext.setFillColor(NSColor.windowBackgroundColor.cgColor)
      context.cgContext.fill(view.bounds)
      // AppKit bitmap contexts are bottom-up; the SwiftUI layer tree is flipped.
      context.cgContext.translateBy(x: 0, y: view.bounds.height)
      context.cgContext.scaleBy(x: 1, y: -1)
      layer.render(in: context.cgContext)
      NSGraphicsContext.restoreGraphicsState()
    } else {
      view.cacheDisplay(in: view.bounds, to: bitmap)
    }
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
      throw SmokeError.captureFailed
    }
    try data.write(to: url, options: .atomic)
  }

  private enum SmokeError: Error { case missingWindow, captureFailed }
}
#endif
