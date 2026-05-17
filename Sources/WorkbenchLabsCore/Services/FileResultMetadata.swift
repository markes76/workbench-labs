import Foundation

public enum FileResultMetadata {
  public static let generatedFilePathsKey = "generatedFilePaths"
  public static let generatedFileCountKey = "generatedFileCount"

  public static func metadata(generatedFileURLs urls: [URL]) -> [String: String] {
    let paths = urls.map(\.path)
    guard !paths.isEmpty else { return [:] }

    let encodedPaths = (try? JSONEncoder().encode(paths))
      .flatMap { String(data: $0, encoding: .utf8) } ?? paths.joined(separator: "\n")

    return [
      generatedFilePathsKey: encodedPaths,
      generatedFileCountKey: String(paths.count)
    ]
  }

  public static func generatedFileURLs(from metadata: [String: String]) -> [URL] {
    guard let value = metadata[generatedFilePathsKey], !value.isEmpty else { return [] }

    let paths: [String]
    if let data = value.data(using: .utf8),
       let decodedPaths = try? JSONDecoder().decode([String].self, from: data) {
      paths = decodedPaths
    } else {
      paths = value
        .split(whereSeparator: \.isNewline)
        .map(String.init)
    }

    return paths
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
      .map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath) }
  }

  public static func existingGeneratedFileURLs(from metadata: [String: String], outputFallback: String = "") -> [URL] {
    let metadataURLs = generatedFileURLs(from: metadata)
    if !metadataURLs.isEmpty {
      return metadataURLs.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    return outputFallback
      .split(whereSeparator: \.isNewline)
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
      .map { URL(fileURLWithPath: NSString(string: $0).expandingTildeInPath) }
      .filter { FileManager.default.fileExists(atPath: $0.path) }
  }
}
