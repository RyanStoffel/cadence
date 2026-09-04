import Foundation

public enum TimerMode: String, Codable, CaseIterable, Sendable {
  case focus
  case shortBreak
  case longBreak

  public var defaultDuration: TimeInterval {
    switch self {
    case .focus: 25 * 60
    case .shortBreak: 5 * 60
    case .longBreak: 15 * 60
    }
  }
}

public struct FocusTimer: Codable, Equatable, Sendable {
  public private(set) var duration: TimeInterval
  public private(set) var startedAt: Date?
  public private(set) var sessionStartedAt: Date?
  public private(set) var remainingWhenPaused: TimeInterval

  public var isRunning: Bool {
    startedAt != nil
  }

  public var expectedEndDate: Date? {
    startedAt?.addingTimeInterval(remainingWhenPaused)
  }

  public init(duration: TimeInterval) {
    self.duration = duration
    self.startedAt = nil
    self.sessionStartedAt = nil
    self.remainingWhenPaused = duration
  }

  public mutating func start(at date: Date) {
    guard startedAt == nil, remainingWhenPaused > 0 else { return }
    startedAt = date
    sessionStartedAt = sessionStartedAt ?? date
  }

  public mutating func pause(at date: Date) {
    guard startedAt != nil else { return }
    remainingWhenPaused = remaining(at: date)
    startedAt = nil
  }

  public mutating func reset(to duration: TimeInterval) {
    self.duration = duration
    startedAt = nil
    sessionStartedAt = nil
    remainingWhenPaused = duration
  }

  public mutating func setDuration(_ duration: TimeInterval) {
    guard !isRunning else { return }
    let clamped = max(60, duration)
    self.duration = clamped
    remainingWhenPaused = clamped
  }

  public func remaining(at date: Date) -> TimeInterval {
    guard let startedAt else { return remainingWhenPaused }
    return max(0, remainingWhenPaused - date.timeIntervalSince(startedAt))
  }
}
