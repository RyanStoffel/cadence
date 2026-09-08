import AppKit
import CadenceCore
import SwiftUI
import Combine

/// AppKit owns the lifecycle; SwiftUI owns the unchanged window and menu content.
/// With no SwiftUI Window scene, launch cannot implicitly create a main window.
@main
@MainActor
enum CadenceApp {
  static func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
  }
}

/// Shared dispatch for the application menu; the inactive timer is never changed.
@MainActor
enum ActiveTimerCommands {
  static func statusText(_ model: AppModel) -> String {
    if model.activeKind == .stopwatch {
      return model.isStopwatchRunning ? model.stopwatchTimeText : ""
    }
    return model.menuBarText
  }

  static func toggle(_ model: AppModel) {
    if model.activeKind == .stopwatch { model.toggleStopwatch() }
    else { model.toggleTimer() }
  }

  static func reset(_ model: AppModel) {
    if model.activeKind == .stopwatch {
      // Match countdown reset: never silently discard an unlogged session.
      guard !model.hasStartedStopwatchSession else { return }
      model.discardStopwatch()
    } else { model.resetTimer() }
  }
}

/// Retain both the controller and its content after close. No window is made at launch.
@MainActor
final class MainWindowController: NSObject, NSMenuItemValidation {
  static let shared = MainWindowController()
  private(set) var windowController: NSWindowController?
  private var model: AppModel { AppDelegate.model }

  @objc func openMainWindow(_ sender: Any? = nil) {
    (NSApp.delegate as? AppDelegate)?.closePopover()
    if windowController == nil {
      let host = NSHostingController(rootView: MainView().environmentObject(model))
      let window = NSWindow(contentViewController: host)
      window.title = "Cadence"
      window.identifier = NSUserInterfaceItemIdentifier("cadence.main")
      window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
      window.isReleasedWhenClosed = false
      window.contentMinSize = NSSize(width: 860, height: 600)
      window.setContentSize(NSSize(width: 1_000, height: 680))
      window.center()
      windowController = NSWindowController(window: window)
    }
    guard let window = windowController?.window else { return }
    if window.isMiniaturized { window.deminiaturize(sender) }
    NSApp.activate(ignoringOtherApps: true)
    windowController?.showWindow(sender)
    window.makeKeyAndOrderFront(sender)
    // MenuBarExtra can finish dismissing after its button action returns.
    DispatchQueue.main.async {
      NSApp.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(sender)
    }
  }

  @objc func toggleTimer(_ sender: Any?) { ActiveTimerCommands.toggle(model) }
  @objc func resetTimer(_ sender: Any?) { ActiveTimerCommands.reset(model) }
  @objc func addTime(_ sender: Any?) {
    openMainWindow(sender)
    model.isManualEntryPresented = true
  }
  @objc func copyWeeklyLog(_ sender: Any?) { model.copyWeeklyLog() }

  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if menuItem.action == #selector(toggleTimer(_:)) {
      let running = model.activeKind == .stopwatch ? model.isStopwatchRunning : model.isRunning
      menuItem.title = "\(running ? "Pause" : "Start") \(model.activeKind == .stopwatch ? "Stopwatch" : "Timer")"
      return running || (model.activeKind == .pomodoro && model.mode != .focus)
        || !model.currentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    if menuItem.action == #selector(resetTimer(_:)) {
      menuItem.title = model.activeKind == .stopwatch ? "Reset Stopwatch" : "Reset Timer"
      return model.activeKind == .stopwatch ? !model.hasStartedStopwatchSession : !model.hasStartedSession
    }
    if menuItem.action == #selector(copyWeeklyLog(_:)) { return !model.sessions.isEmpty }
    return true
  }

  /// NSHostingController windows need an AppKit menu (there is no SwiftUI Window scene).
  func installMainMenu() {
    let main = NSMenu()
    func submenu(_ title: String) -> NSMenu {
      let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
      let menu = NSMenu(title: title)
      item.submenu = menu
      main.addItem(item)
      return menu
    }
    func add(_ menu: NSMenu, _ title: String, _ action: Selector,
      _ key: String, _ modifiers: NSEvent.ModifierFlags = [.command], target: AnyObject? = nil)
    {
      let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
      item.keyEquivalentModifierMask = modifiers
      item.target = target
      menu.addItem(item)
    }
    let app = submenu("Cadence")
    add(app, "About Cadence", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), "")
    app.addItem(.separator())
    add(app, "Hide Cadence", #selector(NSApplication.hide(_:)), "h")
    app.addItem(.separator())
    add(app, "Quit Cadence", #selector(NSApplication.terminate(_:)), "q")
    let file = submenu("File")
    add(file, "Open Cadence", #selector(openMainWindow(_:)), "o", target: self)
    add(file, "Close Window", #selector(NSWindow.performClose(_:)), "w")
    let edit = submenu("Edit")
    add(edit, "Undo", Selector(("undo:")), "z")
    add(edit, "Redo", Selector(("redo:")), "z", [.command, .shift])
    edit.addItem(.separator())
    add(edit, "Cut", #selector(NSText.cut(_:)), "x")
    add(edit, "Copy", #selector(NSText.copy(_:)), "c")
    add(edit, "Paste", #selector(NSText.paste(_:)), "v")
    add(edit, "Select All", #selector(NSText.selectAll(_:)), "a")
    let focus = submenu("Focus")
    add(focus, "Start Timer", #selector(toggleTimer(_:)), "\r", target: self)
    add(focus, "Reset Timer", #selector(resetTimer(_:)), "r", [.command, .option], target: self)
    focus.addItem(.separator())
    add(focus, "Add Time Manually", #selector(addTime(_:)), "n", [.command, .shift], target: self)
    add(focus, "Copy Weekly Log", #selector(copyWeeklyLog(_:)), "c", [.command, .shift], target: self)
    NSApp.mainMenu = main
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  static let model: AppModel = {
    #if DEBUG
      CadenceUISmoke.validateEnvironment()
    #endif
    return AppModel()
  }()

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

  private var statusItem: NSStatusItem?
  private let popover = NSPopover()
  private var modelObservation: AnyCancellable?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    MainWindowController.shared.installMainMenu()
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    statusItem = item
    item.button?.target = self
    item.button?.action = #selector(togglePopover(_:))
    popover.behavior = .transient
    popover.contentViewController = NSHostingController(rootView: MenuBarPanel().environmentObject(Self.model))
    updateStatus()
    modelObservation = Self.model.objectWillChange.sink { [weak self] _ in
      Task { @MainActor in self?.updateStatus() }
    }
    #if DEBUG
      CadenceUISmoke.runIfRequested()
    #endif
  }

  @objc private func togglePopover(_ sender: Any?) {
    if popover.isShown { popover.performClose(sender); return }
    guard let button = statusItem?.button else { return }
    NSApp.activate(ignoringOtherApps: true)
    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    popover.contentViewController?.view.window?.makeKey()
  }

  func closePopover() { popover.performClose(nil) }

  private func updateStatus() {
    guard let button = statusItem?.button else { return }
    let model = Self.model
    button.title = ActiveTimerCommands.statusText(model)
    button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    button.image = NSImage(systemSymbolName: model.activeKind == .stopwatch ? "stopwatch" : "timer",
      accessibilityDescription: "Cadence")
    button.image?.isTemplate = true
    button.imagePosition = .imageLeading
    button.toolTip = "Cadence"
  }

  func applicationWillTerminate(_ notification: Notification) { Self.model.persistNow() }
}
