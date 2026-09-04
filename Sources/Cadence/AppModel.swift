import AppKit
import CadenceCore
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct DayActivity: Identifiable, Sendable {
  let date: Date
  let seconds: TimeInterval

  var id: Date { date }
}

@MainActor
final class AppModel: ObservableObject {
  @Published private(set) var workflow: FocusWorkflow
  @Published private(set) var now: Date
  @Published var isManualEntryPresented = false
  @Published var isHistoryPresented = false
  @Published var bannerMessage: String?

  private let store: SnapshotStore
  private var ticker: Task<Void, Never>?
  private var bannerTask: Task<Void, Never>?

  init() {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[
      0
    ]
    .appendingPathComponent("Cadence", isDirectory: true)
    #if DEBUG
      let stateURL =
        ProcessInfo.processInfo.environment["CADENCE_STATE_PATH"]
        .map { URL(fileURLWithPath: $0) } ?? support.appendingPathComponent("state.json")
    #else
      let stateURL = support.appendingPathComponent("state.json")
    #endif
    let resolvedStore = SnapshotStore(url: stateURL)
    let currentDate = Date()
    var loadMessage: String?
    var snapshot: AppSnapshot

    do {
      snapshot = try resolvedStore.load() ?? AppSnapshot()
    } catch {
      snapshot = AppSnapshot()
      loadMessage = "The saved log could not be opened. A new local log was started."
    }

    #if DEBUG
      if ProcessInfo.processInfo.environment["CADENCE_PREVIEW_DATA"] == "1",
        snapshot.sessions.isEmpty
      {
        var preview = FocusWorkflow(snapshot: snapshot)
        let entries: [(String, String, TimeInterval, TimeInterval, SessionOrigin)] = [
          ("Deep work session", "Draft the quarterly outline", -86_400, 5_400, .timer),
          ("Client proposal", "Tighten the scope and pricing", -64_800, 4_500, .timer),
          ("Design review", "Feedback pass with the team", -43_200, 2_700, .manual),
          ("Inbox cleanup", "Clear the backlog", -21_600, 6_300, .timer),
          ("Writing", "Edit the newsletter draft", -7_200, 3_600, .timer),
        ]
        for entry in entries {
          let startedAt = currentDate.addingTimeInterval(entry.2)
          if let session = WorkSession(
            label: entry.0,
            note: entry.1,
            startedAt: startedAt,
            duration: entry.3,
            origin: entry.4
          ) {
            preview.sessions.append(session)
          }
        }
        preview.currentLabel = "Deep work session"
        preview.currentNote = "Focused work block"
        snapshot = preview.snapshot
      }
    #endif

    var restoredWorkflow = FocusWorkflow(snapshot: snapshot)
    let restoredEvent = restoredWorkflow.completeIfNeeded(at: currentDate)

    self.store = resolvedStore
    self.workflow = restoredWorkflow
    self.now = currentDate
    self.bannerMessage = loadMessage

    if restoredEvent != nil {
      try? resolvedStore.save(restoredWorkflow.snapshot)
    }

    ticker = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(250))
        guard let self else { return }
        self.tick(at: Date())
      }
    }
  }

  deinit {
    ticker?.cancel()
    bannerTask?.cancel()
  }

  var timer: FocusTimer { workflow.timer }
  var mode: TimerMode { workflow.mode }
  var sessions: [WorkSession] { workflow.sessions }
  var currentLabel: String { workflow.currentLabel }
  var currentNote: String { workflow.currentNote }
  var isRunning: Bool { timer.isRunning }
  var hasStartedSession: Bool { timer.sessionStartedAt != nil }
  var stopwatch: Stopwatch { workflow.stopwatch }
  var activeKind: TimerKind { workflow.activeKind }
  var isStopwatchRunning: Bool { stopwatch.isRunning }
  var hasStartedStopwatchSession: Bool { stopwatch.sessionStartedAt != nil }

  var stopwatchElapsedSeconds: TimeInterval {
    stopwatch.elapsed(at: now)
  }

  var stopwatchTimeText: String {
    hourAwareClockText(for: stopwatchElapsedSeconds)
  }

  var remainingSeconds: TimeInterval {
    timer.remaining(at: now)
  }

  var elapsedSeconds: TimeInterval {
    max(0, timer.duration - remainingSeconds)
  }

  var progress: Double {
    guard timer.duration > 0 else { return 0 }
    return min(1, max(0, elapsedSeconds / timer.duration))
  }

  var timeText: String {
    clockText(for: remainingSeconds)
  }

  var menuBarText: String {
    isRunning ? timeText : ""
  }

  var weeklyReport: WeeklyReport {
    WeeklyReport.build(sessions: sessions, containing: now)
  }

  var todaySeconds: TimeInterval {
    sessions
      .filter { Calendar.current.isDate($0.startedAt, inSameDayAs: now) }
      .reduce(0) { $0 + $1.duration }
  }

  var todaySessionCount: Int {
    sessions.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: now) }.count
  }

  var recentSessions: [WorkSession] {
    sessions.sorted { $0.startedAt > $1.startedAt }
  }

  var recentLabels: [String] {
    var seen = Set<String>()
    return
      recentSessions
      .map(\.label)
      .filter { seen.insert($0.lowercased()).inserted }
  }

  var dailyActivities: [DayActivity] {
    let calendar = ReportingCalendar.make()
    guard let interval = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
    return (0..<7).compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else {
        return nil
      }
      let total =
        sessions
        .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
        .reduce(0) { $0 + $1.duration }
      return DayActivity(date: date, seconds: total)
    }
  }

  func setLabel(_ value: String) {
    workflow.currentLabel = value
    persist()
  }

  func setNote(_ value: String) {
    workflow.currentNote = value
    persist()
  }

  func setDuration(_ seconds: TimeInterval) {
    workflow.setDuration(seconds)
    persist()
  }

  func selectMode(_ mode: TimerMode) {
    workflow.select(mode: mode)
    persist()
  }

  func toggleTimer() {
    if isRunning {
      workflow.pause(at: now)
      persist()
      showBanner("Timer paused. Your place is saved.")
      return
    }

    guard workflow.start(at: now) else {
      showBanner("Add a clear label before starting focus.")
      return
    }

    persist()
  }

  func resetTimer() {
    guard !hasStartedSession else {
      showBanner("Choose Finish & Log or confirm that you want to discard this timer.")
      return
    }
    discardTimer()
  }

  func discardTimer() {
    workflow.select(mode: mode)
    persist()
    showBanner("Timer reset.")
  }

  func finishFocus() {
    guard let session = workflow.finishFocus(at: now) else { return }
    persist()
    celebrate("Logged \(durationText(session.duration)). Break ready.")
  }

  @discardableResult
  func addManualSession(label: String, note: String, startedAt: Date, duration: TimeInterval)
    -> Bool
  {
    guard
      let session = workflow.addManualSession(
        label: label,
        note: note,
        startedAt: startedAt,
        duration: duration
      )
    else { return false }
    persist()
    showBanner("Added \(durationText(session.duration)) to the work log.")
    return true
  }

  func deleteSession(id: UUID) {
    workflow.deleteSession(id: id)
    persist()
    showBanner("Entry removed.")
  }

  func selectKind(_ kind: TimerKind) {
    workflow.selectKind(kind)
    persist()
  }

  func toggleStopwatch() {
    if isStopwatchRunning {
      workflow.pauseStopwatch(at: now)
      persist()
      showBanner("Stopwatch paused. Your place is saved.")
      return
    }

    guard workflow.startStopwatch(at: now) else {
      showBanner("Add a clear label before starting the stopwatch.")
      return
    }

    persist()
  }

  func stopAndLogStopwatch() {
    guard let session = workflow.stopStopwatch(at: now) else { return }
    persist()
    celebrate("Logged \(durationText(session.duration)). Stopwatch reset.")
  }

  func discardStopwatch() {
    workflow.discardStopwatch()
    persist()
    showBanner("Stopwatch reset.")
  }

  func copyWeeklyLog() {
    let report = weeklyReport
    guard !report.sessions.isEmpty else {
      showBanner("There is no work to copy for this week yet.")
      return
    }
    let hours = String(format: "%.2f", report.reportableHours)
    let line = "\(hours) hours | \(report.summaryDescription)"
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(line, forType: .string)
    showBanner("Weekly log line copied.")
  }

  func exportCSV() {
    guard !sessions.isEmpty else {
      showBanner("There are no sessions to export yet.")
      return
    }

    let panel = NSSavePanel()
    panel.allowedContentTypes = [.commaSeparatedText]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = "Cadence-\(fileDateText(now)).csv"
    panel.title = "Export Work Log"

    guard panel.runModal() == .OK, let url = panel.url else { return }

    do {
      let csv = CSVExporter.make(sessions: sessions)
      try csv.write(to: url, atomically: true, encoding: .utf8)
      let written = try String(contentsOf: url, encoding: .utf8)
      guard written == csv else { throw ExportError.verificationFailed }
      showBanner("Work log exported.")
    } catch {
      showBanner("Export failed: \(error.localizedDescription)")
    }
  }

  func persistNow() {
    persist()
  }

  func presentPreviewScreenIfRequested() {
    #if DEBUG
      let screen = ProcessInfo.processInfo.environment["CADENCE_PREVIEW_SCREEN"]
      Task { @MainActor [weak self] in
        try? await Task.sleep(for: .milliseconds(150))
        switch screen {
        case "manual": self?.isManualEntryPresented = true
        case "history": self?.isHistoryPresented = true
        default: break
        }
      }
    #endif
  }

  func durationText(_ seconds: TimeInterval) -> String {
    let totalMinutes = max(1, Int((seconds / 60).rounded()))
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours == 0 { return "\(minutes)m" }
    if minutes == 0 { return "\(hours)h" }
    return "\(hours)h \(minutes)m"
  }

  private func tick(at date: Date) {
    now = date
    guard let event = workflow.completeIfNeeded(at: date) else { return }
    persist()
    switch event {
    case .focusLogged(let session):
      celebrate("Focus complete. \(durationText(session.duration)) logged.")
    case .breakFinished:
      celebrate("Break complete. Ready when you are.")
    }
  }

  private func persist() {
    do {
      try store.save(workflow.snapshot)
    } catch {
      showBanner("Could not save locally: \(error.localizedDescription)")
    }
  }

  private func celebrate(_ message: String) {
    NSSound(named: NSSound.Name("Glass"))?.play()
    NSApp.requestUserAttention(.informationalRequest)
    showBanner(message)
  }

  private func showBanner(_ message: String) {
    bannerTask?.cancel()
    bannerMessage = message
    bannerTask = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      self?.bannerMessage = nil
    }
  }

  private func clockText(for seconds: TimeInterval) -> String {
    let total = max(0, Int(ceil(seconds)))
    return String(format: "%02d:%02d", total / 60, total % 60)
  }

  private func hourAwareClockText(for seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds))
    let hours = total / 3_600
    let minutes = (total % 3_600) / 60
    let secs = total % 60
    if hours > 0 {
      return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
  }

  private func fileDateText(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}

private enum ExportError: LocalizedError {
  case verificationFailed

  var errorDescription: String? {
    "The exported file could not be verified."
  }
}
