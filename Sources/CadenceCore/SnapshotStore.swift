import Foundation

public struct AppSnapshot: Codable, Equatable, Sendable {
  public var sessions: [WorkSession]
  public var timer: FocusTimer
  public var mode: TimerMode
  public var currentLabel: String
  public var currentNote: String
  public var stopwatch: Stopwatch
  public var activeKind: TimerKind

  public init(
    sessions: [WorkSession] = [],
    timer: FocusTimer = FocusTimer(duration: TimerMode.focus.defaultDuration),
    mode: TimerMode = .focus,
    currentLabel: String = "",
    currentNote: String = "",
    stopwatch: Stopwatch = Stopwatch(),
    activeKind: TimerKind = .pomodoro
  ) {
    self.sessions = sessions
    self.timer = timer
    self.mode = mode
    self.currentLabel = currentLabel
    self.currentNote = currentNote
    self.stopwatch = stopwatch
    self.activeKind = activeKind
  }

  private enum CodingKeys: String, CodingKey {
    case sessions, timer, mode, currentLabel, currentNote, stopwatch, activeKind
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    sessions = try container.decode([WorkSession].self, forKey: .sessions)
    timer = try container.decode(FocusTimer.self, forKey: .timer)
    mode = try container.decode(TimerMode.self, forKey: .mode)
    currentLabel = try container.decode(String.self, forKey: .currentLabel)
    currentNote = try container.decode(String.self, forKey: .currentNote)
    stopwatch = try container.decodeIfPresent(Stopwatch.self, forKey: .stopwatch) ?? Stopwatch()
    activeKind = try container.decodeIfPresent(TimerKind.self, forKey: .activeKind) ?? .pomodoro
  }
}

public struct SnapshotStore: Sendable {
  public let url: URL

  private var backupURL: URL {
    url.appendingPathExtension("backup")
  }

  public init(url: URL) {
    self.url = url
  }

  public func save(_ snapshot: AppSnapshot) throws {
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(snapshot)
    try data.write(to: url, options: .atomic)
    try data.write(to: backupURL, options: .atomic)
  }

  public func load() throws -> AppSnapshot? {
    let fileManager = FileManager.default
    guard fileManager.fileExists(atPath: url.path) else {
      guard fileManager.fileExists(atPath: backupURL.path) else { return nil }
      return try decode(at: backupURL)
    }

    do {
      return try decode(at: url)
    } catch {
      guard fileManager.fileExists(atPath: backupURL.path) else { throw error }
      return try decode(at: backupURL)
    }
  }

  private func decode(at url: URL) throws -> AppSnapshot {
    try JSONDecoder().decode(AppSnapshot.self, from: Data(contentsOf: url))
  }
}
