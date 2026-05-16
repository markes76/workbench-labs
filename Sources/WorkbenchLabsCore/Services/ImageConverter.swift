import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageConverter {
  public static func run(input: String, options: ToolOptions) throws -> ToolResult {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return ToolResult(output: helpText)
    }

    let operation = options.operation.isEmpty ? "inspect" : options.operation
    switch operation {
    case "convert":
      return try convert(input: input, options: options)
    default:
      return try inspect(input: input)
    }
  }

  private static func inspect(input: String) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input)
    let output = try urls.map { url in
      guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        throw ToolEngineError.invalidInput("Could not open image: \(url.path)")
      }
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
      let width = properties[kCGImagePropertyPixelWidth] ?? "-"
      let height = properties[kCGImagePropertyPixelHeight] ?? "-"
      let dpiWidth = properties[kCGImagePropertyDPIWidth] ?? "-"
      let dpiHeight = properties[kCGImagePropertyDPIHeight] ?? "-"
      let type = CGImageSourceGetType(source).map { UTType($0 as String)?.preferredMIMEType ?? ($0 as String) } ?? "-"

      return """
      File: \(url.path)
      Type: \(type)
      Pixels: \(width) x \(height)
      DPI: \(dpiWidth) x \(dpiHeight)
      Frames: \(CGImageSourceGetCount(source))
      """
    }.joined(separator: "\n\n")

    return ToolResult(output: output, metadata: ["files": String(urls.count)])
  }

  private static func convert(input: String, options: ToolOptions) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input)
    guard let sourceURL = urls.first else { throw ToolEngineError.emptyInput }
    let outputFormat = options.textValues["outputFormat"] ?? "png"
    guard let type = imageType(for: outputFormat) else {
      throw ToolEngineError.invalidInput("Unsupported image output format: \(outputFormat)")
    }

    guard
      let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
      throw ToolEngineError.invalidInput("Could not open image: \(sourceURL.path)")
    }

    let configuredOutputPath = options.textValues["outputPath"]?.nilIfEmpty
    let outputPath = configuredOutputPath == nil || configuredOutputPath == defaultConfiguredOutputPath
      ? defaultOutputPath(for: sourceURL, format: outputFormat)
      : configuredOutputPath!
    let outputURL = try PathInput.availableOutputFileURL(for: PathInput.expandedURL(outputPath))
    let temporaryURL = PathInput.temporarySibling(for: outputURL)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }

    guard let destination = CGImageDestinationCreateWithURL(temporaryURL as CFURL, type.identifier as CFString, 1, nil) else {
      throw ToolEngineError.invalidInput("Could not prepare image output: \(outputURL.path)")
    }

    var properties: [CFString: Any] = [:]
    if type == .jpeg || type == .heic {
      let quality = min(max(Double(options.intValues["quality"] ?? 90) / 100, 0.01), 1)
      properties[kCGImageDestinationLossyCompressionQuality] = quality
    }
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw ToolEngineError.invalidInput("Could not write converted image: \(outputURL.path)")
    }
    try FileManager.default.moveItem(at: temporaryURL, to: outputURL)

    return ToolResult(output: "Converted image to \(outputFormat.uppercased()):\n\(outputURL.path)")
  }

  private static func imageType(for format: String) -> UTType? {
    switch format.lowercased() {
    case "png": .png
    case "jpg", "jpeg": .jpeg
    case "heic": .heic
    case "tif", "tiff": .tiff
    case "gif": .gif
    default: nil
    }
  }

  private static func defaultOutputPath(for inputURL: URL, format: String) -> String {
    let filename = inputURL.deletingPathExtension().lastPathComponent + ".\(format)"
    return inputURL.deletingLastPathComponent().appendingPathComponent(filename).path
  }

  private static let defaultConfiguredOutputPath = "~/Desktop/workbench-labs-image.png"

  private static let helpText = """
  Image Converter runs locally.

  Paste or drop an image path, then choose:
  - Inspect: dimensions, type, frame count, DPI
  - Convert: PNG, JPEG, HEIC, TIFF, or GIF
  """
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
