import Foundation

enum PathInput {
  static func paths(from input: String) -> [String] {
    input
      .split(whereSeparator: \.isNewline)
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
  }

  static func existingFileURLs(from input: String, allowedExtensions: Set<String>? = nil) throws -> [URL] {
    let urls = paths(from: input).map { URL(fileURLWithPath: expandingTilde(in: $0)) }
    guard !urls.isEmpty else { throw ToolEngineError.emptyInput }

    for url in urls {
      guard FileManager.default.fileExists(atPath: url.path) else {
        throw ToolEngineError.invalidInput("File does not exist: \(url.path)")
      }
      if let allowedExtensions, !allowedExtensions.contains(url.pathExtension.lowercased()) {
        throw ToolEngineError.invalidInput("Unsupported file extension: \(url.lastPathComponent)")
      }
    }
    return urls
  }

  static func expandedURL(_ path: String) -> URL {
    URL(fileURLWithPath: expandingTilde(in: path))
  }

  static func availableOutputFileURL(for requestedURL: URL) throws -> URL {
    let directoryURL = requestedURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    guard FileManager.default.fileExists(atPath: requestedURL.path) else {
      return requestedURL
    }

    let baseName = requestedURL.deletingPathExtension().lastPathComponent
    let pathExtension = requestedURL.pathExtension
    for index in 2...10_000 {
      let candidateBaseName = "\(baseName)-\(index)"
      let candidate = directoryURL.appendingPathComponent(candidateBaseName)
      let candidateURL = pathExtension.isEmpty ? candidate : candidate.appendingPathExtension(pathExtension)
      if !FileManager.default.fileExists(atPath: candidateURL.path) {
        return candidateURL
      }
    }
    throw ToolEngineError.invalidInput("Could not find an available output filename near \(requestedURL.path).")
  }

  static func prepareOutputDirectory(at url: URL) throws {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    if exists, !isDirectory.boolValue {
      throw ToolEngineError.invalidInput("Output path is not a folder: \(url.path)")
    }
    if !exists {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
  }

  static func temporarySibling(for url: URL) -> URL {
    let basename = url.deletingPathExtension().lastPathComponent
    let ext = url.pathExtension
    let tempName = ".\(basename).\(UUID().uuidString).tmp"
    let tempURL = url.deletingLastPathComponent().appendingPathComponent(tempName)
    return ext.isEmpty ? tempURL : tempURL.appendingPathExtension(ext)
  }

  private static func expandingTilde(in path: String) -> String {
    NSString(string: path).expandingTildeInPath
  }
}
