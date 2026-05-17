import Foundation

public enum EnvInspector {
  public static func run(input: String, options: ToolOptions) -> ToolResult {
    let operation = options.operation.isEmpty ? "inspect" : options.operation
    let primary = parse(input)
    let showValues = options.boolValues["showValues"] ?? false

    switch operation {
    case "compare":
      let secondary = parse(options.secondaryInput)
      return compare(primary, secondary, showValues: showValues)
    case "redact":
      return redact(input)
    default:
      return inspect(primary, showValues: showValues)
    }
  }

  private static func inspect(_ document: EnvDocument, showValues: Bool) -> ToolResult {
    var lines = [
      ".env Inspect",
      "\(document.entries.count) keys",
      "\(document.duplicateKeys.count) duplicate keys",
      "\(document.invalidLines.count) invalid lines",
      ""
    ]

    if !document.entries.isEmpty {
      lines.append("Keys:")
      lines += document.entries.map { entry in
        let value = showValues ? displayValue(entry.value) : redactedValue(for: entry)
        return "- \(entry.key)=\(value)\(entry.isSecretLike ? "  secret-like" : "")"
      }
    }

    if !document.duplicateKeys.isEmpty {
      lines.append("")
      lines.append("Duplicate keys: \(document.duplicateKeys.sorted().joined(separator: ", "))")
    }

    if !document.invalidLines.isEmpty {
      lines.append("")
      lines.append("Invalid lines:")
      lines += document.invalidLines.map { "- line \($0.lineNumber): \($0.content)" }
    }

    return ToolResult(output: lines.joined(separator: "\n"), metadata: [
      "keyCount": "\(document.entries.count)",
      "duplicateCount": "\(document.duplicateKeys.count)",
      "invalidLineCount": "\(document.invalidLines.count)"
    ])
  }

  private static func compare(_ left: EnvDocument, _ right: EnvDocument, showValues: Bool) -> ToolResult {
    let leftMap = left.lastValuesByKey
    let rightMap = right.lastValuesByKey
    let leftKeys = Set(leftMap.keys)
    let rightKeys = Set(rightMap.keys)
    let added = rightKeys.subtracting(leftKeys).sorted()
    let removed = leftKeys.subtracting(rightKeys).sorted()
    let changed = leftKeys.intersection(rightKeys)
      .filter { leftMap[$0] != rightMap[$0] }
      .sorted()
    let unchanged = leftKeys.intersection(rightKeys)
      .filter { leftMap[$0] == rightMap[$0] }
      .sorted()

    var lines = [
      ".env Compare",
      "Left keys: \(leftKeys.count)",
      "Right keys: \(rightKeys.count)",
      "",
      "Changed keys: \(list(changed))",
      "Removed keys: \(list(removed))",
      "Added keys: \(list(added))",
      "Missing in right: \(list(removed))",
      "Missing in left: \(list(added))",
      "Unchanged keys: \(list(unchanged))"
    ]

    if showValues, !changed.isEmpty {
      lines.append("")
      lines.append("Changed values:")
      lines += changed.map { key in
        "- \(key): \(displayValue(leftMap[key] ?? "")) -> \(displayValue(rightMap[key] ?? ""))"
      }
    }

    return ToolResult(output: lines.joined(separator: "\n"), metadata: [
      "addedCount": "\(added.count)",
      "removedCount": "\(removed.count)",
      "changedCount": "\(changed.count)",
      "unchangedCount": "\(unchanged.count)"
    ])
  }

  private static func redact(_ input: String) -> ToolResult {
    let lines = input.split(separator: "\n", omittingEmptySubsequences: false)
    let redacted = lines.map { rawLine -> String in
      let line = String(rawLine)
      guard let parsed = parseLine(line, lineNumber: 0)?.entry else {
        return line
      }
      let exportPrefix = parsed.hasExportPrefix ? "export " : ""
      return "\(exportPrefix)\(parsed.key)=<redacted>"
    }.joined(separator: "\n")

    let document = parse(input)
    return ToolResult(output: redacted, metadata: ["keyCount": "\(document.entries.count)"])
  }

