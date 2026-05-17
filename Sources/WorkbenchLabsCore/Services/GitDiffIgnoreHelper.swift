import Darwin
import Foundation

public enum GitDiffIgnoreHelper {
  public static func run(input: String, options: ToolOptions) throws -> ToolResult {
    switch options.operation.isEmpty ? "ignoreCheck" : options.operation {
    case "inspect":
      return try inspectRepository(input)
    default:
      return try testIgnorePatterns(patternInput: input, pathInput: options.secondaryInput)
    }
  }

  private static func inspectRepository(_ input: String) throws -> ToolResult {
    let directoryURL = try repositoryDirectory(from: input)
    let root = try runGit(["-C", directoryURL.path, "rev-parse", "--show-toplevel"]).stdoutString
    let branchOutput = try runGit(["-C", directoryURL.path, "branch", "--show-current"]).stdoutString
    let branch = branchOutput.isEmpty ? "detached" : branchOutput
    let statusOutput = try runGit(["-C", directoryURL.path, "status", "--porcelain=v1", "-b"]).stdoutString
    let entries = parseStatus(statusOutput)

    var lines = [
      "Git Repository Inspect",
      "Root: \(root)",
      "Branch: \(branch)",
      "Changed files: \(entries.count)",
      ""
    ]

    if entries.isEmpty {
      lines.append("Working tree clean.")
    } else {
      lines += entries.map { "\($0.label): \($0.path)" }
    }

    lines.append("")
    lines.append("Read-only git commands: rev-parse, branch --show-current, status --porcelain=v1 -b")

    return ToolResult(output: lines.joined(separator: "\n"), metadata: [
      "changedFileCount": "\(entries.count)",
      "repositoryRoot": root,
      "branch": branch
    ])
  }

  private static func testIgnorePatterns(patternInput: String, pathInput: String) throws -> ToolResult {
    let rules = parseIgnoreRules(patternInput)
    guard !rules.isEmpty else { throw ToolEngineError.emptyInput }

    let paths = pathInput
      .split(whereSeparator: \.isNewline)
      .map { normalizePath(String($0)) }
      .filter { !$0.isEmpty }
    guard !paths.isEmpty else {
      throw ToolEngineError.invalidInput("Add one or more paths to test against the ignore patterns.")
    }

    var ignoredCount = 0
    var keptCount = 0
    var lines = [
      "Git Ignore Pattern Check",
      "Patterns: \(rules.count)",
      "Paths: \(paths.count)",
      ""
    ]

    for path in paths {
      let ignored = isIgnored(path, by: rules)
      if ignored {
        ignoredCount += 1
        lines.append("IGNORED  \(path)")
      } else {
        keptCount += 1
        lines.append("KEPT     \(path)")
      }
    }

    return ToolResult(output: lines.joined(separator: "\n"), metadata: [
      "ignoredCount": "\(ignoredCount)",
      "keptCount": "\(keptCount)",
      "patternCount": "\(rules.count)"
    ])
  }

