import AppKit
import CadenceCore
import SwiftUI

extension TimerMode {
  var title: String {
    switch self {
    case .focus: "Focus"
    case .shortBreak: "Short break"
    case .longBreak: "Long break"
    }
  }

  var eyebrow: String {
    switch self {
    case .focus: "DEEP WORK"
    case .shortBreak: "RESET"
    case .longBreak: "RECHARGE"
    }
  }

  var systemImage: String {
    switch self {
    case .focus: "timer"
    case .shortBreak: "cup.and.saucer"
    case .longBreak: "moon.zzz"
    }
  }
}

enum CadencePalette {
  /// One accent, used sparingly. Slightly lighter in dark mode so text set in
  /// the accent stays legible against dark surfaces.
  static let accent = Color(
    nsColor: NSColor(name: nil) { appearance in
      appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        ? NSColor(red: 0.478, green: 0.588, blue: 0.741, alpha: 1)
        : NSColor(red: 0.290, green: 0.400, blue: 0.561, alpha: 1)
    })
  static let accentDeep = Color(red: 0.200, green: 0.278, blue: 0.400)

  static let cardFill = Color(nsColor: .controlBackgroundColor)
  static let hairline = Color.primary.opacity(0.11)
  static let subtleFill = Color.primary.opacity(0.055)
  static let track = Color.primary.opacity(0.09)
}

enum CadenceType {
  static let eyebrowTracking: CGFloat = 0.8

  static let eyebrow = Font.system(size: 10, weight: .semibold)
  static let caption = Font.system(size: 11)
  static let control = Font.system(size: 12, weight: .medium)
  static let body = Font.system(size: 13)
  static let emphasis = Font.system(size: 13, weight: .semibold)
  static let field = Font.system(size: 14)
  static let figure = Font.system(size: 20, weight: .medium)
}

extension TimerKind {
  var title: String {
    switch self {
    case .pomodoro: "Pomodoro"
    case .stopwatch: "Stopwatch"
    }
  }
}

struct MainView: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      FocusCard()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      VStack(spacing: 16) {
        WeekCard()
        RecentActivityCard()
          .frame(maxHeight: .infinity)
      }
      .frame(width: 350)
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color(nsColor: .windowBackgroundColor))
    .overlay(alignment: .topTrailing) {
      if let message = model.bannerMessage {
        BannerView(message: message)
          .padding(16)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .animation(.easeOut(duration: 0.22), value: model.bannerMessage)
    .frame(minWidth: 860, minHeight: 600)
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Button {
          model.isManualEntryPresented = true
        } label: {
          Label("Add time", systemImage: "plus")
        }
        .help("Add time manually")

        Button {
          model.isHistoryPresented = true
        } label: {
          Label("Work log", systemImage: "list.bullet.rectangle")
        }
        .help("Open the work log")

        Button {
          model.exportCSV()
        } label: {
          Label("Export", systemImage: "square.and.arrow.up")
        }
        .help("Export the work log as CSV")
      }
    }
    .debugCaptureIfRequested()
    .sheet(isPresented: $model.isManualEntryPresented) {
      ManualEntryView()
        .environmentObject(model)
    }
    .sheet(isPresented: $model.isHistoryPresented) {
      WorkLogView()
        .environmentObject(model)
    }
    .onDisappear {
      model.persistNow()
    }
    .onAppear {
      model.presentPreviewScreenIfRequested()
    }
  }
}

struct FocusCard: View {
  @EnvironmentObject private var model: AppModel
  @State private var isConfirmingReset = false
  @State private var isConfirmingStopwatchReset = false

  private var labelBinding: Binding<String> {
    Binding(get: { model.currentLabel }, set: { model.setLabel($0) })
  }

  private var noteBinding: Binding<String> {
    Binding(get: { model.currentNote }, set: { model.setNote($0) })
  }

