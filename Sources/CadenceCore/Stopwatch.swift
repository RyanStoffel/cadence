import Foundation

public enum TimerKind: String, Codable, CaseIterable, Sendable {
  case pomodoro
  case stopwatch
}

public struct Stopwatch: Codable, Equatable, Sendable {
  public private(set) var startedAt: Date?
  public private(set) var sessionStartedAt: Date?
  public private(set) var accumulated: TimeInterval

  public var isRunning: Bool {
    startedAt != nil
  }

  public init() {
    self.startedAt = nil
    self.sessionStartedAt = nil
    self.accumulated = 0
  }

  public mutating func start(at date: Date) {
    guard startedAt == nil else { return }
    startedAt = date
    sessionStartedAt = sessionStartedAt ?? date
  }

  public mutating func pause(at date: Date) {
    guard startedAt != nil else { return }
    accumulated = elapsed(at: date)
    startedAt = nil
  }

  public mutating func reset() {
    startedAt = nil
    sessionStartedAt = nil
    accumulated = 0
  }

  public func elapsed(at date: Date) -> TimeInterval {
    guard let startedAt else { return accumulated }
    return accumulated + max(0, date.timeIntervalSince(startedAt))
  }
}
