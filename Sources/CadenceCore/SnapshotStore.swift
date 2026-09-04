import Foundation

public struct AppSnapshot: Codable, Equatable, Sendable {
  public var sessions: [WorkSession]
  public var timer: FocusTimer
  public var mode: TimerMode
  public var currentLabel: String
  public var currentNote: String

  public init(
    sessions: [WorkSession] = [],
    timer: FocusTimer = FocusTimer(duration: TimerMode.focus.defaultDuration),
    mode: TimerMode = .focus,
    currentLabel: String = "",
    currentNote: String = ""
  ) {
    self.sessions = sessions
    self.timer = timer
    self.mode = mode
    self.currentLabel = currentLabel
    self.currentNote = currentNote
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