  var body: some View {
    VStack(spacing: 14) {
      KindSelector()

      if model.activeKind == .pomodoro {
        ModeSelector()

        if model.mode == .focus {
          labelAndNoteFields
        } else {
          HStack(spacing: 8) {
            Image(systemName: model.mode.systemImage)
              .foregroundStyle(.secondary)
            Text(
              model.mode == .shortBreak
                ? "Step away for a moment. Your work is safe."
                : "Take a real pause and return with fresh eyes."
            )
            .foregroundStyle(.secondary)
          }
          .font(CadenceType.body)
          .frame(height: 82)
        }

        TimerDial()
          .frame(width: 244, height: 244)

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
          .help("Reset timer")

          Button {
            model.toggleTimer()
          } label: {
            Label(
              model.isRunning ? "Pause" : (model.hasStartedSession ? "Resume" : "Start"),
              systemImage: model.isRunning ? "pause.fill" : "play.fill"
            )
            .frame(minWidth: 96)
          }
          .buttonStyle(CadencePrimaryButtonStyle())
          .keyboardShortcut(.return, modifiers: [.command])
          .disabled(
            model.mode == .focus
              && model.currentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              && !model.isRunning)

          if model.mode == .focus && model.hasStartedSession {
            Button("Finish & Log") {
              model.finishFocus()
            }
            .buttonStyle(.bordered)
            .disabled(model.elapsedSeconds < 1)
          }
        }

        Text(statusText)
          .font(CadenceType.caption)
          .foregroundStyle(.secondary)
          .frame(height: 14)
      } else {
        labelAndNoteFields

        StopwatchDial()
          .frame(width: 244, height: 244)

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
          .help("Discard stopwatch")

          Button {
            model.toggleStopwatch()
          } label: {
            Label(
              model.isStopwatchRunning
                ? "Pause" : (model.hasStartedStopwatchSession ? "Resume" : "Start"),
              systemImage: model.isStopwatchRunning ? "pause.fill" : "play.fill"
            )
            .frame(minWidth: 96)
          }
          .buttonStyle(CadencePrimaryButtonStyle())
          .keyboardShortcut(.return, modifiers: [.command])
          .disabled(
            model.currentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
              && !model.isStopwatchRunning)

          if model.hasStartedStopwatchSession {
            Button("Stop & Log") {
              model.stopAndLogStopwatch()
            }
            .buttonStyle(.bordered)
            .disabled(model.stopwatchElapsedSeconds < 1)
          }
        }

        Text(stopwatchStatusText)
          .font(CadenceType.caption)
          .foregroundStyle(.secondary)
          .frame(height: 14)
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .cadenceCard()
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

  private var labelAndNoteFields: some View {
    VStack(spacing: 8) {
      HStack(spacing: 8) {
        Image(systemName: "tag")
          .foregroundStyle(.secondary)
        TextField("What are you working on?", text: labelBinding)
          .textFieldStyle(.plain)
          .font(CadenceType.field)
      }
      .padding(.horizontal, 10)
      .frame(height: 34)
      .cadenceFieldChrome()

      HStack(spacing: 8) {
        Image(systemName: "text.alignleft")
          .foregroundStyle(.tertiary)
        TextField("Optional detail for your log", text: noteBinding)
          .textFieldStyle(.plain)
          .font(CadenceType.body)
      }
      .padding(.horizontal, 10)
      .frame(height: 32)
      .cadenceFieldChrome()
    }
    .disabled(model.hasStartedSession || model.hasStartedStopwatchSession)
    .opacity(model.hasStartedSession || model.hasStartedStopwatchSession ? 0.7 : 1)
  }

  private var statusText: String {
    if model.isRunning {
      if model.progress > 0.82 { return "Final stretch. Keep the thread." }
      if model.progress > 0.48 { return "Momentum is building." }
      return "One clear task. One protected block."
    }
    if model.hasStartedSession { return "Paused without losing your place." }
    return model.mode == .focus ? "Label the work, then begin." : "Rest is part of the work."
  }

  private var stopwatchStatusText: String {
    if model.isStopwatchRunning { return "Counting up. Stop & Log whenever you're done." }
    if model.hasStartedStopwatchSession { return "Paused without losing your place." }
    return "Label the work, then begin."
  }
}

struct SegmentedRow<Item: Hashable>: View {
  let items: [Item]
  let title: (Item) -> String
  let isSelected: (Item) -> Bool
  let select: (Item) -> Void

  var body: some View {
    HStack(spacing: 3) {
      ForEach(items, id: \.self) { item in
        let selected = isSelected(item)
        Button {
          select(item)
        } label: {
          Text(title(item))
            .font(CadenceType.control)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? CadencePalette.accent : Color.secondary)
        .background {
          if selected {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .fill(CadencePalette.accent.opacity(0.18))
              .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                  .stroke(CadencePalette.accent.opacity(0.45))
              }
          }
        }
      }
    }
    .padding(3)
    .background(
      CadencePalette.subtleFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(CadencePalette.hairline)
    }
  }
}

