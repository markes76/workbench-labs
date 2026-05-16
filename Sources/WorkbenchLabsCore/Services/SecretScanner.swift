import Foundation

public enum SecretScanner {
  public struct Finding: Hashable, Sendable {
    public enum Confidence: String, Sendable {
      case high
      case medium
      case low
    }

    public var rule: String
    public var line: Int
    public var confidence: Confidence
    public var preview: String
  }

  public struct Result: Sendable {
    public var findings: [Finding]
    public var redactedText: String
    public var diagnostics: [ToolDiagnostic]

    public var report: String {
      guard !findings.isEmpty else {
        return "No secret-looking values found."
      }

      let summary = """
      Findings: \(findings.count)
      High confidence: \(findings.filter { $0.confidence == .high }.count)
      Medium confidence: \(findings.filter { $0.confidence == .medium }.count)
      Low confidence: \(findings.filter { $0.confidence == .low }.count)

      """

      let rows = findings.map { finding in
        "Line \(finding.line): [\(finding.confidence.rawValue.uppercased())] \(finding.rule) - \(finding.preview)"
      }.joined(separator: "\n")

      return summary + rows + "\n\nRedacted text:\n" + redactedText
    }
  }

  private struct Rule {
    var name: String
    var pattern: String
    var confidence: Finding.Confidence
  }

  private static let rules: [Rule] = [
    Rule(name: "Private key block", pattern: #"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----"#, confidence: .high),
    Rule(name: "Authorization bearer token", pattern: #"(?i)\bAuthorization\s*:\s*Bearer\s+[A-Za-z0-9._~+/=-]{12,}"#, confidence: .high),
    Rule(name: "GitHub token", pattern: #"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{20,}\b"#, confidence: .high),
    Rule(name: "OpenAI-style API key", pattern: #"\bsk-[A-Za-z0-9_-]{20,}\b"#, confidence: .high),
    Rule(name: "AWS access key id", pattern: #"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"#, confidence: .high),
    Rule(name: "JWT", pattern: #"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b"#, confidence: .medium),
    Rule(name: "Secret-looking assignment", pattern: #"(?i)\b[A-Z0-9_.-]*(?:SECRET|TOKEN|API[_-]?KEY|PASSWORD|PASSWD|PRIVATE[_-]?KEY|CLIENT[_-]?SECRET)[A-Z0-9_.-]*\s*[:=]\s*["']?[^"'\s#]{8,}"#, confidence: .medium),
    Rule(name: "Credential URL", pattern: #"[A-Za-z][A-Za-z0-9+.-]*://[^/\s:@]+:[^@\s/]+@[^\s]+"#, confidence: .medium)
  ]

  public static func scan(_ input: String) -> Result {
    let assignmentResult = redactSecretAssignments(in: input)
    var redacted = assignmentResult.text
    var findings = assignmentResult.findings

    for rule in rules {
      if rule.name == "Secret-looking assignment" { continue }
      let regex = try? NSRegularExpression(pattern: rule.pattern, options: [])
      let searchRange = NSRange(redacted.startIndex..<redacted.endIndex, in: redacted)
      let matches = regex?.matches(in: redacted, range: searchRange).reversed() ?? []
      for match in matches {
        guard let range = Range(match.range, in: redacted) else { continue }
        let matched = String(redacted[range])
        findings.append(
          Finding(
            rule: rule.name,
            line: lineNumber(for: range.lowerBound, in: redacted),
            confidence: rule.confidence,
            preview: preview(for: matched)
          )
        )
        redacted.replaceSubrange(range, with: redaction(for: rule.name))
      }
    }

    findings = deduplicated(findings)
    findings.sort {
      if $0.line == $1.line { return $0.rule < $1.rule }
      return $0.line < $1.line
    }

    let diagnostics: [ToolDiagnostic]
    if findings.contains(where: { $0.confidence == .high }) {
      diagnostics = [ToolDiagnostic(.warning, "High-confidence secret-looking values found. Review before sharing this text.")]
    } else if !findings.isEmpty {
      diagnostics = [ToolDiagnostic(.info, "Secret-looking values found and redacted in output.")]
    } else {
      diagnostics = [ToolDiagnostic(.info, "No secret-looking values found.")]
    }

    return Result(findings: findings, redactedText: redacted, diagnostics: diagnostics)
  }

  public static func likelyContainsSecret(_ input: String) -> Bool {
    rules.contains { rule in
      guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: []) else { return false }
      let range = NSRange(input.startIndex..<input.endIndex, in: input)
      return regex.firstMatch(in: input, range: range) != nil
    }
  }

  private static func lineNumber(for index: String.Index, in input: String) -> Int {
    input[..<index].reduce(1) { count, character in
      character == "\n" ? count + 1 : count
    }
  }

  private static func redactSecretAssignments(in input: String) -> (text: String, findings: [Finding]) {
    let assignmentRule = rules.first { $0.name == "Secret-looking assignment" }
    guard
      let assignmentRule,
      let regex = try? NSRegularExpression(pattern: assignmentRule.pattern, options: [])
    else {
      return (input, [])
    }

    var outputLines: [String] = []
    var findings: [Finding] = []
    let lines = input.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    for (index, line) in lines.enumerated() {
      let range = NSRange(line.startIndex..<line.endIndex, in: line)
      guard let match = regex.firstMatch(in: line, range: range), let matchRange = Range(match.range, in: line) else {
        outputLines.append(line)
        continue
      }

      let matched = String(line[matchRange])
      findings.append(
        Finding(
          rule: assignmentRule.name,
          line: index + 1,
          confidence: assignmentRule.confidence,
          preview: preview(for: matched)
        )
      )

      if let separatorRange = line.range(of: #"[:=]"#, options: .regularExpression) {
        let prefix = line[..<line.index(after: separatorRange.lowerBound)]
        outputLines.append("\(prefix)<redacted secret-looking assignment>")
      } else {
        outputLines.append(redaction(for: assignmentRule.name))
      }
    }

    return (outputLines.joined(separator: "\n"), findings)
  }

  private static func deduplicated(_ findings: [Finding]) -> [Finding] {
    var seen = Set<String>()
    return findings.filter { finding in
      let key = "\(finding.line)-\(finding.preview)"
      guard !seen.contains(key) else { return false }
      seen.insert(key)
      return true
    }
  }

  private static func redaction(for ruleName: String) -> String {
    "<redacted \(ruleName.lowercased())>"
  }

  private static func preview(for value: String) -> String {
    let compact = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    guard compact.count > 12 else { return "<redacted>" }
    return "\(compact.prefix(4))...\(compact.suffix(4))"
  }
}