  private static func repositoryDirectory(from input: String) throws -> URL {
    let trimmed = input.trimmedForTool
    guard !trimmed.isEmpty else { throw ToolEngineError.emptyInput }

    let url = PathInput.expandedURL(trimmed)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
      throw ToolEngineError.invalidInput("Path does not exist: \(url.path)")
    }
    return isDirectory.boolValue ? url : url.deletingLastPathComponent()
  }

  private static func runGit(_ arguments: [String]) throws -> ExternalProcessResult {
    let runner = ExternalProcessRunner()
    let gitURL: URL
    do {
      gitURL = try runner.requireExecutable(named: "git")
    } catch {
      throw ToolEngineError.runtimeUnavailable("Git is not available in the standard local paths.")
    }

    let result = try runner.run(executableURL: gitURL, arguments: arguments, timeout: 10)
    if result.didTimeOut {
      throw ToolEngineError.runtimeUnavailable("Git command timed out.")
    }
    guard result.isSuccess else {
      let message = result.preferredOutputString.isEmpty ? "Git command failed." : result.preferredOutputString
      throw ToolEngineError.invalidInput(message)
    }
    return result
  }

  private static func parseStatus(_ output: String) -> [GitStatusEntry] {
    output
      .split(whereSeparator: \.isNewline)
      .map(String.init)
      .compactMap(parseStatusLine)
  }

  private static func parseStatusLine(_ line: String) -> GitStatusEntry? {
    guard !line.hasPrefix("##"), line.count >= 3 else { return nil }
    let indexStatus = line[line.startIndex]
    let worktreeStatus = line[line.index(after: line.startIndex)]
    let path = String(line.dropFirst(3))
    guard !path.isEmpty else { return nil }
    return GitStatusEntry(label: statusLabel(indexStatus: indexStatus, worktreeStatus: worktreeStatus), path: path)
  }

  private static func statusLabel(indexStatus: Character, worktreeStatus: Character) -> String {
    if indexStatus == "?" && worktreeStatus == "?" { return "Untracked" }
    if indexStatus == "U" || worktreeStatus == "U" { return "Unmerged" }
    if indexStatus == "R" || worktreeStatus == "R" { return "Renamed" }
    if indexStatus == "C" || worktreeStatus == "C" { return "Copied" }
    if indexStatus == "A" || worktreeStatus == "A" { return "Added" }
    if indexStatus == "D" || worktreeStatus == "D" { return "Deleted" }
    if indexStatus == "M" || worktreeStatus == "M" { return "Modified" }
    return "Changed"
  }

  private static func parseIgnoreRules(_ input: String) -> [IgnoreRule] {
    input
      .split(whereSeparator: \.isNewline)
      .compactMap { parseIgnoreRule(String($0)) }
  }

  private static func parseIgnoreRule(_ rawLine: String) -> IgnoreRule? {
    var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !line.isEmpty, !line.hasPrefix("#") else { return nil }
    if line.hasPrefix("\\#") {
      line.removeFirst()
    }

    let negated = line.hasPrefix("!")
    if negated {
      line.removeFirst()
    }
    guard !line.isEmpty else { return nil }

    let directoryOnly = line.hasSuffix("/")
    let anchored = line.hasPrefix("/")
    if anchored {
      line.removeFirst()
    }
    if directoryOnly {
      line.removeLast()
    }

    line = normalizePath(line)
    guard !line.isEmpty else { return nil }

    return IgnoreRule(
      pattern: line,
      negated: negated,
      directoryOnly: directoryOnly,
      matchesFullPath: anchored || line.contains("/")
    )
  }

  private static func isIgnored(_ path: String, by rules: [IgnoreRule]) -> Bool {
    rules.reduce(false) { ignored, rule in
      matches(rule: rule, path: path) ? !rule.negated : ignored
    }
  }

  private static func matches(rule: IgnoreRule, path: String) -> Bool {
    let normalizedPath = normalizePath(path)
    if rule.directoryOnly {
      return directoryPattern(rule.pattern, matches: normalizedPath, fullPath: rule.matchesFullPath)
    }
    if rule.matchesFullPath {
      return wildcard(rule.pattern, matches: normalizedPath)
    }
    return wildcard(rule.pattern, matches: basename(of: normalizedPath))
  }

  private static func directoryPattern(_ pattern: String, matches path: String, fullPath: Bool) -> Bool {
    if fullPath {
      return path == pattern || path.hasPrefix("\(pattern)/")
    }
    return path
      .split(separator: "/")
      .map(String.init)
      .contains { wildcard(pattern, matches: $0) }
  }

  private static func wildcard(_ pattern: String, matches value: String) -> Bool {
    fnmatch(pattern, value, FNM_PATHNAME) == 0
  }

  private static func basename(of path: String) -> String {
    path.split(separator: "/").last.map(String.init) ?? path
  }

  private static func normalizePath(_ value: String) -> String {
    var path = value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "\\", with: "/")
    while path.hasPrefix("./") {
      path.removeFirst(2)
    }
    while path.hasPrefix("/") {
      path.removeFirst()
    }
    return path
      .split(separator: "/", omittingEmptySubsequences: true)
      .joined(separator: "/")
  }
}

private struct GitStatusEntry {
  var label: String
  var path: String
}

private struct IgnoreRule {
  var pattern: String
  var negated: Bool
  var directoryOnly: Bool
  var matchesFullPath: Bool
}
