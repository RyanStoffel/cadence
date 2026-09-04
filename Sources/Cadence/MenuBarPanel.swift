import AppKit
import SwiftUI

struct MenuBarPanel: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.openWindow) private var openWindow
  @State private var isConfirmingReset = false

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
            Text(model.mode.title)
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

      ZStack {
        Circle()
          .stroke(Color.primary.opacity(0.07), lineWidth: 8)
        Circle()
          .trim(from: 0, to: model.progress)
          .stroke(CadencePalette.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
          .rotationEffect(.degrees(-90))
        VStack(spacing: 3) {
          Text(model.timeText)
            .font(.system(size: 28, weight: .semibold, design: .rounded))
            .monospacedDigit()
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
            Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 8, style: .continuous)
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
  }

  private func openMainWindow() {
    openWindow(id: "main")
    NSApp.activate()
  }
}
