import XCTest

@testable import CadenceCore

final class DurationInputTests: XCTestCase {
  func testConvertsEverySupportedMinuteValueToSeconds() {
    for minutes in 1...1440 {
      XCTAssertEqual(DurationInput.seconds(from: String(minutes)), Double(minutes) * 60)
    }
    XCTAssertEqual(DurationInput.seconds(from: "1"), 60)
    XCTAssertEqual(DurationInput.seconds(from: "25"), 1500)
    XCTAssertEqual(DurationInput.seconds(from: "1440"), 86400)
  }

  func testAcceptsSurroundingWhitespace() {
    XCTAssertEqual(DurationInput.seconds(from: " \t25\n"), 1500)
  }

  func testRejectsMinutesOutsideOneThrough1440() {
    for input in ["0", "-1", "1441", String(Int.max), String(Int.min), String(repeating: "9", count: 400)] {
      XCTAssertNil(DurationInput.seconds(from: input), "Input: \(input)")
    }
  }

  func testRejectsNonintegerInput() {
    for input in ["", " ", "minutes", "1.5", "25.0", "1e2", "NaN", "Infinity", "1 2"] {
      XCTAssertNil(DurationInput.seconds(from: input), "Input: \(input)")
    }
  }
}
