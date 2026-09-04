import Foundation

public enum CompletionEvent: Equatable, Sendable {
  case focusLogged(WorkSession)
  case breakFinished
}

public struct FocusWorkflow: Equatable, Sendable {
  public var sessions: [WorkSession]
  public private(set) var timer: FocusTimer
  public private(set) var mode: TimerMode
  public var currentLabel: String
  public var currentNote: String

  public init(snapshot: AppSnapshot = AppSnapshot()) {
    self.sessions = snapshot.sessions
    self.timer = snapshot.timer
    self.mode = snapshot.mode
    self.currentLabel = snapshot.currentLabel
    self.currentNote = snapshot.currentNote
  }

  public var snapshot: AppSnapshot {
    AppSnapshot(
      sessions: sessions,
      timer: timer,
      mode: mode,
      currentLabel: currentLabel,
      currentNote: currentNote
    )
  }

  @discardableResult
  public mutating func start(at date: Date) -> Bool {
    if mode == .focus && currentLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return false
    }
    timer.start(at: date)
    return timer.isRunning
  }

  public mutating func pause(at date: Date) {
    timer.pause(at: date)
  }

  public mutating func select(mode: TimerMode) {
    self.mode = mode
    timer.reset(to: mode.defaultDuration)
  }

  public mutating func setDuration(_ duration: TimeInterval) {
    guard timer.sessionStartedAt == nil else { return }
    timer.setDuration(duration)
  }

  public mutating func completeIfNeeded(at date: Date) -> CompletionEvent? {
    guard timer.isRunning, timer.remaining(at: date) <= 0 else { return nil }
    if mode != .focus {
      select(mode: .focus)
      return .breakFinished
    }
    let endedAt = timer.expectedEndDate ?? date
    guard let startedAt = timer.sessionStartedAt,
      let session = WorkSession(
        label: currentLabel,
        note: currentNote,
        startedAt: startedAt,
        endedAt: endedAt,
        duration: timer.duration
      )
    else { return nil }
    sessions.append(session)
    select(mode: .shortBreak)
    return .focusLogged(session)
  }

  @discardableResult
  public mutating func finishFocus(at date: Date) -> WorkSession? {
    guard mode == .focus,
      let startedAt = timer.sessionStartedAt
    else { return nil }
    let elapsed = timer.duration - timer.remaining(at: date)
    guard
      let session = WorkSession(
        label: currentLabel,
        note: currentNote,
        startedAt: startedAt,
        endedAt: date,
        duration: elapsed
      )
    else { return nil }
    sessions.append(session)
    select(mode: .shortBreak)
    return session
  }

  @discardableResult
  public mutating func addManualSession(
    label: String,
    note: String,
    startedAt: Date,
    duration: TimeInterval
  ) -> WorkSession? {
    guard
      let session = WorkSession(
        label: label,
        note: note,
        startedAt: startedAt,
        duration: duration,
        origin: .manual
      )
    else { return nil }
    sessions.append(session)
    return session
  }

  public mutating func deleteSession(id: UUID) {
    sessions.removeAll { $0.id == id }
  }
}
