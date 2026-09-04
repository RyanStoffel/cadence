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
    case .focus: "waveform"
    case .shortBreak: "cup.and.saucer.fill"
    case .longBreak: "sparkles"
    }
  }
}

enum CadencePalette {
  static let orange = Color(red: 0.85, green: 0.64, blue: 0.29)
  static let coral = Color(red: 0.91, green: 0.73, blue: 0.40)
  static let gold = Color(red: 1.00, green: 0.69, blue: 0.24)
}

struct MainView: View {
  @EnvironmentObject private var model: AppModel
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(nsColor: .windowBackgroundColor),
          CadencePalette.orange.opacity(colorScheme == .dark ? 0.055 : 0.025),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      VStack(spacing: 0) {
        header
        Divider().opacity(0.65)
        HStack(alignment: .top, spacing: 18) {
          FocusCard()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          VStack(spacing: 18) {
            WeekCard()
            RecentActivityCard()
              .frame(maxHeight: .infinity)
          }
          .frame(width: 390)
        }
        .padding(20)
      }

      if let message = model.bannerMessage {
        BannerView(message: message)
          .padding(20)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
          .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.bannerMessage)
    .frame(minWidth: 900, minHeight: 620)
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

  private var header: some View {
    HStack(spacing: 13) {
      ZStack {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
          .fill(
            LinearGradient(
              colors: [CadencePalette.coral, CadencePalette.orange],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
        Image(systemName: "waveform")
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.white)
      }
      .frame(width: 40, height: 40)
      .shadow(color: CadencePalette.orange.opacity(0.28), radius: 10, y: 4)

      VStack(alignment: .leading, spacing: 1) {
        Text("Cadence")
          .font(.system(size: 18, weight: .semibold, design: .rounded))
        Text("Focus timekeeper")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button {
        model.isManualEntryPresented = true
      } label: {
        Label("Add time", systemImage: "plus")
      }
      .buttonStyle(.bordered)

      Button {
        model.isHistoryPresented = true
      } label: {
        Label("Work log", systemImage: "list.bullet.rectangle")
      }
      .buttonStyle(.bordered)

      Button {
        model.exportCSV()
      } label: {
        Label("Export", systemImage: "square.and.arrow.up")
      }
      .buttonStyle(.bordered)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 14)
  }
}

struct FocusCard: View {
  @EnvironmentObject private var model: AppModel
  @State private var isConfirmingReset = false

  private var labelBinding: Binding<String> {
    Binding(get: { model.currentLabel }, set: { model.setLabel($0) })
  }

  private var noteBinding: Binding<String> {
    Binding(get: { model.currentNote }, set: { model.setNote($0) })
  }

  var body: some View {
    VStack(spacing: 17) {
      ModeSelector()

      if model.mode == .focus {
        VStack(spacing: 9) {
          HStack(spacing: 9) {
            Image(systemName: "tag.fill")
              .foregroundStyle(CadencePalette.orange)
            TextField("What are you working on?", text: labelBinding)
              .textFieldStyle(.plain)
              .font(.system(size: 15, weight: .medium))
          }
          .padding(.horizontal, 13)
          .frame(height: 42)
          .background(
            Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous)
          )
          .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .stroke(Color.primary.opacity(0.075))
          }

          HStack(spacing: 9) {
            Image(systemName: "text.alignleft")
              .foregroundStyle(.tertiary)
            TextField("Optional detail for your log", text: noteBinding)
              .textFieldStyle(.plain)
              .font(.system(size: 13))
          }
          .padding(.horizontal, 13)
          .frame(height: 38)
          .background(
            Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .disabled(model.hasStartedSession)
        .opacity(model.hasStartedSession ? 0.72 : 1)
      } else {
        HStack(spacing: 10) {
          Image(systemName: model.mode.systemImage)
            .foregroundStyle(CadencePalette.orange)
          Text(
            model.mode == .shortBreak
              ? "Step away for a moment. Your work is safe."
              : "Take a real pause and return with fresh eyes."
          )
          .foregroundStyle(.secondary)
        }
        .font(.system(size: 13, weight: .medium))
        .frame(height: 89)
      }

      TimerDial()
        .frame(width: 286, height: 286)

      HStack(spacing: 10) {
        Button {
          if model.hasStartedSession {
            isConfirmingReset = true
          } else {
            model.resetTimer()
          }
        } label: {
          Image(systemName: "arrow.counterclockwise")
            .frame(width: 18, height: 18)
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
          .frame(minWidth: 104)
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
        .font(.caption)
        .foregroundStyle(.secondary.opacity(0.78))
        .frame(height: 16)
    }
    .padding(22)
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
}

struct ModeSelector: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    HStack(spacing: 6) {
      ForEach(TimerMode.allCases, id: \.rawValue) { mode in
        Button {
          model.selectMode(mode)
        } label: {
          Text(mode.title)
            .font(.system(size: 12, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(model.mode == mode ? Color.white : Color.secondary)
        .background {
          if model.mode == mode {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
              .fill(CadencePalette.orange)
              .shadow(color: CadencePalette.orange.opacity(0.22), radius: 6, y: 2)
          }
        }
      }
    }
    .padding(4)
    .background(
      Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous)
    )
    .disabled(model.hasStartedSession)
  }
}

struct TimerDial: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    let progress = min(1, max(0, model.progress))

    ZStack {
      Circle()
        .stroke(Color.primary.opacity(0.055), lineWidth: 13)

      Circle()
        .trim(from: 0, to: progress)
        .stroke(
          AngularGradient(
            colors: [
              CadencePalette.orange, CadencePalette.gold, CadencePalette.coral,
              CadencePalette.orange,
            ],
            center: .center
          ),
          style: StrokeStyle(lineWidth: 13, lineCap: .round)
        )
        .rotationEffect(.degrees(-90))
        .shadow(color: CadencePalette.orange.opacity(model.isRunning ? 0.25 : 0.10), radius: 9)
        .animation(.linear(duration: 0.25), value: progress)

      if model.hasStartedSession {
        Circle()
          .fill(CadencePalette.gold)
          .frame(width: 10, height: 10)
          .shadow(color: CadencePalette.gold.opacity(0.8), radius: 7)
          .offset(y: -136)
          .rotationEffect(.degrees(progress * 360))
          .animation(.linear(duration: 0.25), value: progress)
      }

      VStack(spacing: 8) {
        Label(model.mode.eyebrow, systemImage: model.mode.systemImage)
          .font(.system(size: 10, weight: .bold))
          .tracking(1.3)
          .foregroundStyle(CadencePalette.orange)

        Text(model.timeText)
          .font(.system(size: 57, weight: .medium, design: .rounded))
          .monospacedDigit()
          .contentTransition(.numericText())

        Text(model.isRunning ? "in progress" : (model.hasStartedSession ? "paused" : "ready"))
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary.opacity(0.75))
      }
    }
    .padding(8)
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
        VStack(alignment: .leading, spacing: 2) {
          Text("THIS WEEK")
            .font(.system(size: 10, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(.secondary)
          Text(String(format: "%.1f hours", actualHours))
            .font(.system(size: 28, weight: .semibold, design: .rounded))
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text("REPORTABLE")
            .font(.system(size: 9, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(.secondary)
          Text(String(format: "%.2fh", report.reportableHours))
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(CadencePalette.orange)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
          CadencePalette.orange.opacity(0.09),
          in: RoundedRectangle(cornerRadius: 9, style: .continuous))
      }

      VStack(spacing: 7) {
        GeometryReader { proxy in
          ZStack(alignment: .leading) {
            Capsule()
              .fill(Color.primary.opacity(0.08))
            Capsule()
              .fill(
                LinearGradient(
                  colors: [CadencePalette.coral, CadencePalette.orange],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .frame(width: proxy.size.width * targetProgress)
          }
        }
        .frame(height: 7)
        HStack {
          Text("Weekly goal")
          Spacer()
          Text("10h")
        }
        .font(.caption2)
        .foregroundStyle(.secondary.opacity(0.72))
      }

      DailyBars()
        .frame(height: 70)

      HStack {
        Label("\(model.todaySessionCount) today", systemImage: "checkmark.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          model.copyWeeklyLog()
        } label: {
          Label("Copy weekly line", systemImage: "doc.on.doc")
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.semibold))
        .foregroundStyle(CadencePalette.orange)
        .disabled(report.sessions.isEmpty)
      }
    }
    .padding(18)
    .cadenceCard()
  }
}

struct DailyBars: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    let peak = max(model.dailyActivities.map(\.seconds).max() ?? 0, 3_600)

    HStack(alignment: .bottom, spacing: 10) {
      ForEach(model.dailyActivities) { activity in
        VStack(spacing: 5) {
          Spacer(minLength: 0)
          RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
              Calendar.current.isDate(activity.date, inSameDayAs: model.now)
                ? CadencePalette.orange : CadencePalette.orange.opacity(0.28)
            )
            .frame(height: max(4, CGFloat(activity.seconds / peak) * 43))
          Text(activity.date, format: .dateTime.weekday(.narrow))
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(
              Calendar.current.isDate(activity.date, inSameDayAs: model.now)
                ? CadencePalette.orange : Color.secondary.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
      }
    }
  }
}

struct RecentActivityCard: View {
  @EnvironmentObject private var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Recent work")
            .font(.system(size: 16, weight: .semibold))
          Text("Labeled sessions stay local on this Mac")
            .font(.caption2)
            .foregroundStyle(.secondary.opacity(0.78))
        }
        Spacer()
        Button("View all") {
          model.isHistoryPresented = true
        }
        .buttonStyle(.plain)
        .font(.caption.weight(.semibold))
        .foregroundStyle(CadencePalette.orange)
      }

      if model.recentSessions.isEmpty {
        VStack(spacing: 8) {
          Image(systemName: "waveform")
            .font(.system(size: 24, weight: .light))
            .foregroundStyle(CadencePalette.orange.opacity(0.75))
          Text("Your first focus block will appear here.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(Array(model.recentSessions.prefix(4))) { session in
              SessionRow(session: session)
              if session.id != model.recentSessions.prefix(4).last?.id {
                Divider().padding(.leading, 38)
              }
            }
          }
        }
      }
    }
    .padding(18)
    .cadenceCard()
  }
}

