import AppKit
import CadenceCore
import SwiftUI

@main
struct CadenceApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var model = AppModel()

  var body: some Scene {
    Window("Cadence", id: "main") {
      MainView()
        .environmentObject(model)
    }
    .defaultSize(width: 1_040, height: 700)
    .windowResizability(.contentMinSize)
    .commands {
      CommandMenu("Focus") {
        Button(model.isRunning ? "Pause Timer" : "Start Timer") {
          model.toggleTimer()
        }
        .keyboardShortcut(.return, modifiers: [.command])

        Button("Reset Timer") {
          model.resetTimer()
        }
        .keyboardShortcut("r", modifiers: [.command, .option])

        Divider()

        Button("Add Time Manually") {
          model.isManualEntryPresented = true
        }
        .keyboardShortcut("n", modifiers: [.command, .shift])

        Button("Copy Weekly Log") {
          model.copyWeeklyLog()
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])
      }
    }

    MenuBarExtra {
      MenuBarPanel()
        .environmentObject(model)
    } label: {
      if model.isRunning {
        Label(model.menuBarText, systemImage: "waveform")
      } else {
        Image(systemName: "waveform")
      }
    }
    .menuBarExtraStyle(.window)
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}
