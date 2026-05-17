import Foundation

public enum VideoConverter {
  private static let processRunner = ExternalProcessRunner()

  public static func run(input: String, options: ToolOptions) throws -> ToolResult {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return ToolResult(output: helpText)
    }

    let operation = options.operation.isEmpty ? "info" : options.operation
    switch operation {
    case "extractAudio":
      return try extractAudio(input: input, options: options)
    case "thumbnail":
      return try thumbnail(input: input, options: options)
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

    let requestedFormat = options.textValues["outputFormat"] ?? "mp4"
    if audioFormats.contains(requestedFormat.lowercased()) {
      return try extractAudio(input: input, options: options)
    }

    let format = videoFormat(requestedFormat)
    let trimWindow = TrimWindow(options: options)
    let outputURL = try outputURL(
      sourceURL: sourceURL,
      format: format,
      operation: trimWindow.hasTrim ? "clip" : "convert",
      configuredOutputPath: options.textValues["outputPath"]?.nilIfEmpty
    )
    let temporaryURL = PathInput.temporarySibling(for: outputURL)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }

    var arguments = inputArguments(sourceURL: sourceURL, trimWindow: trimWindow)
    switch format.lowercased() {
    case "gif":
      arguments += ["-vf", "fps=12,scale=960:-1:flags=lanczos", temporaryURL.path]
    case "webm":
      arguments += ["-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "32", "-c:a", "libopus", temporaryURL.path]
    default:
      arguments += ["-c:v", "libx264", "-preset", "medium", "-crf", "23", "-c:a", "aac", temporaryURL.path]
    }

    _ = try runRequiredProcess(executableURL: ffmpeg, arguments: arguments, timeout: 600)
    try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
    return ToolResult(
      output: "\(trimWindow.hasTrim ? "Created video clip" : "Converted video") to \(format.uppercased()):\n\(outputURL.path)",
      metadata: metadata(outputURL: outputURL, operation: trimWindow.hasTrim ? "clip" : "convert", format: format, trimWindow: trimWindow)
    )
  }

