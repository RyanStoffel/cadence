import XCTest

@testable import CadenceCore

final class FocusWorkflowTests: XCTestCase {
  func testFocusTimerStartsOnlyWithALabel() {
    let now = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()

    XCTAssertFalse(workflow.start(at: now))
    XCTAssertFalse(workflow.timer.isRunning)

    workflow.currentLabel = "Deep work session"
    XCTAssertTrue(workflow.start(at: now))
    XCTAssertTrue(workflow.timer.isRunning)
  }

  func testSelectingAModeResetsTheTimerToItsPreset() {
    let now = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.currentLabel = "Deep work session"
    workflow.start(at: now)

    workflow.select(mode: .shortBreak)

    XCTAssertEqual(workflow.mode, .shortBreak)
    XCTAssertEqual(workflow.timer.duration, 300)
    XCTAssertFalse(workflow.timer.isRunning)
  }

  func testCompletingFocusLogsWorkAndPreparesAShortBreak() throws {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.currentLabel = "Deep work session"
    workflow.currentNote = "Model decision edges"
    workflow.start(at: start)

    let event = workflow.completeIfNeeded(at: start.addingTimeInterval(1_500))

    guard case .focusLogged(let session) = event else {
      return XCTFail("Expected a logged focus session")
    }
    XCTAssertEqual(session.label, "Deep work session")
    XCTAssertEqual(session.note, "Model decision edges")
    XCTAssertEqual(session.duration, 1_500)
    XCTAssertEqual(workflow.sessions, [session])
    XCTAssertEqual(workflow.mode, .shortBreak)
    XCTAssertEqual(workflow.timer.duration, 300)
    XCTAssertFalse(workflow.timer.isRunning)
  }

  func testCompletingBreakReturnsToFocusWithoutLoggingTime() {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.select(mode: .shortBreak)
    workflow.start(at: start)

    let event = workflow.completeIfNeeded(at: start.addingTimeInterval(300))

    XCTAssertEqual(event, .breakFinished)
    XCTAssertTrue(workflow.sessions.isEmpty)
    XCTAssertEqual(workflow.mode, .focus)
    XCTAssertEqual(workflow.timer.duration, 1_500)
  }

  func testLateCompletionUsesTheScheduledEndTime() {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.currentLabel = "Deep work session"
    workflow.start(at: start)

    let event = workflow.completeIfNeeded(at: start.addingTimeInterval(3_600))

    guard case .focusLogged(let session) = event else {
      return XCTFail("Expected a logged focus session")
    }
    XCTAssertEqual(session.endedAt, start.addingTimeInterval(1_500))
  }

  func testFinishingEarlyLogsOnlyActiveFocusTime() throws {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.currentLabel = "Design review"
    workflow.start(at: start)
    workflow.pause(at: start.addingTimeInterval(600))

    let session = try XCTUnwrap(workflow.finishFocus(at: start.addingTimeInterval(900)))

    XCTAssertEqual(session.duration, 600, accuracy: 0.001)
    XCTAssertEqual(session.endedAt, start.addingTimeInterval(900))
    XCTAssertEqual(workflow.sessions, [session])
    XCTAssertEqual(workflow.mode, .shortBreak)
  }

  func testManualEntryIsValidatedAndAddedToTheLog() throws {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()

    XCTAssertNil(workflow.addManualSession(label: " ", note: "", startedAt: start, duration: 900))
    let session = try XCTUnwrap(
      workflow.addManualSession(
        label: "Client meeting",
        note: "Requirements review",
        startedAt: start,
        duration: 2_700
      ))

    XCTAssertEqual(session.origin, .manual)
    XCTAssertEqual(workflow.sessions, [session])
  }

  func testDeletingASessionRemovesOnlyThatEntry() throws {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    let keep = try XCTUnwrap(WorkSession(label: "Keep", startedAt: start, duration: 900))
    let remove = try XCTUnwrap(WorkSession(label: "Remove", startedAt: start, duration: 900))
    var workflow = FocusWorkflow(snapshot: AppSnapshot(sessions: [keep, remove]))

    workflow.deleteSession(id: remove.id)

    XCTAssertEqual(workflow.sessions, [keep])
  }

