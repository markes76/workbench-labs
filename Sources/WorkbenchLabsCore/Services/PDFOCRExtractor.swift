import AppKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

public enum PDFOCRExtractor {
  private static let processRunner = ExternalProcessRunner()

  public static func run(input: String, options: ToolOptions) throws -> ToolResult {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return ToolResult(output: helpText)
    }

    let urls = try PathInput.existingFileURLs(from: input, allowedExtensions: ["pdf"])
    guard let sourceURL = urls.first else { throw ToolEngineError.emptyInput }
    guard let document = PDFDocument(url: sourceURL) else {
      throw ToolEngineError.invalidInput("Could not open PDF: \(sourceURL.path)")
    }

    let pageIndexes = try parsePages(options.textValues["pages"] ?? "all", pageCount: document.pageCount)
    let languageConfiguration = try languageConfiguration(for: options.textValues["languages"] ?? "en")
    let backend = try recognitionBackend(for: languageConfiguration)
    var pageOutputs: [String] = []
    var recognizedLineCount = 0
    var confidenceValues: [Float] = []

    for pageIndex in pageIndexes {
      guard let page = document.page(at: pageIndex) else { continue }
      let observations = try recognizeText(in: page, using: backend)
      recognizedLineCount += observations.count
      confidenceValues.append(contentsOf: observations.compactMap(\.confidence))
      let text = observations.map(\.text).joined(separator: "\n")
      let confidenceSummary = confidenceSummary(for: observations)
      pageOutputs.append("""
      # Page \(pageIndex + 1)
      \(confidenceSummary)

      \(text.isEmpty ? "(No text recognized.)" : text)
      """)
    }

    let averageConfidence = confidenceValues.isEmpty
      ? nil
      : confidenceValues.reduce(0, +) / Float(confidenceValues.count)

    var metadata = [
      "files": "1",
      "pages": String(pageIndexes.count),
      "recognizedTextLines": String(recognizedLineCount),
      "recognitionEngine": backend.metadataEngine,
      "recognitionLanguages": backend.metadataLanguages
    ]
    if let averageConfidence {
      metadata["averageConfidence"] = String(format: "%.2f", averageConfidence)
    }

