import Foundation

public enum VideoConverter {
  private static let processRunner = ExternalProcessRunner()

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
    guard let ffprobe = processRunner.executable(named: "ffprobe") else {
      throw ToolEngineError.runtimeUnavailable("ffprobe is required for video inspection. Install ffmpeg locally and reopen Workbench Labs.")
    }

    let output = try urls.map { url in
      let result = try runRequiredProcess(
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
    guard let ffmpeg = processRunner.executable(named: "ffmpeg") else {
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

    _ = try runRequiredProcess(executableURL: ffmpeg, arguments: arguments, timeout: 600)
    try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
    return ToolResult(
      output: "Converted video to \(format.uppercased()):\n\(outputURL.path)",
      metadata: FileResultMetadata.metadata(generatedFileURLs: [outputURL])
    )
  }

  private static func runRequiredProcess(executableURL: URL, arguments: [String], timeout: TimeInterval) throws -> String {
    let result = try processRunner.run(executableURL: executableURL, arguments: arguments, timeout: timeout)
    if result.didTimeOut {
      let detail = result.stderrString.nilIfEmpty.map { " stderr: \($0)" } ?? ""
      throw ToolEngineError.runtimeUnavailable("\(executableURL.lastPathComponent) timed out after \(Int(timeout))s.\(detail)")
    }
    guard result.isSuccess else {
      throw ToolEngineError.invalidInput(result.stderrString.nilIfEmpty ?? "\(executableURL.lastPathComponent) failed.")
    }
    return result.preferredOutputString
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
