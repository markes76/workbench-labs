import Foundation

public enum UnixTimeInputKind: String, CaseIterable, Codable, Identifiable, Sendable {
  case unixSeconds
  case unixMilliseconds
  case iso8601

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .unixSeconds: "Unix time (seconds since epoch)"
    case .unixMilliseconds: "Milliseconds since epoch"
    case .iso8601: "ISO 8601"
    }
  }
}

public struct UnixTimeZoneResult: Equatable, Sendable {
  public var identifier: String
  public var formatted: String
}

public struct UnixTimeResult: Equatable, Sendable {
  public var date: Date
  public var local: String
  public var utcISO8601: String
  public var relative: String
  public var unixSeconds: String
  public var unixMilliseconds: String
  public var dayOfYear: String
  public var weekOfYear: String
  public var isLeapYear: String
  public var localFormats: [String]
  public var timeZones: [UnixTimeZoneResult]
}

public enum UnixTimeConverter {
  public static func convert(
    input: String,
    inputKind: UnixTimeInputKind,
    now: Date = Date(),
    localTimeZone: TimeZone = .current,
    additionalTimeZones: [TimeZone] = []
  ) throws -> UnixTimeResult {
    let date = try parse(input: input, inputKind: inputKind)
    return format(
      date: date,
      now: now,
      localTimeZone: localTimeZone,
      additionalTimeZones: additionalTimeZones
    )
  }

  public static func now(
    localTimeZone: TimeZone = .current,
    additionalTimeZones: [TimeZone] = []
  ) -> UnixTimeResult {
    let date = Date()
    return format(
      date: date,
      now: date,
      localTimeZone: localTimeZone,
      additionalTimeZones: additionalTimeZones
    )
  }

  public static func parse(input: String, inputKind: UnixTimeInputKind) throws -> Date {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { throw ToolEngineError.emptyInput }

    switch inputKind {
    case .unixSeconds:
      var expression = try ArithmeticExpression(trimmed)
      let seconds = try expression.evaluate()
      return Date(timeIntervalSince1970: seconds)
    case .unixMilliseconds:
      var expression = try ArithmeticExpression(trimmed)
      let milliseconds = try expression.evaluate()
      return Date(timeIntervalSince1970: milliseconds / 1000)
    case .iso8601:
      return try parseISO8601(trimmed)
    }
  }

  private static func format(
    date: Date,
    now: Date,
    localTimeZone: TimeZone,
    additionalTimeZones: [TimeZone]
  ) -> UnixTimeResult {
    let calendar = Calendar(identifier: .gregorian)
    var localCalendar = calendar
    localCalendar.timeZone = localTimeZone
    let year = localCalendar.component(.year, from: date)

    let seconds = Int64(date.timeIntervalSince1970.rounded(.towardZero))
    let milliseconds = Int64((date.timeIntervalSince1970 * 1000).rounded(.towardZero))

    return UnixTimeResult(
      date: date,
      local: format(date, timeZone: localTimeZone, pattern: "EEE MMM d HH:mm:ss Z yyyy"),
      utcISO8601: utcString(from: date),
      relative: relativeString(from: date, to: now),
      unixSeconds: String(seconds),
      unixMilliseconds: String(milliseconds),
      dayOfYear: String(localCalendar.ordinality(of: .day, in: .year, for: date) ?? 0),
      weekOfYear: String(localCalendar.component(.weekOfYear, from: date)),
      isLeapYear: isLeapYear(year) ? "true" : "false",
      localFormats: [
        format(date, timeZone: localTimeZone, pattern: "EEEE, MMMM d, yyyy"),
        format(date, timeZone: localTimeZone, pattern: "MM/dd/yyyy"),
        format(date, timeZone: localTimeZone, pattern: "yyyy-MM-dd"),
        format(date, timeZone: localTimeZone, pattern: "MM-dd-yyyy HH:mm"),
        format(date, timeZone: localTimeZone, pattern: "MMM d, h:mm a"),
        format(date, timeZone: localTimeZone, pattern: "MMM yyyy")
      ],
      timeZones: additionalTimeZones.map {
        UnixTimeZoneResult(identifier: $0.identifier, formatted: format(date, timeZone: $0, pattern: "HH:mm:ss EEEE d MMMM yyyy"))
      }
    )
  }

  private static func utcString(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
  }

  private static func parseISO8601(_ input: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: input) {
      return date
    }

    formatter.formatOptions = [.withInternetDateTime]
    if let date = formatter.date(from: input) {
      return date
    }

