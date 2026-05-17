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
    case "extractPages":
      return try extractPages(
        input: input,
        pages: options.textValues["pages"] ?? "all",
        outputPath: options.textValues["outputPath"]
      )
    case "deletePages":
      return try deletePages(
        input: input,
        pages: options.textValues["pages"] ?? "",
        outputPath: options.textValues["outputPath"]
      )
    case "reorderPages":
      return try reorderPages(
        input: input,
        pages: options.textValues["pages"] ?? "",
        outputPath: options.textValues["outputPath"]
      )
    case "rotatePages":
      return try rotatePages(
        input: input,
        pages: options.textValues["pages"] ?? "all",
        rotation: options.textValues["rotation"] ?? "90",
        outputPath: options.textValues["outputPath"]
      )
    case "appendPages":
      return try appendPages(input: input, outputPath: options.textValues["outputPath"])
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

  private static func extractPages(input: String, pages: String, outputPath: String?) throws -> ToolResult {
    let (sourceURL, document) = try singleDocument(from: input)
    let pageIndexes = try parsePages(pages, pageCount: document.pageCount)
    let outputDocument = PDFDocument()
    for pageIndex in pageIndexes {
      try outputDocument.insertCopiedPage(from: document, at: pageIndex, insertionIndex: outputDocument.pageCount)
    }

    let outputURL = try write(
      outputDocument,
      requestedOutputPath: outputPath,
      defaultOutputURL: defaultEditedOutputURL(for: sourceURL, suffix: "extracted")
    )
    return fileResult(
      output: "Extracted \(pageIndexes.count) PDF pages into:\n\(outputURL.path)",
      outputURL: outputURL,
      sourceFileCount: 1
    )
  }

  private static func deletePages(input: String, pages: String, outputPath: String?) throws -> ToolResult {
    let (sourceURL, document) = try singleDocument(from: input)
    let deletedIndexes = Set(try parsePages(pages, pageCount: document.pageCount))
    guard deletedIndexes.count < document.pageCount else {
      throw ToolEngineError.invalidInput("Delete must leave at least one page in the PDF.")
    }

    let outputDocument = PDFDocument()
    for pageIndex in 0..<document.pageCount where !deletedIndexes.contains(pageIndex) {
      try outputDocument.insertCopiedPage(from: document, at: pageIndex, insertionIndex: outputDocument.pageCount)
    }

    let outputURL = try write(
      outputDocument,
      requestedOutputPath: outputPath,
      defaultOutputURL: defaultEditedOutputURL(for: sourceURL, suffix: "deleted")
    )
    return fileResult(
      output: "Deleted \(deletedIndexes.count) PDF pages into:\n\(outputURL.path)",
      outputURL: outputURL,
      sourceFileCount: 1
    )
  }

  private static func reorderPages(input: String, pages: String, outputPath: String?) throws -> ToolResult {
    let (sourceURL, document) = try singleDocument(from: input)
    let pageIndexes = try parsePageOrder(pages, pageCount: document.pageCount)
    let outputDocument = PDFDocument()
    for pageIndex in pageIndexes {
      try outputDocument.insertCopiedPage(from: document, at: pageIndex, insertionIndex: outputDocument.pageCount)
    }

    let outputURL = try write(
      outputDocument,
      requestedOutputPath: outputPath,
      defaultOutputURL: defaultEditedOutputURL(for: sourceURL, suffix: "reordered")
    )
    return fileResult(
      output: "Reordered \(pageIndexes.count) PDF pages into:\n\(outputURL.path)",
      outputURL: outputURL,
      sourceFileCount: 1
    )
  }

  private static func rotatePages(input: String, pages: String, rotation: String, outputPath: String?) throws -> ToolResult {
    let (sourceURL, document) = try singleDocument(from: input)
    let pageIndexes = Set(try parsePages(pages, pageCount: document.pageCount))
    let degrees = try parseRotation(rotation)
    let outputDocument = PDFDocument()
    for pageIndex in 0..<document.pageCount {
      guard let page = PDFToolkitPageCopy.copiedPage(from: document, at: pageIndex) else {
        throw ToolEngineError.invalidInput("Could not copy page \(pageIndex + 1).")
      }
      if pageIndexes.contains(pageIndex) {
        page.rotation = normalizedRotation(page.rotation + degrees)
      }
      outputDocument.insert(page, at: outputDocument.pageCount)
    }

    let outputURL = try write(
      outputDocument,
      requestedOutputPath: outputPath,
      defaultOutputURL: defaultEditedOutputURL(for: sourceURL, suffix: "rotated")
    )
    return fileResult(
      output: "Rotated \(pageIndexes.count) PDF pages into:\n\(outputURL.path)",
      outputURL: outputURL,
      sourceFileCount: 1
    )
  }

  private static func appendPages(input: String, outputPath: String?) throws -> ToolResult {
    let urls = try PathInput.existingFileURLs(from: input, allowedExtensions: ["pdf"])
    guard urls.count >= 2 else {
      throw ToolEngineError.invalidInput("Append requires at least two PDF paths.")
    }

    let outputDocument = PDFDocument()
    for url in urls {
      let document = try openDocument(url)
      for pageIndex in 0..<document.pageCount {
        try outputDocument.insertCopiedPage(from: document, at: pageIndex, insertionIndex: outputDocument.pageCount)
      }
    }

    let outputURL = try write(
      outputDocument,
      requestedOutputPath: outputPath,
      defaultOutputURL: defaultEditedOutputURL(for: urls[0], suffix: "appended")
    )
    return fileResult(
      output: "Appended pages from \(urls.count) PDFs into:\n\(outputURL.path)",
      outputURL: outputURL,
      sourceFileCount: urls.count
    )
  }

  private static func openDocument(_ url: URL) throws -> PDFDocument {
    guard let document = PDFDocument(url: url) else {
      throw ToolEngineError.invalidInput("Could not open PDF: \(url.path)")
    }
    return document
  }

  private static func singleDocument(from input: String) throws -> (URL, PDFDocument) {
    let urls = try PathInput.existingFileURLs(from: input, allowedExtensions: ["pdf"])
    guard let sourceURL = urls.first else { throw ToolEngineError.emptyInput }
    return (sourceURL, try openDocument(sourceURL))
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

  private static func parsePageOrder(_ pages: String, pageCount: Int) throws -> [Int] {
    let trimmed = pages.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.lowercased() != "all" else {
      return Array(0..<pageCount)
    }

    var indexes: [Int] = []
    for part in trimmed.split(separator: ",") {
      let value = part.trimmingCharacters(in: .whitespacesAndNewlines)
      if value.contains("-") {
        let bounds = value.split(separator: "-", maxSplits: 1).compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard bounds.count == 2, bounds[0] <= bounds[1] else {
          throw ToolEngineError.invalidInput("Invalid page range: \(value)")
        }
        for page in bounds[0]...bounds[1] {
          indexes.append(try validatedPage(page, pageCount: pageCount))
        }
      } else if let page = Int(value) {
        indexes.append(try validatedPage(page, pageCount: pageCount))
      } else {
        throw ToolEngineError.invalidInput("Invalid page order: \(value)")
      }
    }
    return indexes
  }

  private static func validatedPage(_ page: Int, pageCount: Int) throws -> Int {
    guard page >= 1, page <= pageCount else {
      throw ToolEngineError.invalidInput("Page \(page) is outside the valid range 1-\(pageCount).")
    }
    return page - 1
  }

  private static func parseRotation(_ rotation: String) throws -> Int {
    guard let degrees = Int(rotation.trimmingCharacters(in: .whitespacesAndNewlines)),
          [90, 180, 270].contains(degrees)
    else {
      throw ToolEngineError.invalidInput("Rotation must be 90, 180, or 270 degrees.")
    }
    return degrees
  }

  private static func normalizedRotation(_ rotation: Int) -> Int {
    let normalized = rotation % 360
    return normalized < 0 ? normalized + 360 : normalized
  }

  private static func defaultEditedOutputURL(for sourceURL: URL, suffix: String) -> URL {
    sourceURL
      .deletingLastPathComponent()
      .appendingPathComponent("\(sourceURL.deletingPathExtension().lastPathComponent)-\(suffix).pdf")
  }

  private static func write(_ document: PDFDocument, requestedOutputPath: String?, defaultOutputURL: URL) throws -> URL {
    let requestedOutputURL: URL
    if let outputPath = requestedOutputPath?.nilIfEmpty, outputPath != defaultConfiguredOutputPath {
      requestedOutputURL = PathInput.expandedURL(outputPath)
    } else {
      requestedOutputURL = defaultOutputURL
    }
    let outputURL = try PathInput.availableOutputFileURL(for: requestedOutputURL)
    let temporaryURL = PathInput.temporarySibling(for: outputURL)
    defer { try? FileManager.default.removeItem(at: temporaryURL) }
    guard document.write(to: temporaryURL) else {
      throw ToolEngineError.invalidInput("Could not write PDF to \(outputURL.path).")
    }
    try FileManager.default.moveItem(at: temporaryURL, to: outputURL)
    return outputURL
  }

  private static func fileResult(output: String, outputURL: URL, sourceFileCount: Int) -> ToolResult {
    var metadata = FileResultMetadata.metadata(generatedFileURLs: [outputURL])
    metadata["files"] = String(sourceFileCount)
    return ToolResult(output: output, metadata: metadata)
  }

  private static let helpText = """
  PDF Toolkit runs locally.

  Paste one PDF file path per line, or drop PDF files into the input.
  Operations:
  - Inspect: page count, metadata, encryption status
  - Extract Text: selectable PDF text
  - Merge: combine multiple PDFs into Output file
  - Split Pages: write selected pages into Output folder
  - Extract Pages: write selected pages into one PDF
  - Delete Pages: remove selected pages and save a new PDF
  - Reorder Pages: save pages in a custom order
  - Rotate Pages: rotate selected pages
  - Append Pages: append pages from additional PDFs
  """

  private static let defaultConfiguredOutputPath = "~/Desktop/workbench-labs-output.pdf"
  private static let defaultConfiguredOutputDirectory = "~/Desktop"
}

private extension String {
  var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}

private extension PDFDocument {
  func insertCopiedPage(from source: PDFDocument, at sourceIndex: Int, insertionIndex: Int) throws {
    guard let page = PDFToolkitPageCopy.copiedPage(from: source, at: sourceIndex) else {
      throw ToolEngineError.invalidInput("Could not copy page \(sourceIndex + 1).")
    }
    insert(page, at: insertionIndex)
  }
}

private enum PDFToolkitPageCopy {
  static func copiedPage(from document: PDFDocument, at index: Int) -> PDFPage? {
    guard let page = document.page(at: index) else { return nil }
    return page.copy() as? PDFPage ?? page
  }
}
