import AppKit
import CadenceCore
import SwiftUI

struct MenuBarPanel: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.openWindow) private var openWindow
  @State private var isConfirmingReset = false
  @State private var isConfirmingStopwatchReset = false

  private var labelBinding: Binding<String> {
    Binding(get: { model.currentLabel }, set: { model.setLabel($0) })
  }

  private let durationPresets: [Int] = [15, 25, 45, 60]

  var body: some View {
    VStack(spacing: 15) {
      HStack {
        HStack(spacing: 9) {
          ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(CadencePalette.orange)
            Image(systemName: "waveform")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.white)
          }
          .frame(width: 29, height: 29)
          VStack(alignment: .leading, spacing: 1) {
            Text("Cadence")
              .font(.system(size: 13, weight: .semibold))
            Text(model.activeKind == .pomodoro ? model.mode.title : "Stopwatch")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
        Button {
          openMainWindow()
        } label: {
          Image(systemName: "arrow.up.forward.app")
        }
        .buttonStyle(.plain)
        .help("Open Cadence")
      }

      MenuBarKindSelector()

      if model.activeKind == .pomodoro {
        ZStack {
          Circle()
            .stroke(Color.primary.opacity(0.07), lineWidth: 8)
          Circle()
            .trim(from: 0, to: model.progress)
            .stroke(CadencePalette.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(-90))
          VStack(spacing: 3) {
            MenuBarEditableDurationText()
            Text(model.isRunning ? "FOCUSING" : (model.hasStartedSession ? "PAUSED" : "READY"))
              .font(.system(size: 8, weight: .bold))
              .tracking(1.1)
              .foregroundStyle(.secondary)
          }
        }
        .frame(width: 132, height: 132)

        if model.mode == .focus {
          TextField("What are you working on?", text: labelBinding)
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
              Color.primary.opacity(0.045),
              in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .disabled(model.hasStartedSession)
            .opacity(model.hasStartedSession ? 0.72 : 1)
        } else {
          Text(model.mode == .shortBreak ? "Take a short reset" : "Take a proper break")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }

        if !model.hasStartedSession {
          HStack(spacing: 6) {
            ForEach(durationPresets, id: \.self) { minutes in
              Button {
                model.setDuration(TimeInterval(minutes * 60))
              } label: {
                Text("\(minutes)m")
                  .font(.system(size: 11, weight: .semibold))
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 6)
              }
              .buttonStyle(.plain)
              .background(
                (model.timer.duration == TimeInterval(minutes * 60))
                  ? CadencePalette.orange.opacity(0.16) : Color.primary.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
              )
              .foregroundStyle(
                (model.timer.duration == TimeInterval(minutes * 60))
                  ? CadencePalette.orange : Color.secondary)
            }
          }
        }

        HStack(spacing: 9) {
          Button {
            if model.hasStartedSession {
              isConfirmingReset = true
            } else {
              model.resetTimer()
            }
          } label: {
            Image(systemName: "arrow.counterclockwise")
              .frame(width: 20, height: 20)
          }
          .buttonStyle(.bordered)

          Button {
            model.toggleTimer()
          } label: {
            Label(
              model.isRunning ? "Pause" : (model.hasStartedSession ? "Resume" : "Start"),
              systemImage: model.isRunning ? "pause.fill" : "play.fill"
            )
            .frame(minWidth: 86)
          }
          .buttonStyle(CadencePrimaryButtonStyle())
          .disabled(
            model.mode == .focus
              && model.currentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              && !model.isRunning)

          if model.mode == .focus && model.hasStartedSession {
            Button {
              model.finishFocus()
            } label: {
              Image(systemName: "checkmark")
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.bordered)
            .help("Finish and log")
            .disabled(model.elapsedSeconds < 1)
          }
        }
      } else {
        ZStack {
          Circle()
            .stroke(Color.primary.opacity(0.07), lineWidth: 8)
          Circle()
            .stroke(CadencePalette.gold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .opacity(model.isStopwatchRunning ? 0.9 : 0.3)
          VStack(spacing: 3) {
            Text(model.stopwatchTimeText)
              .font(.system(size: 28, weight: .semibold, design: .rounded))
              .monospacedDigit()
            Text(
              model.isStopwatchRunning
                ? "COUNTING" : (model.hasStartedStopwatchSession ? "PAUSED" : "READY")
            )
            .font(.system(size: 8, weight: .bold))
            .tracking(1.1)
            .foregroundStyle(.secondary)
          }
        }
        .frame(width: 132, height: 132)

        TextField("What are you working on?", text: labelBinding)
          .textFieldStyle(.plain)
          .font(.system(size: 12, weight: .medium))
          .padding(.horizontal, 10)
          .frame(height: 30)
          .background(
            Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
          )
          .disabled(model.hasStartedStopwatchSession)
          .opacity(model.hasStartedStopwatchSession ? 0.72 : 1)

        HStack(spacing: 9) {
          Button {
            if model.stopwatchElapsedSeconds > 0 {
              isConfirmingStopwatchReset = true
            } else {
              model.discardStopwatch()
            }
          } label: {
            Image(systemName: "arrow.counterclockwise")
              .frame(width: 20, height: 20)
          }
          .buttonStyle(.bordered)

          Button {
            model.toggleStopwatch()
          } label: {
            Label(
              model.isStopwatchRunning
                ? "Pause" : (model.hasStartedStopwatchSession ? "Resume" : "Start"),
              systemImage: model.isStopwatchRunning ? "pause.fill" : "play.fill"
            )
            .frame(minWidth: 86)
          }
          .buttonStyle(CadencePrimaryButtonStyle())
          .disabled(
            model.currentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              && !model.isStopwatchRunning)

          if model.hasStartedStopwatchSession {
            Button {
              model.stopAndLogStopwatch()
            } label: {
              Image(systemName: "checkmark")
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.bordered)
            .help("Stop and log")
            .disabled(model.stopwatchElapsedSeconds < 1)
          }
        }
      }

      Divider()

      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("THIS WEEK")
            .font(.system(size: 8, weight: .bold))
            .tracking(1)
            .foregroundStyle(.secondary)
          Text(String(format: "%.1f hours", model.weeklyReport.totalSeconds / 3_600))
            .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        Spacer()
        Button("Copy log line") {
          model.copyWeeklyLog()
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.semibold))
        .foregroundStyle(CadencePalette.orange)
        .disabled(model.weeklyReport.sessions.isEmpty)
      }

      HStack {
        Button("Open App") { openMainWindow() }
          .buttonStyle(.plain)
        Spacer()
        Button("Quit") {
          model.persistNow()
          NSApp.terminate(nil)
        }
        .buttonStyle(.plain)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(17)
    .frame(width: 310)
    .confirmationDialog(
      "Discard this timer?",
      isPresented: $isConfirmingReset,
      titleVisibility: .visible
    ) {
      Button("Discard Timer", role: .destructive) {
        model.discardTimer()
      }
      Button("Keep Timer", role: .cancel) {}
    } message: {
      Text("Unlogged focus time in this timer will be lost.")
    }
    .confirmationDialog(
      "Discard this stopwatch?",
      isPresented: $isConfirmingStopwatchReset,
      titleVisibility: .visible
    ) {
      Button("Discard Stopwatch", role: .destructive) {
        model.discardStopwatch()
      }
      Button("Keep Stopwatch", role: .cancel) {}
    } message: {
      Text("Unlogged elapsed time on this stopwatch will be lost.")
    }
  }

  private func openMainWindow() {
    openWindow(id: "main")
    NSApp.activate()
  }
}

