import XCTest

@testable import CadenceCore

final class StopwatchTests: XCTestCase {
  func testFreshStopwatchIsNotRunningWithZeroElapsed() {
    let stopwatch = Stopwatch()

    XCTAssertFalse(stopwatch.isRunning)
    XCTAssertEqual(stopwatch.elapsed(at: Date()), 0)
    XCTAssertNil(stopwatch.sessionStartedAt)
  }

  func testStartingCountsUpFromWallClockTime() {
    let start = Date(timeIntervalSince1970: 1_000)
    var stopwatch = Stopwatch()

    stopwatch.start(at: start)

    XCTAssertTrue(stopwatch.isRunning)
    XCTAssertEqual(stopwatch.elapsed(at: start.addingTimeInterval(90)), 90, accuracy: 0.001)
  }

  func testPausingFreezesElapsedTimeUntilResumed() {
    let start = Date(timeIntervalSince1970: 1_000)
    var stopwatch = Stopwatch()
    stopwatch.start(at: start)

    stopwatch.pause(at: start.addingTimeInterval(60))

    XCTAssertFalse(stopwatch.isRunning)
    XCTAssertEqual(stopwatch.elapsed(at: start.addingTimeInterval(600)), 60, accuracy: 0.001)

    stopwatch.start(at: start.addingTimeInterval(600))
    XCTAssertEqual(stopwatch.elapsed(at: start.addingTimeInterval(630)), 90, accuracy: 0.001)
  }

  func testSessionStartedAtIsPreservedAcrossAPause() {
    let start = Date(timeIntervalSince1970: 1_000)
    var stopwatch = Stopwatch()
    stopwatch.start(at: start)
    stopwatch.pause(at: start.addingTimeInterval(60))

    stopwatch.start(at: start.addingTimeInterval(600))

    XCTAssertEqual(stopwatch.sessionStartedAt, start)
  }

  func testResetClearsEverythingBackToReady() {
    let start = Date(timeIntervalSince1970: 1_000)
    var stopwatch = Stopwatch()
    stopwatch.start(at: start)
    stopwatch.pause(at: start.addingTimeInterval(60))

    stopwatch.reset()

    XCTAssertFalse(stopwatch.isRunning)
    XCTAssertNil(stopwatch.sessionStartedAt)
    XCTAssertEqual(stopwatch.elapsed(at: start.addingTimeInterval(600)), 0)
  }
}
