import XCTest

@testable import CadenceCore

final class CSVExporterTests: XCTestCase {
  func testCSVExportIsChronologicalAndEscapesUserText() throws {
    let later = Date(timeIntervalSince1970: 1_788_428_700)
    let earlier = later.addingTimeInterval(-3_600)
    let second = try XCTUnwrap(
      WorkSession(
        label: "Graph, schema", note: "Reviewed \"decision\" nodes", startedAt: later,
        duration: 1_500))
    let first = try XCTUnwrap(
      WorkSession(label: "Proposal", startedAt: earlier, duration: 900, origin: .manual))

    let csv = CSVExporter.make(sessions: [second, first], timeZone: TimeZone(secondsFromGMT: 0)!)
    let lines = csv.split(separator: "\n", omittingEmptySubsequences: false)

    XCTAssertEqual(lines.first, "Date,Start,End,Hours,Label,Notes,Source")
    XCTAssertTrue(lines[1].contains(",0.25,Proposal,,Manual"))
    XCTAssertTrue(
      lines[2].contains(",0.42,\"Graph, schema\",\"Reviewed \"\"decision\"\" nodes\",Timer"))
  }
}
