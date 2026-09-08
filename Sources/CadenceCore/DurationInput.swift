import Foundation

public enum DurationInput {
  public static func seconds(from text: String) -> TimeInterval? {
    guard let minutes = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
      (1...1440).contains(minutes)
    else {
      return nil
    }
    return Double(minutes) * 60
  }
}