struct SessionRow: View {
  @EnvironmentObject private var model: AppModel
  @State private var isConfirmingDelete = false
  let session: WorkSession

  var body: some View {
    HStack(spacing: 11) {
      ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(CadencePalette.orange.opacity(0.09))
        Image(systemName: session.origin == .timer ? "timer" : "square.and.pencil")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(CadencePalette.orange)
      }
      .frame(width: 29, height: 29)

      VStack(alignment: .leading, spacing: 2) {
        Text(session.label)
          .font(.system(size: 13, weight: .medium))
          .lineLimit(1)
        Text(
          session.note.isEmpty
            ? session.startedAt.formatted(date: .abbreviated, time: .shortened) : session.note
        )
        .font(.caption2)
        .foregroundStyle(.secondary.opacity(0.76))
        .lineLimit(1)
      }

      Spacer(minLength: 8)

      Text(model.durationText(session.duration))
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)

      Menu {
        Button("Delete", role: .destructive) {
          isConfirmingDelete = true
        }
      } label: {
        Image(systemName: "ellipsis")
          .foregroundStyle(.secondary)
          .frame(width: 18, height: 24)
      }
      .menuStyle(.borderlessButton)
      .menuIndicator(.hidden)
      .fixedSize()
    }
    .padding(.vertical, 9)
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
    HStack(spacing: 9) {
      Image(systemName: "waveform")
        .foregroundStyle(CadencePalette.orange)
      Text(message)
        .font(.system(size: 12, weight: .medium))
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 11)
    .background(.ultraThickMaterial, in: Capsule())
    .overlay {
      Capsule().stroke(Color.primary.opacity(0.09))
    }
    .shadow(color: .black.opacity(0.14), radius: 16, y: 7)
  }
}

struct CadencePrimaryButtonStyle: ButtonStyle {
  @Environment(\.isEnabled) private var isEnabled

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 18)
      .frame(height: 34)
      .background(
        LinearGradient(
          colors: [CadencePalette.coral, CadencePalette.orange],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
      )
      .shadow(
        color: CadencePalette.orange.opacity(configuration.isPressed && isEnabled ? 0.12 : 0.25),
        radius: isEnabled ? 7 : 0, y: 3
      )
      .opacity(isEnabled ? 1 : 0.42)
      .saturation(isEnabled ? 1 : 0.35)
      .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1)
  }
}

private struct CadenceCardModifier: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
          .stroke(Color.primary.opacity(0.075))
      }
      .shadow(color: .black.opacity(0.055), radius: 16, y: 7)
  }
}

extension View {
  func cadenceCard() -> some View {
    modifier(CadenceCardModifier())
  }
}
