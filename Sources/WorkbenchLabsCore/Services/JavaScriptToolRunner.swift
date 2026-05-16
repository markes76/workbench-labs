import Darwin
import Dispatch
import Foundation

enum JSONValue: Codable, Equatable, Sendable {
  case string(String)
  case int(Int)
  case bool(Bool)

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .string(let value): try container.encode(value)
    case .int(let value): try container.encode(value)
    case .bool(let value): try container.encode(value)
    }
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Int.self) {
      self = .int(value)
    } else {
      self = .string(try container.decode(String.self))
    }
  }

  var stringValue: String {
    switch self {
    case .string(let value): value
    case .int(let value): String(value)
    case .bool(let value): String(value)
    }
  }
}

struct RuntimeRequest: Encodable {
  var tool: String
  var input: String
  var options: [String: JSONValue]
}

struct RuntimeResponse: Decodable {
  var ok: Bool
  var output: String?
  var error: String?
  var metadata: [String: JSONValue]?
}

public final class JavaScriptToolRunner: @unchecked Sendable {
  private static let defaultTimeout: TimeInterval = 30
  private static let defaultMaxCapturedOutputBytes = 16 * 1024 * 1024
  private static let diagnosticSnippetBytes = 2_048

  private let runtimeScriptURL: URL?
  private let nodeExecutableURLOverride: URL?
  private let timeout: TimeInterval
  private let maxCapturedOutputBytes: Int

  public convenience init() {
    self.init(
      runtimeScriptURL: nil,
      nodeExecutableURL: nil,
      timeout: Self.defaultTimeout,
      maxCapturedOutputBytes: Self.defaultMaxCapturedOutputBytes
    )
  }

  init(
    runtimeScriptURL: URL?,
    nodeExecutableURL: URL?,
    timeout: TimeInterval,
    maxCapturedOutputBytes: Int
  ) {
    precondition(timeout > 0, "JavaScript runtime timeout must be positive.")
    precondition(maxCapturedOutputBytes > 0, "JavaScript runtime output cap must be positive.")
    self.runtimeScriptURL = runtimeScriptURL
    self.nodeExecutableURLOverride = nodeExecutableURL
    self.timeout = timeout
    self.maxCapturedOutputBytes = maxCapturedOutputBytes
  }

  public func run(tool: String, input: String, options: ToolOptions = ToolOptions()) throws -> ToolResult {
    let scriptURL: URL
    if let runtimeScriptURL {
      scriptURL = runtimeScriptURL
    } else {
      guard let bundledRuntimeScriptURL = Self.bundledRuntimeScriptURL() else {
        throw ToolEngineError.runtimeUnavailable("The bundled JavaScript runtime could not be found.")
      }
      scriptURL = bundledRuntimeScriptURL
    }

    var runtimeOptions = [String: JSONValue]()
    if !options.operation.isEmpty {
      runtimeOptions["operation"] = .string(options.operation)
    }
    if !options.secondaryInput.isEmpty {
      runtimeOptions["secondaryInput"] = .string(options.secondaryInput)
    }
    for (key, value) in options.textValues {
      runtimeOptions[key] = .string(value)
    }
    for (key, value) in options.boolValues {
      runtimeOptions[key] = .bool(value)
    }
    for (key, value) in options.intValues {
      runtimeOptions[key] = .int(value)
    }

    let request = RuntimeRequest(tool: tool, input: input, options: runtimeOptions)
    let requestData = try JSONEncoder().encode(request)

    guard let nodeURL = nodeExecutableURLOverride ?? Self.nodeExecutableURL() else {
      throw ToolEngineError.runtimeUnavailable(
        "Node.js is required for this formatter/converter and could not be found. Install Node.js in /opt/homebrew/bin/node or /usr/local/bin/node, then reopen Workbench Labs."
      )
    }

    let outputFiles: RuntimeOutputFiles
    do {
      outputFiles = try RuntimeOutputFiles()
    } catch {
      throw ToolEngineError.runtimeUnavailable("Could not prepare JavaScript runtime output capture: \(error.localizedDescription)")
    }
    defer { outputFiles.cleanup() }

    let process = Process()
    process.executableURL = nodeURL
    process.arguments = [scriptURL.path]

    let stdin = Pipe()
    let terminationSemaphore = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in
      terminationSemaphore.signal()
    }
    process.standardInput = stdin
    process.standardOutput = outputFiles.stdoutWritingHandle
    process.standardError = outputFiles.stderrWritingHandle