    throw ToolEngineError.invalidInput("Input is not a valid ISO 8601 date.")
  }

  private static func format(_ date: Date, timeZone: TimeZone, pattern: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = timeZone
    formatter.dateFormat = pattern
    return formatter.string(from: date)
  }

  private static func relativeString(from date: Date, to now: Date) -> String {
    let interval = date.timeIntervalSince(now)
    if abs(interval) < 1 {
      return "now"
    }

    let duration = compactDuration(abs(interval))
    return interval > 0 ? "in \(duration)" : "\(duration) ago"
  }

  private static func compactDuration(_ interval: TimeInterval) -> String {
    let seconds = Int(interval.rounded())
    let units: [(Int, String)] = [
      (31_536_000, "yr"),
      (2_592_000, "mo"),
      (604_800, "wk"),
      (86_400, "d"),
      (3_600, "h"),
      (60, "min"),
      (1, "sec")
    ]
    var remaining = seconds
    var parts: [String] = []
    for (unitSeconds, suffix) in units where remaining >= unitSeconds {
      let value = remaining / unitSeconds
      remaining %= unitSeconds
      parts.append("\(value)\(suffix)")
      if parts.count == 2 { break }
    }
    return parts.isEmpty ? "0sec" : parts.joined(separator: " ")
  }

  private static func isLeapYear(_ year: Int) -> Bool {
    (year.isMultiple(of: 4) && !year.isMultiple(of: 100)) || year.isMultiple(of: 400)
  }
}

private struct ArithmeticExpression {
  private var tokens: [Token] = []
  private var index = 0

  init(_ rawValue: String) throws {
    tokens = try Self.tokenize(rawValue)
  }

  mutating func evaluate() throws -> Double {
    let value = try parseExpression()
    guard index == tokens.count else {
      throw ToolEngineError.invalidInput("Unexpected token in timestamp expression.")
    }
    return value
  }

  private mutating func parseExpression() throws -> Double {
    var value = try parseTerm()
    while let token = current, token == .plus || token == .minus {
      index += 1
      let rhs = try parseTerm()
      value = token == .plus ? value + rhs : value - rhs
    }
    return value
  }

  private mutating func parseTerm() throws -> Double {
    var value = try parseFactor()
    while let token = current, token == .multiply || token == .divide {
      index += 1
      let rhs = try parseFactor()
      if token == .divide, rhs == 0 {
        throw ToolEngineError.invalidInput("Timestamp expression divides by zero.")
      }
      value = token == .multiply ? value * rhs : value / rhs
    }
    return value
  }

  private mutating func parseFactor() throws -> Double {
    guard let token = current else {
      throw ToolEngineError.invalidInput("Timestamp expression is incomplete.")
    }

    switch token {
    case .number(let value):
      index += 1
      return value
    case .minus:
      index += 1
      return try -parseFactor()
    case .leftParen:
      index += 1
      let value = try parseExpression()
      guard current == .rightParen else {
        throw ToolEngineError.invalidInput("Timestamp expression has an unclosed parenthesis.")
      }
      index += 1
      return value
    default:
      throw ToolEngineError.invalidInput("Timestamp expression contains an invalid operator.")
    }
  }

  private var current: Token? {
    index < tokens.count ? tokens[index] : nil
  }

  private static func tokenize(_ input: String) throws -> [Token] {
    var tokens: [Token] = []
    var index = input.startIndex

    while index < input.endIndex {
      let character = input[index]
      if character.isWhitespace {
        index = input.index(after: index)
        continue
      }

      if character.isNumber || character == "." {
        let start = index
        index = input.index(after: index)
        while index < input.endIndex, input[index].isNumber || input[index] == "." {
          index = input.index(after: index)
        }
        guard let value = Double(input[start..<index]) else {
          throw ToolEngineError.invalidInput("Timestamp expression contains an invalid number.")
        }
        tokens.append(.number(value))
        continue
      }

      switch character {
      case "+": tokens.append(.plus)
      case "-": tokens.append(.minus)
      case "*": tokens.append(.multiply)
      case "/": tokens.append(.divide)
      case "(": tokens.append(.leftParen)
      case ")": tokens.append(.rightParen)
      default:
        throw ToolEngineError.invalidInput("Only numbers and + - * / operators are supported for numeric timestamp inputs.")
      }
      index = input.index(after: index)
    }

    return tokens
  }

  private enum Token: Equatable {
    case number(Double)
    case plus
    case minus
    case multiply
    case divide
    case leftParen
    case rightParen
  }
}
