import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageMetadataInspector {
  public static func run(input: String, options: ToolOptions) throws -> ToolResult {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return ToolResult(output: helpText)
    }

    let operation = options.operation.isEmpty ? "inspect" : options.operation
    switch operation {
    case "scrub":
      return try scrub(input: input, options: options)
    default:
      return try inspect(input: input)
    }
  }

  private static func inspect(input: String) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input)
    var hasGPS = false
    let summaries = try urls.map { url in
      let summary = try metadataSummary(for: url)
      hasGPS = hasGPS || summary.hasGPS
      return summary.output
    }

    return ToolResult(
      output: summaries.joined(separator: "\n\n"),
      metadata: [
        "files": String(urls.count),
        "gps": hasGPS ? "present" : "absent"
      ]
    )
  }

  private static func scrub(input: String, options: ToolOptions) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input)
    let outputDirectory = options.textValues["outputDirectory"]?.nilIfEmpty.map(PathInput.expandedURL)
    if let outputDirectory {
      try PathInput.prepareOutputDirectory(at: outputDirectory)
    }

    let scrubOptions = MetadataScrubOptions(
      removeGPS: options.boolValues["removeGPS"] ?? true,
      removeCameraMetadata: options.boolValues["removeCameraMetadata"] ?? false,
      removeDescriptiveMetadata: options.boolValues["removeDescriptiveMetadata"] ?? false,
      removeAllMetadata: options.boolValues["removeAllMetadata"] ?? false
    )

    var outputURLs: [URL] = []
    var summaries: [String] = []
    for url in urls {
      let result = try scrub(url, outputDirectory: outputDirectory, options: scrubOptions)
      outputURLs.append(result.outputURL)
      summaries.append("""
      \(url.lastPathComponent)
      Removed: \(result.removedDescriptions.isEmpty ? "nothing selected" : result.removedDescriptions.joined(separator: ", "))
      Output: \(result.outputURL.path)
      """)
    }

    var metadata = FileResultMetadata.metadata(generatedFileURLs: outputURLs)
    metadata["files"] = String(urls.count)
    metadata["removedGPS"] = scrubOptions.removeGPS || scrubOptions.removeAllMetadata ? "true" : "false"
    return ToolResult(
      output: "Scrubbed \(outputURLs.count) image\(outputURLs.count == 1 ? "" : "s"):\n\n\(summaries.joined(separator: "\n\n"))",
      metadata: metadata
    )
  }

  private static func metadataSummary(for url: URL) throws -> ImageMetadataSummary {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      throw ToolEngineError.invalidInput("Could not open image: \(url.path)")
    }

    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    let typeDescription = CGImageSourceGetType(source)
      .flatMap { UTType($0 as String)?.preferredMIMEType ?? ($0 as String) } ?? "-"
    let width = properties[kCGImagePropertyPixelWidth].map(String.init(describing:)) ?? "-"
    let height = properties[kCGImagePropertyPixelHeight].map(String.init(describing:)) ?? "-"
    let dpiWidth = properties[kCGImagePropertyDPIWidth].map(String.init(describing:)) ?? "-"
    let dpiHeight = properties[kCGImagePropertyDPIHeight].map(String.init(describing:)) ?? "-"
    let colorModel = properties[kCGImagePropertyColorModel].map(String.init(describing:)) ?? "-"
    let profile = properties[kCGImagePropertyProfileName].map(String.init(describing:)) ?? "-"
    let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]
    let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
    let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
    let iptc = properties[kCGImagePropertyIPTCDictionary] as? [CFString: Any]

    var lines = [
      "File: \(url.path)",
      "Type: \(typeDescription)",
      "Pixels: \(width) x \(height)",
      "DPI: \(dpiWidth) x \(dpiHeight)",
      "Frames: \(CGImageSourceGetCount(source))",
      "Color model: \(colorModel)",
      "Color profile: \(profile)",
      "GPS: \(gps == nil ? "absent" : "present")"
    ]

    if let gps {
      if let latitude = coordinate(from: gps, valueKey: kCGImagePropertyGPSLatitude, refKey: kCGImagePropertyGPSLatitudeRef) {
        lines.append("Latitude: \(formattedCoordinate(latitude))")
      }
      if let longitude = coordinate(from: gps, valueKey: kCGImagePropertyGPSLongitude, refKey: kCGImagePropertyGPSLongitudeRef) {
        lines.append("Longitude: \(formattedCoordinate(longitude))")
      }
      if let altitude = gps[kCGImagePropertyGPSAltitude] {
        lines.append("Altitude: \(altitude)")
      }
      lines.append("Privacy: geolocation metadata found")
    } else {
      lines.append("Privacy: no GPS geolocation metadata found")
    }

    lines.append("EXIF: \(exif == nil ? "absent" : "present")")
    if let exif {
      appendKnownValue(from: exif, key: kCGImagePropertyExifDateTimeOriginal, label: "Date taken", to: &lines)
      appendKnownValue(from: exif, key: kCGImagePropertyExifLensModel, label: "Lens", to: &lines)
    }
    lines.append("TIFF/camera: \(tiff == nil ? "absent" : "present")")
    if let tiff {
      appendKnownValue(from: tiff, key: kCGImagePropertyTIFFMake, label: "Camera make", to: &lines)
      appendKnownValue(from: tiff, key: kCGImagePropertyTIFFModel, label: "Camera model", to: &lines)
      appendKnownValue(from: tiff, key: kCGImagePropertyTIFFArtist, label: "Artist", to: &lines)
      appendKnownValue(from: tiff, key: kCGImagePropertyTIFFCopyright, label: "Copyright", to: &lines)
    }
    lines.append("IPTC/descriptive: \(iptc == nil ? "absent" : "present")")

    return ImageMetadataSummary(output: lines.joined(separator: "\n"), hasGPS: gps != nil)
  }

  private static func scrub(_ url: URL, outputDirectory: URL?, options: MetadataScrubOptions) throws -> ScrubbedImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
      throw ToolEngineError.invalidInput("Could not open image: \(url.path)")
    }

    let type = destinationType(for: source)
    let outputURL = try PathInput.availableOutputFileURL(for: requestedOutputURL(for: url, outputDirectory: outputDirectory, type: type))
    let temporaryURL = PathInput.temporarySibling(for: outputURL)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }

    guard let destination = CGImageDestinationCreateWithURL(temporaryURL as CFURL, type.identifier as CFString, CGImageSourceGetCount(source), nil) else {
      throw ToolEngineError.invalidInput("Could not prepare image output: \(outputURL.path)")
    }

    for index in 0..<CGImageSourceGetCount(source) {
      guard let image = CGImageSourceCreateImageAtIndex(source, index, nil) else {
        throw ToolEngineError.invalidInput("Could not read image frame \(index + 1): \(url.path)")
      }
      let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any] ?? [:]
      let scrubbedProperties = scrubbed(properties, options: options)
      CGImageDestinationAddImage(destination, image, scrubbedProperties as CFDictionary)
    }

    guard CGImageDestinationFinalize(destination) else {
      throw ToolEngineError.invalidInput("Could not write scrubbed image: \(outputURL.path)")
    }
    try FileManager.default.moveItem(at: temporaryURL, to: outputURL)

    return ScrubbedImage(outputURL: outputURL, removedDescriptions: options.removedDescriptions)
  }

  private static func scrubbed(_ properties: [CFString: Any], options: MetadataScrubOptions) -> [CFString: Any] {
    if options.removeAllMetadata {
      return [:]
    }

    var output = properties
    if options.removeGPS {
      output.removeValue(forKey: kCGImagePropertyGPSDictionary)
    }
    if options.removeCameraMetadata {
      output.removeValue(forKey: kCGImagePropertyExifDictionary)
      output.removeValue(forKey: kCGImagePropertyTIFFDictionary)
    }
    if options.removeDescriptiveMetadata {
      output.removeValue(forKey: kCGImagePropertyIPTCDictionary)
      output.removeValue(forKey: kCGImagePropertyPNGDictionary)
      output.removeValue(forKey: kCGImagePropertyGIFDictionary)
    }
    return output
  }

  private static func destinationType(for source: CGImageSource) -> UTType {
    guard let identifier = CGImageSourceGetType(source) as String?,
          let sourceType = UTType(identifier),
          supportedTypes.contains(sourceType)
    else {
      return .jpeg
    }
    return sourceType
  }

  private static let supportedTypes: Set<UTType> = [.jpeg, .png, .heic, .tiff, .gif]

  private static func requestedOutputURL(for sourceURL: URL, outputDirectory: URL?, type: UTType) -> URL {
    let ext = type.preferredFilenameExtension ?? "jpg"
    return (outputDirectory ?? sourceURL.deletingLastPathComponent())
      .appendingPathComponent("\(sourceURL.deletingPathExtension().lastPathComponent)-metadata-scrubbed.\(ext)")
  }

  private static func coordinate(from gps: [CFString: Any], valueKey: CFString, refKey: CFString) -> Double? {
    guard let value = numericValue(gps[valueKey]) else { return nil }
    let reference = (gps[refKey] as? String)?.uppercased()
    if reference == "S" || reference == "W" {
      return -value
    }
    return value
  }

  private static func numericValue(_ value: Any?) -> Double? {
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    if let double = value as? Double {
      return double
    }
    if let string = value as? String {
      return Double(string)
    }
    return nil
  }

  private static func formattedCoordinate(_ value: Double) -> String {
    let rounded = (value * 1_000_000).rounded() / 1_000_000
    return String(format: "%.6g", rounded)
  }

  private static func appendKnownValue(from dictionary: [CFString: Any], key: CFString, label: String, to lines: inout [String]) {
    guard let value = dictionary[key] else { return }
    lines.append("\(label): \(value)")
  }

  private static let helpText = """
  Image Metadata Inspector runs locally.

  Paste or drop one or more image paths, then choose:
  - Inspect: report image dimensions, color profile, EXIF, TIFF, IPTC, and GPS location presence.
  - Scrub: write safe copies with GPS location removed by default before sharing online.
  """
}

private struct ImageMetadataSummary {
  var output: String
  var hasGPS: Bool
}

private struct ScrubbedImage {
  var outputURL: URL
  var removedDescriptions: [String]
}

private struct MetadataScrubOptions {
  var removeGPS: Bool
  var removeCameraMetadata: Bool
  var removeDescriptiveMetadata: Bool
  var removeAllMetadata: Bool

  var removedDescriptions: [String] {
    if removeAllMetadata {
      return ["all metadata"]
    }

    var descriptions: [String] = []
    if removeGPS {
      descriptions.append("GPS location")
    }
    if removeCameraMetadata {
      descriptions.append("camera metadata")
    }
    if removeDescriptiveMetadata {
      descriptions.append("descriptive metadata")
    }
    return descriptions
  }
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
