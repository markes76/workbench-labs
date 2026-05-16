import Darwin
import Dispatch
import Foundation

public enum VideoConverter {
  private static let maxCapturedOutputBytes = 2 * 1024 * 1024

  public static func run(input: String, options: ToolOptions) throws -> ToolResult {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return ToolResult(output: helpText)
    }

    let operation = options.operation.isEmpty ? "info" : options.operation
    switch operation {
    case "convert":
      return try convert(input: input, options: options)
    default:
      return try info(input: input)
    }
  }

  private static func info(input: String) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input)
    guard let ffprobe = executable(named: "ffprobe") else {
      throw ToolEngineError.runtimeUnavailable("ffprobe is required for video inspection. Install ffmpeg locally and reopen Workbench Labs.")
    }

    let output = try urls.map { url in
      let result = try runProcess(
        executableURL: ffprobe,
        arguments: ["-v", "error", "-show_format", "-show_streams", "-of", "json", url.path],
        timeout: 20
      )
      return """
      # \(url.lastPathComponent)
      \(result)
      """
    }.joined(separator: "\n\n")

    return ToolResult(output: output, metadata: ["files": String(urls.count)])
  }

  private static func convert(input: String, options: ToolOptions) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input)
    guard let sourceURL = urls.first else { throw ToolEngineError.emptyInput }
    guard let ffmpeg = executable(named: "ffmpeg") else {
      throw ToolEngineError.runtimeUnavailable("ffmpeg is required for video conversion. Install ffmpeg locally and reopen Workbench Labs.")
    }

    let format = options.textValues["outputFormat"] ?? "mp4"
    let configuredOutputPath = options.textValues["outputPath"]?.nilIfEmpty
    let outputPath = configuredOutputPath == nil || configuredOutputPath == defaultConfiguredOutputPath
      ? defaultOutputPath(for: sourceURL, format: format)
      : configuredOutputPath!
    let outputURL = try PathInput.availableOutputFileURL(for: PathInput.expandedURL(outputPath))
    let temporaryURL = PathInput.temporarySibling(for: outputURL)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }

    var arguments = ["-hide_banner", "-i", sourceURL.path]
    switch format.lowercased() {
    case "gif":
      arguments += ["-vf", "fps=12,scale=960:-1:flags=lanczos", temporaryURL.path]
    case "mp3":
      arguments += ["-vn", "-c:a", "libmp3lame", "-b:a", "192k", temporaryURL.path]
    case "webm":
      arguments += ["-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "32", "-c:a", "libopus", temporaryURL.path]
    default:
      arguments += ["-c:v", "libx264", "-preset", "medium", "-crf", "23", "-c:a", "aac", temporaryURL.path]
    }

    _ = try runProcess(executableURL: ffmpeg, arguments: arguments, timeout: 600)
    try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
    return ToolResult(output: "Converted video to \(format.uppercased()):\n\(outputURL.path)")
  }

  private static func executable(named name: String) -> URL? {
    let candidates = [
      "/opt/homebrew/bin/\(name)",
      "/usr/local/bin/\(name)",
      "/usr/bin/\(name)"
    ]
    guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
      return nil
    }
    return URL(fileURLWithPath: path)
  }

  private static func runProcess(executableURL: URL, arguments: [String], timeout: TimeInterval) throws -> String {
    let outputFiles: ProcessOutputFiles
    do {
      outputFiles = try ProcessOutputFiles()
    } catch {
      throw ToolEngineError.runtimeUnavailable("Could not prepare process output capture: \(error.localizedDescription)")
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
      let error = try outputFiles.readStderr(maxBytes: maxCapturedOutputBytes).stringValue
      let detail = error.nilIfEmpty.map { " stderr: \($0)" } ?? ""
      throw ToolEngineError.runtimeUnavailable("\(executableURL.lastPathComponent) timed out after \(Int(timeout))s.\(detail)")
    }

    outputFiles.closeWritingHandles()
    let output = try outputFiles.readStdout(maxBytes: maxCapturedOutputBytes)
    let error = try outputFiles.readStderr(maxBytes: maxCapturedOutputBytes)
    guard process.terminationStatus == 0 else {
      throw ToolEngineError.invalidInput(error.stringValue.nilIfEmpty ?? "\(executableURL.lastPathComponent) failed.")
    }
    return output.stringValue.nilIfEmpty ?? error.stringValue
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

  private static func defaultOutputPath(for sourceURL: URL, format: String) -> String {
    sourceURL
      .deletingPathExtension()
      .appendingPathExtension(format.lowercased())
      .path
  }

  private static let helpText = """
  Video Converter runs locally with ffmpeg/ffprobe.

  Paste or drop a video path, then choose:
  - Info: inspect format and streams with ffprobe
  - Convert: MP4, MOV, WebM, GIF, or MP3 with ffmpeg
  """

  private static let defaultConfiguredOutputPath = "~/Desktop/workbench-labs-video.mp4"
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}

private struct CapturedProcessOutput {
  var data: Data
  var truncated: Bool

  var stringValue: String {
    let text = String(data: data, encoding: .utf8) ?? "<\(data.count) non-printing bytes>"
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return truncated ? "\(trimmed)\n(output truncated)" : trimmed
  }
}

private final class ProcessOutputFiles {
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

  func readStdout(maxBytes: Int) throws -> CapturedProcessOutput {
    try readOutput(at: stdoutURL, maxBytes: maxBytes)
  }

  func readStderr(maxBytes: Int) throws -> CapturedProcessOutput {
    try readOutput(at: stderrURL, maxBytes: maxBytes)
  }

  func cleanup() {
    closeWritingHandles()
    try? fileManager.removeItem(at: directoryURL)
  }

  private func readOutput(at url: URL, maxBytes: Int) throws -> CapturedProcessOutput {
    let readHandle = try FileHandle(forReadingFrom: url)
    defer { try? readHandle.close() }

    let data = try readHandle.read(upToCount: maxBytes + 1) ?? Data()
    if data.count > maxBytes {
      return CapturedProcessOutput(data: Data(data.prefix(maxBytes)), truncated: true)
    }
    return CapturedProcessOutput(data: data, truncated: false)
  }
}