    do {
      try process.run()
    } catch {
      throw ToolEngineError.runtimeUnavailable("Could not launch Node.js at \(nodeURL.path): \(error.localizedDescription)")
    }

    stdin.fileHandleForWriting.write(requestData)
    stdin.fileHandleForWriting.closeFile()

    let didExit = terminationSemaphore.wait(timeout: .now() + timeout) == .success
    if !didExit {
      Self.terminate(process, terminationSemaphore: terminationSemaphore)
      outputFiles.closeWritingHandles()
      let errorOutput = try readCapturedStderr(from: outputFiles)
      let errorDetail = Self.diagnosticDescription(for: errorOutput, label: "stderr")
      var message = "JavaScript runtime timed out after \(Self.formatDuration(timeout)) while running \(tool). The process was terminated."
      if let errorDetail {
        message += " \(errorDetail)"
      }
      throw ToolEngineError.runtimeUnavailable(message)
    }

    outputFiles.closeWritingHandles()
    let (output, errorOutput) = try readCapturedOutputs(from: outputFiles)
    guard !output.truncated else {
      var message = "JavaScript runtime produced more than \(Self.formatByteCount(maxCapturedOutputBytes)) of stdout while running \(tool). Output was truncated."
      if let errorDetail = Self.diagnosticDescription(for: errorOutput, label: "stderr") {
        message += " \(errorDetail)"
      }
      throw ToolEngineError.runtimeUnavailable(message)
    }
    guard !output.data.isEmpty else {
      throw ToolEngineError.runtimeUnavailable(
        Self.emptyOutputMessage(
          tool: tool,
          process: process,
          stderr: errorOutput
        )
      )
    }

    let response: RuntimeResponse
    do {
      response = try JSONDecoder().decode(RuntimeResponse.self, from: output.data)
    } catch {
      var message = "JavaScript runtime returned an invalid response while running \(tool): \(error.localizedDescription)."
      if let outputDetail = Self.diagnosticDescription(for: output, label: "stdout") {
        message += " \(outputDetail)"
      }
      if let errorDetail = Self.diagnosticDescription(for: errorOutput, label: "stderr") {
        message += " \(errorDetail)"
      }
      throw ToolEngineError.runtimeUnavailable(message)
    }

    if !response.ok {
      throw ToolEngineError.invalidInput(response.error ?? "The JavaScript runtime rejected this input.")
    }