struct ModeSelector: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    SegmentedRow(
      items: TimerMode.allCases,
      title: { $0.title },
      isSelected: { model.mode == $0 },
      select: { model.selectMode($0) }
    )
    .disabled(model.hasStartedSession)
  }
}

struct KindSelector: View {
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

struct TimerDial: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    let progress = min(1, max(0, model.progress))

    ZStack {
      Circle()
        .stroke(CadencePalette.track, lineWidth: 9)

      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          CadencePalette.accent,
          style: StrokeStyle(lineWidth: 9, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .animation(.linear(duration: 0.25), value: progress)

      VStack(spacing: 6) {
        Label(model.mode.eyebrow, systemImage: model.mode.systemImage)
          .font(CadenceType.eyebrow)
          .tracking(CadenceType.eyebrowTracking)
          .foregroundStyle(.secondary)

        EditableDurationText(fontSize: 46)

        Text(model.isRunning ? "in progress" : (model.hasStartedSession ? "paused" : "ready"))
          .font(CadenceType.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(6)
  }
}

struct StopwatchDial: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    ZStack {
      Circle()
        .stroke(CadencePalette.track, lineWidth: 9)

      Circle()
        .stroke(
          model.isStopwatchRunning ? CadencePalette.accent : CadencePalette.accent.opacity(0.35),
          style: StrokeStyle(lineWidth: 9, lineCap: .round)
        )
        .animation(.linear(duration: 0.25), value: model.isStopwatchRunning)

      VStack(spacing: 6) {
        Label("STOPWATCH", systemImage: "stopwatch")
          .font(CadenceType.eyebrow)
          .tracking(CadenceType.eyebrowTracking)
          .foregroundStyle(.secondary)

        Text(model.stopwatchTimeText)
          .font(.system(size: 46, weight: .light))
          .monospacedDigit()
          .contentTransition(.numericText())

        Text(
          model.isStopwatchRunning
            ? "counting" : (model.hasStartedStopwatchSession ? "paused" : "ready")
        )
        .font(CadenceType.caption)
        .foregroundStyle(.secondary)
      }
    }
    .padding(6)
  }
}

/// A big time readout that becomes an editable minutes field when tapped,
/// as long as the Pomodoro timer hasn't started. Enter commits, Escape or
/// losing focus without a change cancels back to the normal display.
struct EditableDurationText: View {
  @EnvironmentObject private var model: AppModel
  @State private var isEditing = false
  @State private var draftText = ""
  @FocusState private var isFieldFocused: Bool
  let fontSize: CGFloat

  private var canEdit: Bool {
    !model.hasStartedSession
  }

  var body: some View {
    if isEditing {
      TextField("", text: $draftText)
        .textFieldStyle(.plain)
        .font(.system(size: fontSize, weight: .light))
        .monospacedDigit()
        .multilineTextAlignment(.center)
        .frame(width: fontSize * 3.4)
        .focused($isFieldFocused)
        .onSubmit { commit() }
        .onExitCommand { cancel() }
        .onChange(of: isFieldFocused) { _, focused in
          if !focused { cancel() }
        }
        .onAppear { isFieldFocused = true }
    } else {
      Text(model.timeText)
        .font(.system(size: fontSize, weight: .light))
        .monospacedDigit()
        .contentTransition(.numericText())
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
    guard let seconds = DurationInput.seconds(from: draftText) else {
      isFieldFocused = true
      return
    }
    model.setDuration(seconds)
    isEditing = false
  }

  private func cancel() {
    isEditing = false
  }
}

struct WeekCard: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    let report = model.weeklyReport
    let actualHours = report.totalSeconds / 3_600
    let targetProgress = min(1, report.totalSeconds / (10 * 3_600))

    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Text("THIS WEEK")
            .font(CadenceType.eyebrow)
            .tracking(CadenceType.eyebrowTracking)
            .foregroundStyle(.secondary)
          Text(String(format: "%.1f hours", actualHours))
            .font(CadenceType.figure)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 3) {
          Text("REPORTABLE")
            .font(CadenceType.eyebrow)
            .tracking(CadenceType.eyebrowTracking)
            .foregroundStyle(.secondary)
          Text(String(format: "%.2fh", report.reportableHours))
            .font(CadenceType.figure)
            .foregroundStyle(CadencePalette.accent)
        }
      }

      VStack(spacing: 6) {
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule()
              .fill(CadencePalette.track)
            Capsule()
              .fill(CadencePalette.accent)
              .frame(width: proxy.size.width * targetProgress)
          }
        }
        .frame(height: 5)
        HStack {
          Text("Weekly goal")
          Spacer()
          Text("10h")
        }
        .font(CadenceType.caption)
        .foregroundStyle(.secondary)
      }

      DailyBars()
        .frame(height: 62)

      HStack {
        Text("\(model.todaySessionCount) today")
          .font(CadenceType.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Copy weekly line") {
          model.copyWeeklyLog()
        }
        .buttonStyle(.link)
        .font(CadenceType.caption)
        .disabled(report.sessions.isEmpty)
      }
    }
    .padding(16)
    .cadenceCard()
  }
}

