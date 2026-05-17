import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum BatchImageResizer {
  public static func run(input: String, options: ToolOptions) throws -> ToolResult {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return ToolResult(output: helpText)
    }

    let urls = try PathInput.existingFileURLs(from: input)
    guard !urls.isEmpty else { throw ToolEngineError.emptyInput }

    let resizeMode = options.textValues["resizeMode"] ?? "max"
    let outputFormat = options.textValues["outputFormat"] ?? "jpeg"
    let outputDirectory = options.textValues["outputDirectory"]?.nilIfEmpty.map(PathInput.expandedURL)
    if let outputDirectory {
      try PathInput.prepareOutputDirectory(at: outputDirectory)
    }

    var outputURLs: [URL] = []
    var summaries: [String] = []
    for sourceURL in urls {
      let processed = try process(sourceURL, resizeMode: resizeMode, outputFormat: outputFormat, outputDirectory: outputDirectory, options: options)
      outputURLs.append(processed.outputURL)
      summaries.append("\(sourceURL.lastPathComponent): \(processed.originalWidth)x\(processed.originalHeight) -> \(processed.outputWidth)x\(processed.outputHeight)\n\(processed.outputURL.path)")
    }

    var metadata = FileResultMetadata.metadata(generatedFileURLs: outputURLs)
    metadata["files"] = String(urls.count)
    metadata["resizeMode"] = resizeMode
    metadata["outputFormat"] = outputFormat
    return ToolResult(
      output: "Processed \(outputURLs.count) image\(outputURLs.count == 1 ? "" : "s"):\n\n\(summaries.joined(separator: "\n\n"))",
      metadata: metadata
    )
  }

  private static func process(
    _ sourceURL: URL,
    resizeMode: String,
    outputFormat: String,
    outputDirectory: URL?,
    options: ToolOptions
  ) throws -> ProcessedImage {
    guard
      let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
      throw ToolEngineError.invalidInput("Could not open image: \(sourceURL.path)")
    }

    let sourceType = CGImageSourceGetType(source).flatMap { UTType($0 as String) }
    let type = try destinationType(outputFormat: outputFormat, sourceType: sourceType)
    let targetSize = targetSize(for: CGSize(width: image.width, height: image.height), resizeMode: resizeMode, options: options)
    let outputImage = try rendered(image, size: targetSize)
    let outputURL = try PathInput.availableOutputFileURL(
      for: requestedOutputURL(for: sourceURL, outputDirectory: outputDirectory, type: type)
    )
    let temporaryURL = PathInput.temporarySibling(for: outputURL)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }

    guard let destination = CGImageDestinationCreateWithURL(temporaryURL as CFURL, type.identifier as CFString, 1, nil) else {
      throw ToolEngineError.invalidInput("Could not prepare image output: \(outputURL.path)")
    }

    var properties: [CFString: Any] = [:]
    if !(options.boolValues["stripMetadata"] ?? true),
       let sourceProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
      properties = sourceProperties
    }
    if type == .jpeg || type == .heic {
      properties[kCGImageDestinationLossyCompressionQuality] = min(max(Double(options.intValues["quality"] ?? 82) / 100, 0.01), 1)
    }

    CGImageDestinationAddImage(destination, outputImage, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw ToolEngineError.invalidInput("Could not write image output: \(outputURL.path)")
    }
    try FileManager.default.moveItem(at: temporaryURL, to: outputURL)

    return ProcessedImage(
      outputURL: outputURL,
      originalWidth: image.width,
      originalHeight: image.height,
      outputWidth: outputImage.width,
      outputHeight: outputImage.height
    )
  }

  private static func destinationType(outputFormat: String, sourceType: UTType?) throws -> UTType {
    if outputFormat == "original" {
      if let sourceType, supportedTypes.contains(sourceType) {
        return sourceType
      }
      return .png
    }
    guard let type = supportedType(for: outputFormat) else {
      throw ToolEngineError.invalidInput("Unsupported image output format: \(outputFormat)")
    }
    return type
  }

  private static func supportedType(for format: String) -> UTType? {
    switch format.lowercased() {
    case "png": .png
    case "jpg", "jpeg": .jpeg
    case "heic": .heic
    case "tif", "tiff": .tiff
    default: nil
    }
  }

  private static let supportedTypes: Set<UTType> = [.png, .jpeg, .heic, .tiff]

  private static func targetSize(for originalSize: CGSize, resizeMode: String, options: ToolOptions) -> CGSize {
    let width = max(originalSize.width, 1)
    let height = max(originalSize.height, 1)
    let aspect = width / height

    switch resizeMode {
    case "width":
      let targetWidth = CGFloat(max(options.intValues["width"] ?? Int(width), 1))
      return CGSize(width: targetWidth, height: max((targetWidth / aspect).rounded(), 1))
    case "height":
      let targetHeight = CGFloat(max(options.intValues["height"] ?? Int(height), 1))
      return CGSize(width: max((targetHeight * aspect).rounded(), 1), height: targetHeight)
    case "scale":
      let scale = max(CGFloat(options.intValues["scalePercent"] ?? 100) / 100, 0.01)
      return CGSize(width: max((width * scale).rounded(), 1), height: max((height * scale).rounded(), 1))
    case "none":
      return originalSize
    default:
      let maxDimension = CGFloat(max(options.intValues["maxDimension"] ?? max(Int(width), Int(height)), 1))
      let longest = max(width, height)
      guard longest > maxDimension else { return originalSize }
      let scale = maxDimension / longest
      return CGSize(width: max((width * scale).rounded(), 1), height: max((height * scale).rounded(), 1))
    }
  }

  private static func rendered(_ image: CGImage, size: CGSize) throws -> CGImage {
    let width = max(Int(size.width.rounded()), 1)
    let height = max(Int(size.height.rounded()), 1)
    if width == image.width, height == image.height {
      return image
    }
    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      throw ToolEngineError.invalidInput("Could not prepare resized image canvas.")
    }
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    guard let output = context.makeImage() else {
      throw ToolEngineError.invalidInput("Could not render resized image.")
    }
    return output
  }

  private static func requestedOutputURL(for sourceURL: URL, outputDirectory: URL?, type: UTType) -> URL {
    let ext = type.preferredFilenameExtension ?? "png"
    return (outputDirectory ?? sourceURL.deletingLastPathComponent())
      .appendingPathComponent("\(sourceURL.deletingPathExtension().lastPathComponent)-resized.\(ext)")
  }

  private static let helpText = """
  Batch Image Resizer & Compressor runs locally.

  Paste or drop one image path per line, then choose a resize mode, output format, quality, metadata stripping, and optional output folder.
  """
}

private struct ProcessedImage {
  var outputURL: URL
  var originalWidth: Int
  var originalHeight: Int
  var outputWidth: Int
  var outputHeight: Int
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