    let metadata = (response.metadata ?? [:]).mapValues(\.stringValue)
    return ToolResult(output: response.output ?? "", metadata: metadata)
  }

  private func readCapturedOutputs(
    from outputFiles: RuntimeOutputFiles
  ) throws -> (stdout: CapturedRuntimeOutput, stderr: CapturedRuntimeOutput) {
    do {
      return (
        try outputFiles.readStdout(maxBytes: maxCapturedOutputBytes),
        try outputFiles.readStderr(maxBytes: maxCapturedOutputBytes)
      )
    } catch {
      throw ToolEngineError.runtimeUnavailable("Could not read JavaScript runtime output: \(error.localizedDescription)")
    }
  }

  private func readCapturedStderr(from outputFiles: RuntimeOutputFiles) throws -> CapturedRuntimeOutput {
    do {
      return try outputFiles.readStderr(maxBytes: maxCapturedOutputBytes)
    } catch {
      throw ToolEngineError.runtimeUnavailable("Could not read JavaScript runtime error output: \(error.localizedDescription)")
    }
  }

  private static func nodeExecutableURL(fileManager: FileManager = .default) -> URL? {
    let candidates = [
      "/opt/homebrew/bin/node",
      "/usr/local/bin/node",
      "/usr/bin/node"
    ]
    guard let path = candidates.first(where: { fileManager.isExecutableFile(atPath: $0) }) else {
      return nil
    }
    return URL(fileURLWithPath: path)
  }

  private static func bundledRuntimeScriptURL(fileManager: FileManager = .default) -> URL? {
    let subdirectories = [
      "WorkbenchLabs_WorkbenchLabsCore.bundle/Resources/ToolRuntime",
      "../WorkbenchLabs_WorkbenchLabsCore.bundle/Resources/ToolRuntime"
    ]
    for subdirectory in subdirectories {
      if let url = Bundle.main.url(
        forResource: "tool-runtime",
        withExtension: "cjs",
        subdirectory: subdirectory
      ),
         fileManager.fileExists(atPath: url.path) {
        return url
      }
    }
    return Bundle.module.url(
      forResource: "tool-runtime",
      withExtension: "cjs",
      subdirectory: "Resources/ToolRuntime"
    )
  }

  private static func terminate(_ process: Process, terminationSemaphore: DispatchSemaphore) {
    if process.isRunning {
      process.terminate()
    }
    if terminationSemaphore.wait(timeout: .now() + .milliseconds(500)) == .success {
      return
    }
    if process.isRunning {
      Darwin.kill(process.processIdentifier, SIGKILL)
    }
    _ = terminationSemaphore.wait(timeout: .now() + .seconds(1))
  }

  private static func emptyOutputMessage(
    tool: String,
    process: Process,
    stderr: CapturedRuntimeOutput
  ) -> String {
    let status = processStatusDescription(process)
    var message = "JavaScript runtime \(status) while running \(tool) without producing a response."
    if let errorDetail = diagnosticDescription(for: stderr, label: "stderr") {
      message += " \(errorDetail)"
    } else {
      message += " No stderr was captured."
    }
    return message
  }

  private static func processStatusDescription(_ process: Process) -> String {
    switch process.terminationReason {
    case .exit:
      "exited with status \(process.terminationStatus)"
    case .uncaughtSignal:
      "was terminated by signal \(process.terminationStatus)"
    @unknown default:
      "ended with status \(process.terminationStatus)"
    }
  }

  private static func diagnosticDescription(for output: CapturedRuntimeOutput, label: String) -> String? {
    guard !output.data.isEmpty else {
      return output.truncated ? "\(label) was truncated before any text could be captured." : nil
    }
    let snippetData = Data(output.data.prefix(diagnosticSnippetBytes))
    let snippet = String(data: snippetData, encoding: .utf8)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    let text = snippet?.isEmpty == false ? snippet! : "<\(snippetData.count) non-printing bytes>"
    let truncated = output.truncated || output.data.count > diagnosticSnippetBytes
    return "\(label): \(text)\(truncated ? " (truncated)" : "")"
  }

  private static func formatDuration(_ duration: TimeInterval) -> String {
    if duration.rounded(.down) == duration {
      return "\(Int(duration))s"
    }
    return String(format: "%.1fs", duration)
  }

  private static func formatByteCount(_ byteCount: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
  }
}

private struct CapturedRuntimeOutput {
  var data: Data
  var truncated: Bool
}

private final class RuntimeOutputFiles {
  let stdoutWritingHandle: FileHandle
  let stderrWritingHandle: FileHandle

  private let directoryURL: URL
  private let stdoutURL: URL
  private let stderrURL: URL
  private let fileManager: FileManager
  private var didCloseWritingHandles = false

  init(fileManager: FileManager = .default) throws {
    self.fileManager = fileManager
    directoryURL = fileManager.temporaryDirectory
      .appendingPathComponent("WorkbenchLabsJavaScriptRuntime-\(UUID().uuidString)", isDirectory: true)
    stdoutURL = directoryURL.appendingPathComponent("stdout")
    stderrURL = directoryURL.appendingPathComponent("stderr")

    try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    try Data().write(to: stdoutURL)
    try Data().write(to: stderrURL)
    stdoutWritingHandle = try FileHandle(forWritingTo: stdoutURL)
    stderrWritingHandle = try FileHandle(forWritingTo: stderrURL)
  }

  func closeWritingHandles() {
    guard !didCloseWritingHandles else { return }
    try? stdoutWritingHandle.close()
    try? stderrWritingHandle.close()
    didCloseWritingHandles = true
  }

  func readStdout(maxBytes: Int) throws -> CapturedRuntimeOutput {
    try readOutput(at: stdoutURL, maxBytes: maxBytes)
  }

  func readStderr(maxBytes: Int) throws -> CapturedRuntimeOutput {
    try readOutput(at: stderrURL, maxBytes: maxBytes)
  }

  func cleanup() {
    closeWritingHandles()
    try? fileManager.removeItem(at: directoryURL)
  }

  private func readOutput(at url: URL, maxBytes: Int) throws -> CapturedRuntimeOutput {
    let readHandle = try FileHandle(forReadingFrom: url)
    defer { try? readHandle.close() }

    let data = try readHandle.read(upToCount: maxBytes + 1) ?? Data()
    if data.count > maxBytes {
      return CapturedRuntimeOutput(data: Data(data.prefix(maxBytes)), truncated: true)
    }
    return CapturedRuntimeOutput(data: data, truncated: false)
  }
}
