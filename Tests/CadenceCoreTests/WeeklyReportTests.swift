import XCTest

@testable import CadenceCore

final class WeeklyReportTests: XCTestCase {
  func testReportingCalendarStartsWeeksOnMonday() throws {
    let timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    let calendar = ReportingCalendar.make(timeZone: timeZone)
    let sunday = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 9, day: 6, hour: 12)))
    let interval = try XCTUnwrap(calendar.dateInterval(of: .weekOfYear, for: sunday))

    XCTAssertEqual(calendar.component(.weekday, from: interval.start), 2)
    XCTAssertEqual(calendar.component(.day, from: interval.start), 31)
  }

  func testWeeklyReportFiltersSessionsAndRoundsToNearestQuarterHour() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    let reference = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 12)))
    let earlier = try XCTUnwrap(calendar.date(byAdding: .day, value: -9, to: reference))
    let first = try XCTUnwrap(
      WorkSession(label: "Graph schema", startedAt: reference, duration: 3_600))
    let second = try XCTUnwrap(
      WorkSession(
        label: "Webhook adapter", startedAt: reference.addingTimeInterval(3_700), duration: 450))
    let outside = try XCTUnwrap(WorkSession(label: "Proposal", startedAt: earlier, duration: 7_200))

    let report = WeeklyReport.build(
      sessions: [outside, first, second], containing: reference, calendar: calendar)

    XCTAssertEqual(report.totalSeconds, 4_050, accuracy: 0.001)
    XCTAssertEqual(report.reportableHours, 1.25, accuracy: 0.001)
    XCTAssertEqual(report.sessions.map(\.label), ["Graph schema", "Webhook adapter"])
  }

  func testWeeklySummaryDescriptionListsEachLabelOnce() throws {
    let start = Date(timeIntervalSince1970: 1_786_000_000)
    let first = try XCTUnwrap(WorkSession(label: "Graph schema", startedAt: start, duration: 900))
    let repeated = try XCTUnwrap(
      WorkSession(label: "Graph schema", startedAt: start.addingTimeInterval(1_000), duration: 900))
    let second = try XCTUnwrap(
      WorkSession(
        label: "Webhook adapter", startedAt: start.addingTimeInterval(2_000), duration: 900))

    let report = WeeklyReport.build(sessions: [first, repeated, second], containing: start)

    XCTAssertEqual(report.summaryDescription, "Graph schema; Webhook adapter")
  }
}
