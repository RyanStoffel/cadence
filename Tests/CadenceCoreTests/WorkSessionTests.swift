import XCTest

@testable import CadenceCore

final class WorkSessionTests: XCTestCase {
  func testSessionRequiresAUsefulTrimmedLabel() {
    let start = Date(timeIntervalSince1970: 1_000)

    let blank = WorkSession(label: "  \n ", startedAt: start, duration: 1_500)
    let labeled = WorkSession(label: "  Deep work session  ", startedAt: start, duration: 1_500)

    XCTAssertNil(blank)
    XCTAssertEqual(labeled?.label, "Deep work session")
  }

  func testSessionRejectsNonpositiveDuration() {
    let start = Date(timeIntervalSince1970: 1_000)

    XCTAssertNil(WorkSession(label: "Graph schema", startedAt: start, duration: 0))
    XCTAssertNil(WorkSession(label: "Graph schema", startedAt: start, duration: -1))
  }

  func testSessionCanPreserveWallClockEndAcrossPauses() throws {
    let start = Date(timeIntervalSince1970: 1_000)
    let end = start.addingTimeInterval(2_100)

    let session = try XCTUnwrap(
      WorkSession(
        label: "Graph schema",
        startedAt: start,
        endedAt: end,
        duration: 1_500
      ))

    XCTAssertEqual(session.endedAt, end)
    XCTAssertEqual(session.duration, 1_500)
  }
}