struct DailyBars: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    let peak = max(model.dailyActivities.map(\.seconds).max() ?? 0, 3_600)

    HStack(alignment: .bottom, spacing: 8) {
      ForEach(model.dailyActivities) { activity in
        let isToday = Calendar.current.isDate(activity.date, inSameDayAs: model.now)
        VStack(spacing: 5) {
          Spacer(minLength: 0)
          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isToday ? CadencePalette.accent : Color.primary.opacity(0.18))
            .frame(height: max(3, CGFloat(activity.seconds / peak) * 38))
          Text(activity.date, format: .dateTime.weekday(.narrow))
            .font(CadenceType.caption)
            .foregroundStyle(isToday ? CadencePalette.accent : Color.secondary)
        }
        .frame(maxWidth: .infinity)
      }
    }
  }
}

struct RecentActivityCard: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text("Recent work")
            .font(CadenceType.emphasis)
          Text("Labeled sessions stay local on this Mac")
            .font(CadenceType.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("View all") {
          model.isHistoryPresented = true
        }
        .buttonStyle(.link)
        .font(CadenceType.caption)
      }

      if model.recentSessions.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "timer")
            .font(.system(size: 22, weight: .light))
            .foregroundStyle(.tertiary)
          Text("Your first focus block will appear here.")
            .font(CadenceType.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(Array(model.recentSessions.prefix(4))) { session in
              SessionRow(session: session)
              if session.id != model.recentSessions.prefix(4).last?.id {
                Divider()
              }
            }
          }
        }
      }
    }
    .padding(16)
    .cadenceCard()
  }
}

struct SessionRow: View {
  @EnvironmentObject private var model: AppModel
  @State private var isConfirmingDelete = false
  let session: WorkSession

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: session.origin == .timer ? "timer" : "square.and.pencil")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(session.label)
          .font(CadenceType.body)
          .lineLimit(1)
        Text(
          session.note.isEmpty
            ? session.startedAt.formatted(date: .abbreviated, time: .shortened) : session.note
        )
        .font(CadenceType.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }

      Spacer(minLength: 8)

      Text(model.durationText(session.duration))
        .font(CadenceType.body)
        .monospacedDigit()
        .foregroundStyle(.secondary)

      Menu {
        Button("Delete", role: .destructive) {
          isConfirmingDelete = true
        }
      } label: {
        Image(systemName: "ellipsis")
          .foregroundStyle(.secondary)
          .frame(width: 16, height: 22)
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
    }
    .padding(.vertical, 8)
    .confirmationDialog(
      "Delete this log entry?",
      isPresented: $isConfirmingDelete,
      titleVisibility: .visible
    ) {
      Button("Delete Entry", role: .destructive) {
        model.deleteSession(id: session.id)
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("The logged time for \(session.label) will be removed.")
    }
  }
}

struct BannerView: View {
  let message: String

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "info.circle")
        .foregroundStyle(CadencePalette.accent)
      Text(message)
        .font(CadenceType.body)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 9)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(CadencePalette.hairline)
    }
    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
  }
}

struct CadencePrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(CadenceType.emphasis)
      .foregroundStyle(.white)
      .padding(.horizontal, 14)
      .frame(height: 28)
      .background(
        configuration.isPressed && isEnabled ? CadencePalette.accentDeep : CadencePalette.accent,
        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
      )
      .opacity(isEnabled ? 1 : 0.4)
  }
}

private struct CadenceCardModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(
        CadencePalette.cardFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(CadencePalette.hairline)
      }
  }
}

private struct CadenceFieldChromeModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(
        CadencePalette.subtleFill, in: RoundedRectangle(cornerRadius: 6, style: .continuous)
      )
      .overlay {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(CadencePalette.hairline)
      }
  }
}

extension View {
  func cadenceCard() -> some View {
    modifier(CadenceCardModifier())
  }

  func cadenceFieldChrome() -> some View {
    modifier(CadenceFieldChromeModifier())
  }
}