    return ToolResult(
      output: pageOutputs.joined(separator: "\n\n"),
      diagnostics: [
        ToolDiagnostic(.info, "OCR processed \(pageIndexes.count) page\(pageIndexes.count == 1 ? "" : "s") locally with \(backend.displayName).")
      ],
      metadata: metadata
    )
  }

  static func hasTesseractLanguages(_ languageCodes: [String]) -> Bool {
    guard let tesseractURL = processRunner.executable(named: "tesseract") else { return false }
    let availableLanguages = tesseractLanguages(executableURL: tesseractURL)
    return Set(languageCodes).isSubset(of: availableLanguages)
  }

  private static func recognizeText(in page: PDFPage, using backend: OCRBackend) throws -> [RecognizedLine] {
    switch backend {
    case .vision(let languageCodes):
      return try recognizeTextWithVision(in: page, languageCodes: languageCodes)
    case .tesseract(let executableURL, let languageCodes):
      return try recognizeTextWithTesseract(in: page, executableURL: executableURL, languageCodes: languageCodes)
    }
  }

  private static func recognizeTextWithVision(in page: PDFPage, languageCodes: [String]) throws -> [RecognizedLine] {
    let cgImage = try render(page: page)
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = languageCodes

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])

    let observations = (request.results ?? [])
      .sorted { lhs, rhs in
        if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > 0.01 {
          return lhs.boundingBox.minY > rhs.boundingBox.minY
        }
        return lhs.boundingBox.minX < rhs.boundingBox.minX
      }

    return observations.compactMap { observation in
      guard let candidate = observation.topCandidates(1).first else { return nil }
      return RecognizedLine(text: candidate.string, confidence: candidate.confidence)
    }
  }

  private static func recognizeTextWithTesseract(in page: PDFPage, executableURL: URL, languageCodes: [String]) throws -> [RecognizedLine] {
    let cgImage = try render(page: page)
    let imageURL = try writeTemporaryPNG(cgImage)
    defer { try? FileManager.default.removeItem(at: imageURL.deletingLastPathComponent()) }

    let result = try processRunner.run(
      executableURL: executableURL,
      arguments: [
        imageURL.path,
        "stdout",
        "-l",
        languageCodes.joined(separator: "+"),
        "--psm",
        "6"
      ],
      timeout: 120
    )
    guard result.isSuccess else {
      let detail = result.stderrString.nilIfEmpty ?? result.stdoutString.nilIfEmpty ?? "Tesseract OCR failed."
      throw ToolEngineError.runtimeUnavailable(detail)
    }

    let lines = result.stdoutString
      .split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    return lines.map { RecognizedLine(text: $0, confidence: nil) }
  }

  private static func render(page: PDFPage) throws -> CGImage {
    let pageBounds = page.bounds(for: .mediaBox)
    let scale: CGFloat = 2
    let width = max(Int(pageBounds.width * scale), 1)
    let height = max(Int(pageBounds.height * scale), 1)
    guard let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      throw ToolEngineError.invalidInput("Could not render PDF page for OCR.")
    }

    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    context.saveGState()
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)
    context.restoreGState()

    guard let image = context.makeImage() else {
      throw ToolEngineError.invalidInput("Could not render PDF page image for OCR.")
    }
    return image
  }

  private static func writeTemporaryPNG(_ image: CGImage) throws -> URL {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("WorkbenchLabsOCR-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    let imageURL = directoryURL.appendingPathComponent("page.png")

    guard let destination = CGImageDestinationCreateWithURL(imageURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
      throw ToolEngineError.invalidInput("Could not prepare a temporary image for OCR.")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
      throw ToolEngineError.invalidInput("Could not write a temporary image for OCR.")
    }
    return imageURL
  }

  private static func languageConfiguration(for rawValue: String) throws -> OCRLanguageConfiguration {
    switch rawValue {
    case "en", "":
      return OCRLanguageConfiguration(
        label: "English",
        visionLanguageCodes: ["en-US"],
        tesseractLanguageCodes: []
      )
    case "he":
      return OCRLanguageConfiguration(
        label: "Hebrew",
        visionLanguageCodes: [],
        tesseractLanguageCodes: ["heb"]
      )
    case "en-he":
      return OCRLanguageConfiguration(
        label: "English + Hebrew",
        visionLanguageCodes: [],
        tesseractLanguageCodes: ["eng", "heb"]
      )
    default:
      throw ToolEngineError.invalidInput("Unsupported OCR language option: \(rawValue)")
    }
  }

  private static func recognitionBackend(for configuration: OCRLanguageConfiguration) throws -> OCRBackend {
    if !configuration.tesseractLanguageCodes.isEmpty {
      guard let tesseractURL = processRunner.executable(named: "tesseract") else {
        throw ToolEngineError.runtimeUnavailable("Hebrew OCR requires local Tesseract. Install it with: brew install tesseract tesseract-lang")
      }
      let availableLanguages = tesseractLanguages(executableURL: tesseractURL)
      let missingLanguages = configuration.tesseractLanguageCodes.filter { !availableLanguages.contains($0) }
      guard missingLanguages.isEmpty else {
        throw ToolEngineError.runtimeUnavailable(
          "Hebrew OCR requires Tesseract language data for \(missingLanguages.joined(separator: ", ")). Install it with: brew install tesseract-lang"
        )
      }
      return .tesseract(executableURL: tesseractURL, languageCodes: configuration.tesseractLanguageCodes)
    }

    let supportedLanguages = visionSupportedLanguages()
    let languageCodes = configuration.visionLanguageCodes.filter { supportedLanguages.contains($0) }
    guard !languageCodes.isEmpty else {
      throw ToolEngineError.runtimeUnavailable("Apple Vision does not support \(configuration.label) OCR on this macOS runtime.")
    }
    return .vision(languageCodes: languageCodes)
  }

  private static func visionSupportedLanguages() -> Set<String> {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    let languages = (try? request.supportedRecognitionLanguages()) ?? []
    return Set(languages)
  }

  private static func tesseractLanguages(executableURL: URL) -> Set<String> {
    guard
      let result = try? processRunner.run(
        executableURL: executableURL,
        arguments: ["--list-langs"],
        timeout: 20
      ),
      result.isSuccess
    else {
      return []
    }

    let combinedOutput = "\(result.stdoutString)\n\(result.stderrString)"
    return Set(
      combinedOutput
        .split(whereSeparator: \.isNewline)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.range(of: #"^[A-Za-z_]+$"#, options: .regularExpression) != nil }
    )
  }

  private static func parsePages(_ pages: String, pageCount: Int) throws -> [Int] {
    let trimmed = pages.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.lowercased() != "all" else {
      return Array(0..<pageCount)
    }

    var indexes: Set<Int> = []
    for part in trimmed.split(separator: ",") {
      let value = part.trimmingCharacters(in: .whitespacesAndNewlines)
      if value.contains("-") {
        let bounds = value.split(separator: "-", maxSplits: 1).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard bounds.count == 2, bounds[0] <= bounds[1] else {
          throw ToolEngineError.invalidInput("Invalid page range: \(value)")
        }
        for page in bounds[0]...bounds[1] {
          indexes.insert(try validatedPage(page, pageCount: pageCount))
        }
      } else if let page = Int(value) {
        indexes.insert(try validatedPage(page, pageCount: pageCount))
      } else {
        throw ToolEngineError.invalidInput("Invalid page selection: \(value)")
      }
    }
    return indexes.sorted()
  }

  private static func validatedPage(_ page: Int, pageCount: Int) throws -> Int {
    guard page >= 1, page <= pageCount else {
      throw ToolEngineError.invalidInput("Page \(page) is outside the valid range 1-\(pageCount).")
    }
    return page - 1
  }

  private static func confidenceSummary(for observations: [RecognizedLine]) -> String {
    let confidenceValues = observations.compactMap(\.confidence)
    guard !confidenceValues.isEmpty else {
      return "Confidence: n/a"
    }
    let average = confidenceValues.reduce(0, +) / Float(confidenceValues.count)
    return "Confidence: \(String(format: "%.2f", average))"
  }

  private static let helpText = """
  PDF OCR Text Extractor runs locally with Apple Vision and Tesseract.

  Paste or drop one PDF file path. Use Pages for all pages, individual pages, or ranges such as 1,3-5.
  English OCR uses Apple Vision. Hebrew and English + Hebrew OCR use local Tesseract with Hebrew language data.
  """
}

private struct OCRLanguageConfiguration {
  var label: String
  var visionLanguageCodes: [String]
  var tesseractLanguageCodes: [String]
}

private enum OCRBackend {
  case vision(languageCodes: [String])
  case tesseract(executableURL: URL, languageCodes: [String])

  var displayName: String {
    switch self {
    case .vision:
      return "Apple Vision"
    case .tesseract:
      return "Tesseract"
    }
  }

  var metadataEngine: String {
    switch self {
    case .vision:
      return "vision"
    case .tesseract:
      return "tesseract"
    }
  }

  var metadataLanguages: String {
    switch self {
    case .vision(let languageCodes), .tesseract(_, let languageCodes):
      return languageCodes.joined(separator: "+")
    }
  }
}

private struct RecognizedLine {
  var text: String
  var confidence: Float?
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