struct MenuBarKindSelector: View {
  @EnvironmentObject private var model: AppModel

  private var isLocked: Bool {
    model.hasStartedSession || model.hasStartedStopwatchSession
  }

  var body: some View {
    HStack(spacing: 5) {
      ForEach(TimerKind.allCases, id: \.rawValue) { kind in
        Button {
          model.selectKind(kind)
        } label: {
          Text(kind.title)
            .font(.system(size: 11, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.activeKind == kind ? Color.white : Color.secondary)
        .background {
          if model.activeKind == kind {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .fill(CadencePalette.gold)
          }
        }
      }
    }
    .padding(3)
    .background(
      Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous)
    )
    .disabled(isLocked)
  }
}

/// The menu bar's big time readout; tapping it (when not running/started)
/// swaps to an inline numeric field for a custom minute count. Implemented
/// as an inline swap rather than a popover, since popovers anchored inside
/// another popover are unreliable in the menu bar extra.
struct MenuBarEditableDurationText: View {
  @EnvironmentObject private var model: AppModel
  @State private var isEditing = false
  @State private var draftText = ""
  @FocusState private var isFieldFocused: Bool

  private var canEdit: Bool {
    !model.hasStartedSession
  }

  var body: some View {
    if isEditing {
      TextField("", text: $draftText)
        .textFieldStyle(.plain)
        .font(.system(size: 28, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .frame(width: 96)
        .focused($isFieldFocused)
        .onSubmit { commit() }
        .onExitCommand { cancel() }
        .onChange(of: isFieldFocused) { _, focused in
          if !focused { cancel() }
        }
        .onAppear { isFieldFocused = true }
    } else {
      Text(model.timeText)
        .font(.system(size: 28, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .contentShape(Rectangle())
        .onTapGesture { beginEditing() }
        .help(canEdit ? "Tap to set a custom duration" : "")
    }
  }

  private func beginEditing() {
    guard canEdit else { return }
    draftText = "\(max(1, Int((model.timer.duration / 60).rounded())))"
    isEditing = true
  }

  private func commit() {
    defer { isEditing = false }
    guard let minutes = Int(draftText.trimmingCharacters(in: .whitespaces)), minutes > 0 else {
      return
    }
    model.setDuration(TimeInterval(minutes * 60))
  }

  private func cancel() {
    isEditing = false
  }
}
