import Foundation

public enum CSVExporter {
  public static func make(sessions: [WorkSession], timeZone: TimeZone = .current) -> String {
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .gregorian)
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = timeZone
    dateFormatter.dateFormat = "yyyy-MM-dd"

    let timeFormatter = DateFormatter()
    timeFormatter.calendar = Calendar(identifier: .gregorian)
    timeFormatter.locale = Locale(identifier: "en_US_POSIX")
    timeFormatter.timeZone = timeZone
    timeFormatter.dateFormat = "HH:mm"

    let rows =
      sessions
      .sorted { $0.startedAt < $1.startedAt }
      .map { session in
        [
          dateFormatter.string(from: session.startedAt),
          timeFormatter.string(from: session.startedAt),
          timeFormatter.string(from: session.endedAt),
          String(
            format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), session.duration / 3_600),
          session.label,
          session.note,
          session.origin == .timer ? "Timer" : "Manual",
        ]
        .map(escaped)
        .joined(separator: ",")
      }

    return (["Date,Start,End,Hours,Label,Notes,Source"] + rows).joined(separator: "\n") + "\n"
  }

  private static func escaped(_ value: String) -> String {
    guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
    return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
  }
}
