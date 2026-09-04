import XCTest

@testable import CadenceCore

final class SnapshotStoreTests: XCTestCase {
  func testSnapshotRoundTripsRunningTimerAndSessions() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("state.json")
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var timer = FocusTimer(duration: 1_500)
    timer.start(at: start)
    let session = try XCTUnwrap(
      WorkSession(label: "Requirements", startedAt: start.addingTimeInterval(-3_600), duration: 900)
    )
    let snapshot = AppSnapshot(
      sessions: [session],
      timer: timer,
      mode: .focus,
      currentLabel: "Design review",
      currentNote: "Resolve imports"
    )
    let store = SnapshotStore(url: url)

    try store.save(snapshot)
    let restored = try store.load()

    XCTAssertEqual(restored, snapshot)
  }

  func testCorruptPrimarySnapshotRecoversFromBackup() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("state.json")
    let snapshot = AppSnapshot(currentLabel: "GitHub ingestion")
    let store = SnapshotStore(url: url)
    try store.save(snapshot)
    try Data("not-json".utf8).write(to: url, options: .atomic)

    let restored = try store.load()

    XCTAssertEqual(restored, snapshot)
  }

  func testSnapshotRoundTripsStopwatchAndActiveKind() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("state.json")
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var stopwatch = Stopwatch()
    stopwatch.start(at: start)
    let snapshot = AppSnapshot(
      currentLabel: "Client call",
      stopwatch: stopwatch,
      activeKind: .stopwatch
    )
    let store = SnapshotStore(url: url)

    try store.save(snapshot)
    let restored = try store.load()

    XCTAssertEqual(restored, snapshot)
  }

  func testOldFormatSnapshotWithoutStopwatchFieldsStillDecodes() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    let url = directory.appendingPathComponent("state.json")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let legacyJSON = """
      {
        "sessions": [],
        "timer": {
          "duration": 1500,
          "remainingWhenPaused": 1500
        },
        "mode": "focus",
        "currentLabel": "Legacy label",
        "currentNote": ""
      }
      """
    try Data(legacyJSON.utf8).write(to: url, options: .atomic)
    let store = SnapshotStore(url: url)

    let restored = try store.load()

    XCTAssertEqual(restored?.currentLabel, "Legacy label")
    XCTAssertEqual(restored?.activeKind, .pomodoro)
    XCTAssertEqual(restored?.stopwatch, Stopwatch())
  }
}
