import Foundation

public enum ReportingCalendar {
  public static func make(timeZone: TimeZone = .current) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar
  }
}

public struct WeeklyReport: Equatable, Sendable {
  public let interval: DateInterval
  public let sessions: [WorkSession]
  public let totalSeconds: TimeInterval
  public let reportableHours: Double

  public var summaryDescription: String {
    var seen = Set<String>()
    return
      sessions
      .map(\.label)
      .filter { seen.insert($0.lowercased()).inserted }
      .joined(separator: "; ")
  }

  public static func build(
    sessions: [WorkSession],
    containing date: Date,
    calendar: Calendar = ReportingCalendar.make()
  ) -> WeeklyReport {
    let interval =
      calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 0)
    let included =
      sessions
      .filter { interval.contains($0.startedAt) }
      .sorted { $0.startedAt < $1.startedAt }
    let totalSeconds = included.reduce(0) { $0 + $1.duration }
    let reportableHours = (totalSeconds / 3_600 * 4).rounded() / 4
    return WeeklyReport(
      interval: interval,
      sessions: included,
      totalSeconds: totalSeconds,
      reportableHours: reportableHours
    )
  }
}
