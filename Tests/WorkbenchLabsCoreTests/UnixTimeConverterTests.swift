import XCTest
@testable import WorkbenchLabsCore

final class UnixTimeConverterTests: XCTestCase {
  func testParsesUnixSecondsAndProducesCalendarFields() throws {
    let result = try UnixTimeConverter.convert(
      input: "1715356800",
      inputKind: .unixSeconds,
      now: Date(timeIntervalSince1970: 1_715_356_800),
      localTimeZone: TimeZone(secondsFromGMT: 0)!
    )

    XCTAssertEqual(result.unixSeconds, "1715356800")
    XCTAssertEqual(result.unixMilliseconds, "1715356800000")
    XCTAssertEqual(result.utcISO8601, "2024-05-10T16:00:00Z")
    XCTAssertEqual(result.dayOfYear, "131")
    XCTAssertEqual(result.weekOfYear, "19")
    XCTAssertEqual(result.isLeapYear, "true")
  }

  func testParsesMillisecondsSinceEpoch() throws {
    let result = try UnixTimeConverter.convert(
      input: "1715356800000",
      inputKind: .unixMilliseconds,
      now: Date(timeIntervalSince1970: 1_715_356_800),
      localTimeZone: TimeZone(secondsFromGMT: 0)!
    )

    XCTAssertEqual(result.unixSeconds, "1715356800")
    XCTAssertEqual(result.unixMilliseconds, "1715356800000")
  }

  func testParsesISO8601Input() throws {
    let result = try UnixTimeConverter.convert(
      input: "2024-05-10T16:00:00Z",
      inputKind: .iso8601,
      now: Date(timeIntervalSince1970: 1_715_356_800),
      localTimeZone: TimeZone(secondsFromGMT: 0)!
    )

    XCTAssertEqual(result.unixSeconds, "1715356800")
    XCTAssertEqual(result.utcISO8601, "2024-05-10T16:00:00Z")
  }

  func testSupportsArithmeticOperatorsForNumericInputs() throws {
    let result = try UnixTimeConverter.convert(
      input: "1715356800 + 60 * 2",
      inputKind: .unixSeconds,
      now: Date(timeIntervalSince1970: 1_715_356_800),
      localTimeZone: TimeZone(secondsFromGMT: 0)!
    )

    XCTAssertEqual(result.unixSeconds, "1715356920")
  }

  func testFormatsAdditionalTimeZones() throws {
    let result = try UnixTimeConverter.convert(
      input: "1715356800",
      inputKind: .unixSeconds,
      now: Date(timeIntervalSince1970: 1_715_356_800),
      localTimeZone: TimeZone(secondsFromGMT: 0)!,
      additionalTimeZones: [TimeZone(identifier: "Asia/Jerusalem")!]
    )

    XCTAssertEqual(result.timeZones.first?.identifier, "Asia/Jerusalem")
    XCTAssertTrue(result.timeZones.first?.formatted.contains("19:00:00") == true)
  }
}
