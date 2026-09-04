import XCTest

@testable import CadenceCore

final class FocusTimerTests: XCTestCase {
  func testTimerModesUsePomodoroDefaults() {
    XCTAssertEqual(TimerMode.focus.defaultDuration, 25 * 60)
    XCTAssertEqual(TimerMode.shortBreak.defaultDuration, 5 * 60)
    XCTAssertEqual(TimerMode.longBreak.defaultDuration, 15 * 60)
  }

  func testRunningTimerUsesElapsedWallClockTime() {
    let start = Date(timeIntervalSince1970: 1_000)
    var timer = FocusTimer(duration: 1_500)

    timer.start(at: start)

    XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(90)), 1_410, accuracy: 0.001)
  }

  func testPausingFreezesTimerUntilRestarted() {
    let start = Date(timeIntervalSince1970: 1_000)
    var timer = FocusTimer(duration: 1_500)
    timer.start(at: start)

    timer.pause(at: start.addingTimeInterval(60))

    XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(600)), 1_440, accuracy: 0.001)

    timer.start(at: start.addingTimeInterval(600))
    XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(630)), 1_410, accuracy: 0.001)
  }

  func testResetRestoresAStoppedTimerWithTheNewDuration() {
    let start = Date(timeIntervalSince1970: 1_000)
    var timer = FocusTimer(duration: 1_500)
    timer.start(at: start)

    timer.reset(to: 300)

    XCTAssertEqual(timer.duration, 300)
    XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(60)), 300)
    XCTAssertFalse(timer.isRunning)
  }

  func testTimerPreservesOriginalSessionStartAcrossAPause() {
    let start = Date(timeIntervalSince1970: 1_000)
    var timer = FocusTimer(duration: 1_500)
    timer.start(at: start)
    timer.pause(at: start.addingTimeInterval(60))

    timer.start(at: start.addingTimeInterval(600))

    XCTAssertEqual(timer.sessionStartedAt, start)
  }

  func testSetDurationUpdatesAStoppedTimerAndItsRemainingTime() {
    var timer = FocusTimer(duration: 1_500)

    timer.setDuration(900)

    XCTAssertEqual(timer.duration, 900)
    XCTAssertEqual(timer.remaining(at: Date()), 900)
    XCTAssertFalse(timer.isRunning)
  }

  func testSetDurationIsIgnoredWhileTheTimerIsRunning() {
    let start = Date(timeIntervalSince1970: 1_000)
    var timer = FocusTimer(duration: 1_500)
    timer.start(at: start)

    timer.setDuration(900)

    XCTAssertEqual(timer.duration, 1_500)
    XCTAssertEqual(timer.remaining(at: start), 1_500)
  }

  func testSetDurationClampsToAtLeastOneMinute() {
    var timer = FocusTimer(duration: 1_500)

    timer.setDuration(10)

    XCTAssertEqual(timer.duration, 60)
    XCTAssertEqual(timer.remaining(at: Date()), 60)
  }
}
