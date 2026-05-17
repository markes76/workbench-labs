import Darwin
import Dispatch
import Foundation

public enum ExternalProcessRunnerError: Error, Equatable {
  case executableNotFound(name: String, searchPaths: [String])
  case outputCaptureFailed(String)
}

public struct ExternalProcessResult: Equatable, Sendable {
  public var stdoutData: Data
  public var stderrData: Data
  public var stdoutTruncated: Bool
  public var stderrTruncated: Bool
  public var exitCode: Int32?
  public var didTimeOut: Bool

  public var isSuccess: Bool {
    exitCode == 0 && !didTimeOut
  }

  public var stdoutString: String {
    Self.stringValue(for: stdoutData, truncated: stdoutTruncated)
  }

  public var stderrString: String {
    Self.stringValue(for: stderrData, truncated: stderrTruncated)
  }

  public var preferredOutputString: String {
    stdoutString.isEmpty ? stderrString : stdoutString
  }

  private static func stringValue(for data: Data, truncated: Bool) -> String {
    let text = String(data: data, encoding: .utf8) ?? "<\(data.count) non-printing bytes>"
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return truncated ? "\(trimmed)\n(output truncated)" : trimmed
  }
}

public struct ExternalProcessRunner: Sendable {
  public static let defaultSearchPaths = [
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/usr/bin",
    "/bin"
  ]

  public var searchPaths: [String]
  public var maxCapturedOutputBytes: Int

  public init(
    searchPaths: [String] = Self.defaultSearchPaths,
    maxCapturedOutputBytes: Int = 2 * 1024 * 1024
  ) {
    self.searchPaths = searchPaths
    self.maxCapturedOutputBytes = maxCapturedOutputBytes
  }

  public func executable(named name: String) -> URL? {
    if name.contains("/") {
      return FileManager.default.isExecutableFile(atPath: name) ? URL(fileURLWithPath: name) : nil
    }

    return searchPaths
      .map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }
      .first { FileManager.default.isExecutableFile(atPath: $0) }
      .map(URL.init(fileURLWithPath:))
  }

  public func requireExecutable(named name: String) throws -> URL {
    guard let executableURL = executable(named: name) else {
      throw ExternalProcessRunnerError.executableNotFound(name: name, searchPaths: searchPaths)
    }
    return executableURL
  }

  public func run(
    executableURL: URL,
    arguments: [String],
    timeout: TimeInterval
  ) throws -> ExternalProcessResult {
    let outputFiles: ExternalProcessOutputFiles
    do {
      outputFiles = try ExternalProcessOutputFiles()
    } catch {
      throw ExternalProcessRunnerError.outputCaptureFailed(error.localizedDescription)
    }
    defer { outputFiles.cleanup() }

    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.standardOutput = outputFiles.stdoutWritingHandle
    process.standardError = outputFiles.stderrWritingHandle

    let terminationSemaphore = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in
      terminationSemaphore.signal()
    }

    try process.run()
    let didExit = terminationSemaphore.wait(timeout: .now() + timeout) == .success
    if !didExit {
      terminate(process, terminationSemaphore: terminationSemaphore)
      outputFiles.closeWritingHandles()
      let stdout = try outputFiles.readStdout(maxBytes: maxCapturedOutputBytes)
      let stderr = try outputFiles.readStderr(maxBytes: maxCapturedOutputBytes)
      return ExternalProcessResult(
        stdoutData: stdout.data,
        stderrData: stderr.data,
        stdoutTruncated: stdout.truncated,
        stderrTruncated: stderr.truncated,
        exitCode: nil,
        didTimeOut: true
      )
    }

    outputFiles.closeWritingHandles()
    let stdout = try outputFiles.readStdout(maxBytes: maxCapturedOutputBytes)
    let stderr = try outputFiles.readStderr(maxBytes: maxCapturedOutputBytes)
    return ExternalProcessResult(
      stdoutData: stdout.data,
      stderrData: stderr.data,
      stdoutTruncated: stdout.truncated,
      stderrTruncated: stderr.truncated,
      exitCode: process.terminationStatus,
      didTimeOut: false
    )
  }

  private func terminate(_ process: Process, terminationSemaphore: DispatchSemaphore) {
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
}

private struct CapturedExternalProcessOutput {
  var data: Data
  var truncated: Bool
}

private final class ExternalProcessOutputFiles {
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
      .appendingPathComponent("WorkbenchLabsExternalProcess-\(UUID().uuidString)", isDirectory: true)
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

  func readStdout(maxBytes: Int) throws -> CapturedExternalProcessOutput {
    try readOutput(at: stdoutURL, maxBytes: maxBytes)
  }

  func readStderr(maxBytes: Int) throws -> CapturedExternalProcessOutput {
    try readOutput(at: stderrURL, maxBytes: maxBytes)
  }

  func cleanup() {
    closeWritingHandles()
    try? fileManager.removeItem(at: directoryURL)
  }

  private func readOutput(at url: URL, maxBytes: Int) throws -> CapturedExternalProcessOutput {
    let readHandle = try FileHandle(forReadingFrom: url)
    defer { try? readHandle.close() }

    let data = try readHandle.read(upToCount: maxBytes + 1) ?? Data()
    if data.count > maxBytes {
      return CapturedExternalProcessOutput(data: Data(data.prefix(maxBytes)), truncated: true)
    }
    return CapturedExternalProcessOutput(data: data, truncated: false)
  }
}