  private static func parse(_ input: String) -> EnvDocument {
    var entries: [EnvEntry] = []
    var invalidLines: [InvalidEnvLine] = []

    for (index, rawLine) in input.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
      let line = String(rawLine)
      guard let parsed = parseLine(line, lineNumber: index + 1) else { continue }
      if let entry = parsed.entry {
        entries.append(entry)
      } else if let invalid = parsed.invalid {
        invalidLines.append(invalid)
      }
    }

    let counts = Dictionary(grouping: entries, by: \.key).mapValues(\.count)
    let duplicateKeys = Set(counts.filter { $0.value > 1 }.keys)
    return EnvDocument(entries: entries, invalidLines: invalidLines, duplicateKeys: duplicateKeys)
  }

  private static func parseLine(_ line: String, lineNumber: Int) -> ParsedLine? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }

    var working = trimmed
    var hasExportPrefix = false
    if working.hasPrefix("export ") {
      hasExportPrefix = true
      working = String(working.dropFirst("export ".count)).trimmingCharacters(in: .whitespaces)
    }

    guard let equalsIndex = working.firstIndex(of: "=") else {
      return ParsedLine(entry: nil, invalid: InvalidEnvLine(lineNumber: lineNumber, content: line))
    }

    let key = working[..<equalsIndex].trimmingCharacters(in: .whitespaces)
    let valuePart = working[working.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)
    guard key.range(of: #"^[A-Za-z_][A-Za-z0-9_]*$"#, options: .regularExpression) != nil else {
      return ParsedLine(entry: nil, invalid: InvalidEnvLine(lineNumber: lineNumber, content: line))
    }

    let value = unquote(String(valuePart))
    return ParsedLine(
      entry: EnvEntry(
        key: String(key),
        value: value,
        lineNumber: lineNumber,
        hasExportPrefix: hasExportPrefix
      ),
      invalid: nil
    )
  }

  private static func unquote(_ value: String) -> String {
    guard value.count >= 2 else { return value }
    if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
      return String(value.dropFirst().dropLast())
    }
    if let commentIndex = value.firstIndex(of: "#") {
      let beforeComment = value[..<commentIndex].trimmingCharacters(in: .whitespaces)
      return String(beforeComment)
    }
    return value
  }

  private static func redactedValue(for entry: EnvEntry) -> String {
    entry.value.isEmpty ? "<empty>" : "<redacted>"
  }

  private static func displayValue(_ value: String) -> String {
    value.isEmpty ? "<empty>" : value
  }

  private static func list(_ keys: [String]) -> String {
    keys.isEmpty ? "none" : keys.joined(separator: ", ")
  }
}

private struct EnvDocument {
  var entries: [EnvEntry]
  var invalidLines: [InvalidEnvLine]
  var duplicateKeys: Set<String>

  var lastValuesByKey: [String: String] {
    entries.reduce(into: [:]) { result, entry in
      result[entry.key] = entry.value
    }
  }
}

private struct EnvEntry {
  var key: String
  var value: String
  var lineNumber: Int
  var hasExportPrefix: Bool

  var isSecretLike: Bool {
    let secretKeyPattern = #"(?i)(secret|token|key|password|passwd|pwd|credential|private|client_secret|database_url)"#
    return key.range(of: secretKeyPattern, options: .regularExpression) != nil ||
      value.range(of: #"(?i)(bearer\s+[a-z0-9._-]+|sk-[a-z0-9_-]{8,}|gh[pousr]_[a-z0-9_]+)"#, options: .regularExpression) != nil
  }
}

private struct InvalidEnvLine {
  var lineNumber: Int
  var content: String
}

private struct ParsedLine {
  var entry: EnvEntry?
  var invalid: InvalidEnvLine?
}
