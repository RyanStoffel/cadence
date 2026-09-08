import AppKit
import CadenceCore
import SwiftUI

struct MenuBarPanel: View {
  @EnvironmentObject private var model: AppModel

  @State private var isConfirmingReset = false
  @State private var isConfirmingStopwatchReset = false

  private var labelBinding: Binding<String> {
    Binding(get: { model.currentLabel }, set: { model.setLabel($0) })
  }

  private let durationPresets: [Int] = [15, 25, 45, 60]

  var body: some View {
    VStack(spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 1) {
          Text("Cadence")
            .font(CadenceType.emphasis)
          Text(model.activeKind == .pomodoro ? model.mode.title : "Stopwatch")
            .font(CadenceType.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          openMainWindow()
        } label: {
          Image(systemName: "arrow.up.forward.app")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Open Cadence")
      }

      MenuBarKindSelector()

      if model.activeKind == .pomodoro {
        ZStack {
          Circle()
            .stroke(CadencePalette.track, lineWidth: 6)
          Circle()
            .trim(from: 0, to: model.progress)
            .stroke(CadencePalette.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            .rotationEffect(.degrees(-90))
          VStack(spacing: 2) {
            MenuBarEditableDurationText()
            Text(model.isRunning ? "FOCUSING" : (model.hasStartedSession ? "PAUSED" : "READY"))
              .font(CadenceType.eyebrow)
              .tracking(CadenceType.eyebrowTracking)
              .foregroundStyle(.secondary)
          }
        }
        .frame(width: 120, height: 120)

        if model.mode == .focus {
          TextField("What are you working on?", text: labelBinding)
            .textFieldStyle(.plain)
            .font(CadenceType.body)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .cadenceFieldChrome()
            .disabled(model.hasStartedSession)
            .opacity(model.hasStartedSession ? 0.7 : 1)
        } else {
          Text(model.mode == .shortBreak ? "Take a short reset" : "Take a proper break")
            .font(CadenceType.body)
            .foregroundStyle(.secondary)
            .frame(height: 28)
        }

        if !model.hasStartedSession {
          HStack(spacing: 5) {
            ForEach(durationPresets, id: \.self) { minutes in
              let selected = model.timer.duration == TimeInterval(minutes * 60)
              Button {
                model.setDuration(TimeInterval(minutes * 60))
              } label: {
                Text("\(minutes)m")
                  .font(CadenceType.control)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 5)
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .foregroundStyle(selected ? CadencePalette.accent : Color.secondary)
              .background(
                selected ? CadencePalette.accent.opacity(0.14) : CadencePalette.subtleFill,
                in: RoundedRectangle(cornerRadius: 5, style: .continuous)
              )
              .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                  .stroke(CadencePalette.hairline)
              }
            }
          }
        }

        HStack(spacing: 8) {
          Button {
            if model.hasStartedSession {
              isConfirmingReset = true
            } else {
              model.resetTimer()
            }
          } label: {
            Image(systemName: "arrow.counterclockwise")
              .frame(width: 16, height: 16)
          }
          .buttonStyle(.bordered)

          Button {
            model.toggleTimer()
          } label: {
            Label(
              model.isRunning ? "Pause" : (model.hasStartedSession ? "Resume" : "Start"),
              systemImage: model.isRunning ? "pause.fill" : "play.fill"
            )
            .frame(minWidth: 80)
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
                .frame(width: 16, height: 16)
            }
            .buttonStyle(.bordered)
            .help("Finish and log")
            .disabled(model.elapsedSeconds < 1)
          }
        }
      } else {
        ZStack {
          Circle()
            .stroke(CadencePalette.track, lineWidth: 6)
          Circle()
            .stroke(
              model.isStopwatchRunning
                ? CadencePalette.accent : CadencePalette.accent.opacity(0.35),
              style: StrokeStyle(lineWidth: 6, lineCap: .round)
            )
          VStack(spacing: 2) {
            Text(model.stopwatchTimeText)
              .font(.system(size: 24, weight: .light))
              .monospacedDigit()
            Text(
              model.isStopwatchRunning
                ? "COUNTING" : (model.hasStartedStopwatchSession ? "PAUSED" : "READY")
            )
            .font(CadenceType.eyebrow)
            .tracking(CadenceType.eyebrowTracking)
            .foregroundStyle(.secondary)
          }
        }
        .frame(width: 120, height: 120)

        TextField("What are you working on?", text: labelBinding)
          .textFieldStyle(.plain)
          .font(CadenceType.body)
          .padding(.horizontal, 9)
          .frame(height: 28)
          .cadenceFieldChrome()
          .disabled(model.hasStartedStopwatchSession)
          .opacity(model.hasStartedStopwatchSession ? 0.7 : 1)

        HStack(spacing: 8) {
          Button {
            if model.stopwatchElapsedSeconds > 0 {
              isConfirmingStopwatchReset = true
            } else {
              model.discardStopwatch()
            }
          } label: {
            Image(systemName: "arrow.counterclockwise")
              .frame(width: 16, height: 16)
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
            .frame(minWidth: 80)
          }
          .buttonStyle(CadencePrimaryButtonStyle())
          .disabled(
            model.currentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              && !model.isStopwatchRunning)

          if model.hasStartedStopwatchSession {
            Button("Stop & Log") {
              model.stopAndLogStopwatch()
            }
            .buttonStyle(.bordered)
            .help("Stop and log")
            .disabled(model.stopwatchElapsedSeconds < 1)
          }
        }
      }

      Divider()

      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text("THIS WEEK")
            .font(CadenceType.eyebrow)
            .tracking(CadenceType.eyebrowTracking)
            .foregroundStyle(.secondary)
          Text(String(format: "%.1f hours", model.weeklyReport.totalSeconds / 3_600))
            .font(CadenceType.emphasis)
        }
        Spacer()
        Button("Copy log line") {
          model.copyWeeklyLog()
        }
        .buttonStyle(.link)
        .font(CadenceType.caption)
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
      .font(CadenceType.caption)
      .foregroundStyle(.secondary)
    }
    .padding(14)
    .frame(width: 288)
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
    MainWindowController.shared.openMainWindow()
  }
}

struct MenuBarKindSelector: View {
  @EnvironmentObject private var model: AppModel

  private var isLocked: Bool {
    model.hasStartedSession || model.hasStartedStopwatchSession
  }

  var body: some View {
    SegmentedRow(
      items: TimerKind.allCases,
      title: { $0.title },
      isSelected: { model.activeKind == $0 },
      select: { model.selectKind($0) }
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
        .font(.system(size: 24, weight: .light))
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .frame(width: 90)
        .focused($isFieldFocused)
        .onSubmit { commit() }
        .onExitCommand { cancel() }
        .onChange(of: isFieldFocused) { _, focused in
          if !focused { cancel() }
        }
        .onAppear { isFieldFocused = true }
    } else {
      Text(model.timeText)
        .font(.system(size: 24, weight: .light))
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
    guard let seconds = DurationInput.seconds(from: draftText) else { return }
    model.setDuration(seconds)
    isEditing = false
  }

  private func cancel() {
    isEditing = false
  }
}
