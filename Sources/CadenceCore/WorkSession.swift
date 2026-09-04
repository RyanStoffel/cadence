import Foundation

public enum SessionOrigin: String, Codable, CaseIterable, Sendable {
  case timer
  case manual
}

public struct WorkSession: Identifiable, Codable, Hashable, Sendable {
  public let id: UUID
  public var label: String
  public var note: String
  public var startedAt: Date
  public var endedAt: Date
  public var duration: TimeInterval
  public var origin: SessionOrigin

  public init?(
    id: UUID = UUID(),
    label: String,
    note: String = "",
    startedAt: Date,
    endedAt: Date? = nil,
    duration: TimeInterval,
    origin: SessionOrigin = .timer
  ) {
    let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanLabel.isEmpty, duration > 0 else { return nil }
    self.id = id
    self.label = cleanLabel
    self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    self.startedAt = startedAt
    self.endedAt = endedAt ?? startedAt.addingTimeInterval(duration)
    self.duration = duration
    self.origin = origin
  }
}
