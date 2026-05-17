import Foundation
import PDFKit

public enum PDFToolkit {
  public static func run(input: String, options: ToolOptions) throws -> ToolResult {
    let operation = options.operation.isEmpty ? "inspect" : options.operation
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return ToolResult(output: helpText)
    }

    switch operation {
    case "extractText":
      return try extractText(input: input)
    case "merge":
      return try merge(input: input, outputPath: options.textValues["outputPath"])
    case "split":
      return try split(
        input: input,
        pages: options.textValues["pages"] ?? "all",
        outputDirectory: options.textValues["outputDirectory"]
      )
    default:
      return try inspect(input: input)
    }
  }

  private static func inspect(input: String) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input, allowedExtensions: ["pdf"])
    let output = try urls.map { url in
      let document = try openDocument(url)
      let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
      let author = document.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String
      let subject = document.documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String
      return """
      File: \(url.path)
      Pages: \(document.pageCount)
      Encrypted: \(document.isEncrypted ? "yes" : "no")
      Allows copying: \(document.allowsCopying ? "yes" : "no")
      Title: \(title?.nilIfEmpty ?? "-")
      Author: \(author?.nilIfEmpty ?? "-")
      Subject: \(subject?.nilIfEmpty ?? "-")
      """
    }.joined(separator: "\n\n")

    return ToolResult(output: output, metadata: ["files": String(urls.count)])
  }

  private static func extractText(input: String) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input, allowedExtensions: ["pdf"])
    let output = try urls.map { url in
      let document = try openDocument(url)
      let text = (0..<document.pageCount)
        .compactMap { document.page(at: $0)?.string }
        .joined(separator: "\n\n")
      return """
      # \(url.lastPathComponent)

      \(text.isEmpty ? "(No selectable text found.)" : text)
      """
    }.joined(separator: "\n\n")

    return ToolResult(output: output, metadata: ["files": String(urls.count)])
  }

  private static func merge(input: String, outputPath: String?) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input, allowedExtensions: ["pdf"])
    guard urls.count >= 2 else {
      throw ToolEngineError.invalidInput("Merge requires at least two PDF paths.")
    }

    let merged = PDFDocument()
    for url in urls {
      let document = try openDocument(url)
      for pageIndex in 0..<document.pageCount {
        guard let page = document.page(at: pageIndex) else { continue }
        merged.insert(page, at: merged.pageCount)
      }
    }

    let requestedOutputURL: URL
    if let outputPath = outputPath?.nilIfEmpty, outputPath != defaultConfiguredOutputPath {
      requestedOutputURL = PathInput.expandedURL(outputPath)
    } else {
      requestedOutputURL = urls[0]
        .deletingLastPathComponent()
        .appendingPathComponent("\(urls[0].deletingPathExtension().lastPathComponent)-merged.pdf")
    }
    let outputURL = try PathInput.availableOutputFileURL(for: requestedOutputURL)
    let temporaryURL = PathInput.temporarySibling(for: outputURL)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }
    guard merged.write(to: temporaryURL) else {
      throw ToolEngineError.invalidInput("Could not write merged PDF to \(outputURL.path).")
    }
    try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
    var metadata = FileResultMetadata.metadata(generatedFileURLs: [outputURL])
    metadata["files"] = String(urls.count)
    return ToolResult(output: "Merged \(urls.count) PDFs into:\n\(outputURL.path)", metadata: metadata)
  }

  private static func split(input: String, pages: String, outputDirectory: String?) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input, allowedExtensions: ["pdf"])
    guard let sourceURL = urls.first else { throw ToolEngineError.emptyInput }
    let document = try openDocument(sourceURL)
    let pageIndexes = try parsePages(pages, pageCount: document.pageCount)
    let outputDirectoryURL: URL
    if let outputDirectory = outputDirectory?.nilIfEmpty, outputDirectory != defaultConfiguredOutputDirectory {
      outputDirectoryURL = PathInput.expandedURL(outputDirectory)
    } else {
      outputDirectoryURL = sourceURL.deletingLastPathComponent()
    }
    try PathInput.prepareOutputDirectory(at: outputDirectoryURL)
    let sourceName = sourceURL.deletingPathExtension().lastPathComponent

    var outputURLs: [URL] = []
    for pageIndex in pageIndexes {
      let requestedURL = outputDirectoryURL.appendingPathComponent("\(sourceName)-page-\(pageIndex + 1).pdf")
      outputURLs.append(try PathInput.availableOutputFileURL(for: requestedURL))
    }

    var outputPaths: [String] = []
    for (pageIndex, outputURL) in zip(pageIndexes, outputURLs) {
      guard let page = document.page(at: pageIndex) else { continue }
      let splitDocument = PDFDocument()
      splitDocument.insert(page, at: 0)
      let temporaryURL = PathInput.temporarySibling(for: outputURL)
      defer { try? FileManager.default.removeItem(at: temporaryURL) }
      guard splitDocument.write(to: temporaryURL) else {
        throw ToolEngineError.invalidInput("Could not write split PDF to \(outputURL.path).")
      }
      try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
      outputPaths.append(outputURL.path)
    }

    var metadata = FileResultMetadata.metadata(generatedFileURLs: outputURLs)
    metadata["files"] = "1"
    return ToolResult(
      output: "Wrote \(outputPaths.count) PDF page files:\n\(outputPaths.joined(separator: "\n"))",
      metadata: metadata
    )
  }

  private static func openDocument(_ url: URL) throws -> PDFDocument {
    guard let document = PDFDocument(url: url) else {
      throw ToolEngineError.invalidInput("Could not open PDF: \(url.path)")
    }
    return document
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

  private static let helpText = """
  PDF Toolkit runs locally.

  Paste one PDF file path per line, or drop PDF files into the input.
  Operations:
  - Inspect: page count, metadata, encryption status
  - Extract Text: selectable PDF text
  - Merge: combine multiple PDFs into Output file
  - Split Pages: write selected pages into Output folder
  """

  private static let defaultConfiguredOutputPath = "~/Desktop/workbench-labs-output.pdf"
  private static let defaultConfiguredOutputDirectory = "~/Desktop"
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