  func testSetDurationUpdatesTheTimerBeforeStarting() {
    var workflow = FocusWorkflow()

    workflow.setDuration(900)

    XCTAssertEqual(workflow.timer.duration, 900)
  }

  func testSetDurationIsIgnoredOnceASessionHasStarted() {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.currentLabel = "Deep work session"
    workflow.start(at: start)
    workflow.pause(at: start.addingTimeInterval(60))

    workflow.setDuration(900)

    XCTAssertEqual(workflow.timer.duration, 1_500)
  }

  func testStopwatchStartsOnlyWithALabel() {
    let now = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()

    XCTAssertFalse(workflow.startStopwatch(at: now))
    XCTAssertFalse(workflow.stopwatch.isRunning)

    workflow.currentLabel = "Client call"
    XCTAssertTrue(workflow.startStopwatch(at: now))
    XCTAssertTrue(workflow.stopwatch.isRunning)
  }

  func testPausingStopwatchFreezesElapsedTime() {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.currentLabel = "Client call"
    workflow.startStopwatch(at: start)

    workflow.pauseStopwatch(at: start.addingTimeInterval(60))

    XCTAssertFalse(workflow.stopwatch.isRunning)
    XCTAssertEqual(
      workflow.stopwatch.elapsed(at: start.addingTimeInterval(600)), 60, accuracy: 0.001)
  }

  func testStoppingStopwatchLogsASessionAndResetsToZero() throws {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.currentLabel = "Client call"
    workflow.currentNote = "Walk through the proposal"
    workflow.startStopwatch(at: start)

    let session = try XCTUnwrap(workflow.stopStopwatch(at: start.addingTimeInterval(300)))

    XCTAssertEqual(session.label, "Client call")
    XCTAssertEqual(session.note, "Walk through the proposal")
    XCTAssertEqual(session.duration, 300, accuracy: 0.001)
    XCTAssertEqual(session.origin, .timer)
    XCTAssertEqual(workflow.sessions, [session])
    XCTAssertFalse(workflow.stopwatch.isRunning)
    XCTAssertEqual(workflow.stopwatch.elapsed(at: start.addingTimeInterval(900)), 0)
  }

  func testStoppingAZeroDurationStopwatchDoesNotLogASession() {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.currentLabel = "Client call"
    workflow.startStopwatch(at: start)

    let session = workflow.stopStopwatch(at: start)

    XCTAssertNil(session)
    XCTAssertTrue(workflow.sessions.isEmpty)
  }

  func testDiscardingStopwatchClearsItWithoutLoggingASession() {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.currentLabel = "Client call"
    workflow.startStopwatch(at: start)
    workflow.pauseStopwatch(at: start.addingTimeInterval(120))

    workflow.discardStopwatch()

    XCTAssertTrue(workflow.sessions.isEmpty)
    XCTAssertFalse(workflow.stopwatch.isRunning)
    XCTAssertEqual(workflow.stopwatch.elapsed(at: start.addingTimeInterval(900)), 0)
  }

  func testPomodoroAndStopwatchStateAreIndependent() {
    let start = Date(timeIntervalSince1970: 1_788_000_000)
    var workflow = FocusWorkflow()
    workflow.currentLabel = "Deep work session"
    workflow.start(at: start)

    workflow.selectKind(.stopwatch)
    workflow.startStopwatch(at: start.addingTimeInterval(60))
    workflow.pauseStopwatch(at: start.addingTimeInterval(120))

    XCTAssertTrue(workflow.timer.isRunning)
    XCTAssertEqual(
      workflow.timer.remaining(at: start.addingTimeInterval(120)), 1_380, accuracy: 0.001)
    XCTAssertEqual(workflow.activeKind, .stopwatch)
  }
}