  private static func extractAudio(input: String, options: ToolOptions) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input)
    guard let sourceURL = urls.first else { throw ToolEngineError.emptyInput }
    guard let ffmpeg = processRunner.executable(named: "ffmpeg") else {
      throw ToolEngineError.runtimeUnavailable("ffmpeg is required for audio extraction. Install ffmpeg locally and reopen Workbench Labs.")
    }

    let format = audioFormat(options.textValues["outputFormat"] ?? "mp3")
    let trimWindow = TrimWindow(options: options)
    let outputURL = try outputURL(
      sourceURL: sourceURL,
      format: format,
      operation: "audio",
      configuredOutputPath: options.textValues["outputPath"]?.nilIfEmpty
    )
    let temporaryURL = PathInput.temporarySibling(for: outputURL)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }

    var arguments = inputArguments(sourceURL: sourceURL, trimWindow: trimWindow)
    switch format {
    case "wav":
      arguments += ["-vn", "-c:a", "pcm_s16le", temporaryURL.path]
    case "aac":
      arguments += ["-vn", "-c:a", "aac", "-b:a", "192k", temporaryURL.path]
    default:
      arguments += ["-vn", "-c:a", "libmp3lame", "-b:a", "192k", temporaryURL.path]
    }

    _ = try runRequiredProcess(executableURL: ffmpeg, arguments: arguments, timeout: 600)
    try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
    return ToolResult(
      output: "Extracted \(format.uppercased()) audio:\n\(outputURL.path)",
      metadata: metadata(outputURL: outputURL, operation: "extractAudio", format: format, trimWindow: trimWindow)
    )
  }

  private static func thumbnail(input: String, options: ToolOptions) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input)
    guard let sourceURL = urls.first else { throw ToolEngineError.emptyInput }
    guard let ffmpeg = processRunner.executable(named: "ffmpeg") else {
      throw ToolEngineError.runtimeUnavailable("ffmpeg is required for thumbnail generation. Install ffmpeg locally and reopen Workbench Labs.")
    }

    let format = thumbnailFormat(options.textValues["outputFormat"] ?? "jpg")
    let trimWindow = TrimWindow(options: options)
    let outputURL = try outputURL(
      sourceURL: sourceURL,
      format: format,
      operation: "thumbnail",
      configuredOutputPath: options.textValues["outputPath"]?.nilIfEmpty
    )
    let temporaryURL = PathInput.temporarySibling(for: outputURL)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }

    var arguments = thumbnailInputArguments(sourceURL: sourceURL, trimWindow: trimWindow.withoutEnd)
    if format == "jpg" || format == "jpeg" {
      arguments += ["-frames:v", "1", "-q:v", "2", "-pix_fmt", "yuvj420p", "-update", "1", temporaryURL.path]
    } else {
      arguments += ["-frames:v", "1", "-update", "1", temporaryURL.path]
    }

    _ = try runRequiredProcess(executableURL: ffmpeg, arguments: arguments, timeout: 120)
    try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
    return ToolResult(
      output: "Generated \(format.uppercased()) thumbnail:\n\(outputURL.path)",
      metadata: metadata(outputURL: outputURL, operation: "thumbnail", format: format, trimWindow: trimWindow.withoutEnd)
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

  private static func inputArguments(sourceURL: URL, trimWindow: TrimWindow) -> [String] {
    var arguments = ["-hide_banner"]
    if let startTime = trimWindow.startTime {
      arguments += ["-ss", startTime]
    }
    arguments += ["-i", sourceURL.path]
    if let duration = trimWindow.duration {
      arguments += ["-t", duration]
    } else if let endTime = trimWindow.endTime {
      arguments += ["-to", endTime]
    }
    return arguments
  }

  private static func thumbnailInputArguments(sourceURL: URL, trimWindow: TrimWindow) -> [String] {
    var arguments = ["-hide_banner", "-i", sourceURL.path]
    if let startTime = trimWindow.startTime {
      arguments += ["-ss", startTime]
    }
    return arguments
  }

  private static func outputURL(
    sourceURL: URL,
    format: String,
    operation: String,
    configuredOutputPath: String?
  ) throws -> URL {
    let outputPath = configuredOutputPath == nil || configuredOutputPath == defaultConfiguredOutputPath
      ? defaultOutputPath(for: sourceURL, format: format, operation: operation)
      : configuredOutputPath!
    return try PathInput.availableOutputFileURL(for: PathInput.expandedURL(outputPath))
  }

  private static func defaultOutputPath(for sourceURL: URL, format: String, operation: String) -> String {
    let suffix = switch operation {
    case "clip": "-clip"
    case "audio": "-audio"
    case "thumbnail": "-thumbnail"
    default: ""
    }
    return sourceURL
      .deletingPathExtension()
      .deletingLastPathComponent()
      .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent + suffix)
      .appendingPathExtension(format.lowercased())
      .path
  }

  private static func videoFormat(_ value: String) -> String {
    let lowercased = value.lowercased()
    return videoFormats.contains(lowercased) ? lowercased : "mp4"
  }

  private static func audioFormat(_ value: String) -> String {
    let lowercased = value.lowercased()
    return audioFormats.contains(lowercased) ? lowercased : "mp3"
  }

  private static func thumbnailFormat(_ value: String) -> String {
    let lowercased = value.lowercased()
    return thumbnailFormats.contains(lowercased) ? lowercased : "jpg"
  }

  private static func metadata(outputURL: URL, operation: String, format: String, trimWindow: TrimWindow) -> [String: String] {
    var metadata = FileResultMetadata.metadata(generatedFileURLs: [outputURL])
    metadata["operation"] = operation
    metadata["outputFormat"] = format
    if let startTime = trimWindow.startTime {
      metadata["startTime"] = startTime
    }
    if let endTime = trimWindow.endTime {
      metadata["endTime"] = endTime
    }
    return metadata
  }

  private static let helpText = """
  Video Converter runs locally with ffmpeg/ffprobe.

  Paste or drop a video path, then choose:
  - Info: inspect format and streams with ffprobe
  - Convert: MP4, MOV, WebM, or GIF, with optional start/end trimming
  - Extract Audio: MP3, WAV, or AAC
  - Thumbnail: JPG or PNG still image
  """

  private static let defaultConfiguredOutputPath = "~/Desktop/workbench-labs-video.mp4"
  private static let videoFormats: Set<String> = ["mp4", "mov", "webm", "gif"]
  private static let audioFormats: Set<String> = ["mp3", "wav", "aac"]
  private static let thumbnailFormats: Set<String> = ["jpg", "jpeg", "png"]
}

private struct TrimWindow {
  var startTime: String?
  var endTime: String?

  init(options: ToolOptions) {
    startTime = options.textValues["startTime"]?.nilIfEmpty
    endTime = options.textValues["endTime"]?.nilIfEmpty
  }

  private init(startTime: String?, endTime: String?) {
    self.startTime = startTime
    self.endTime = endTime
  }

  var hasTrim: Bool {
    startTime != nil || endTime != nil
  }

  var withoutEnd: TrimWindow {
    TrimWindow(startTime: startTime, endTime: nil)
  }

  var duration: String? {
    guard let startTime,
          let endTime,
          let startSeconds = Self.seconds(from: startTime),
          let endSeconds = Self.seconds(from: endTime),
          endSeconds > startSeconds
    else {
      return nil
    }
    return Self.format(seconds: endSeconds - startSeconds)
  }

  private static func seconds(from value: String) -> Double? {
    if let seconds = Double(value) {
      return seconds
    }
    let parts = value.split(separator: ":").compactMap { Double($0) }
    guard parts.count >= 2, parts.count <= 3 else { return nil }
    if parts.count == 2 {
      return parts[0] * 60 + parts[1]
    }
    return parts[0] * 3600 + parts[1] * 60 + parts[2]
  }

  private static func format(seconds: Double) -> String {
    String(format: "%.3f", seconds)
      .replacingOccurrences(of: #"0+$"#, with: "", options: .regularExpression)
      .replacingOccurrences(of: #"\.$"#, with: "", options: .regularExpression)
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
