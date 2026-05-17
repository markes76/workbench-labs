import AppKit
import PDFKit
import XCTest
@testable import WorkbenchLabsCore

final class PDFAndMediaToolTests: XCTestCase {
  private let runner = ToolRunner()
  private var tempURLs: [URL] = []

  override func tearDown() {
    for url in tempURLs {
      try? FileManager.default.removeItem(at: url)
    }
    tempURLs.removeAll()
    super.tearDown()
  }

  func testPDFToolkitInspectsLocalPDF() async throws {
    let pdfURL = try makePDF(named: "sample.pdf")
    let result = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path)

    XCTAssertTrue(result.output.contains("Pages: 1"), result.output)
    XCTAssertTrue(result.output.contains(pdfURL.path), result.output)
  }

  func testPDFToolkitExtractsTextFromLocalPDF() async throws {
    let pdfURL = try makePDF(named: "text.pdf", text: "Workbench Labs PDF")
    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "extractText"

    let result = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path, options: options)

    XCTAssertTrue(result.output.contains(pdfURL.lastPathComponent), result.output)
    XCTAssertTrue(result.output.contains("No selectable text found") || result.output.contains("Workbench Labs PDF"), result.output)
  }

  func testImageConverterInspectsAndConvertsLocalImage() async throws {
    let inputURL = try makePNG(named: "input.png")
    let inspect = try await runner.run(toolID: .imageConverter, input: inputURL.path)
    XCTAssertTrue(inspect.output.contains("Pixels: 8 x 6"), inspect.output)

    let outputURL = tempURL(named: "converted.jpg")
    var options = ToolRegistry.definition(for: .imageConverter).defaultOptions
    options.operation = "convert"
    options.textValues["outputFormat"] = "jpeg"
    options.textValues["outputPath"] = outputURL.path
    options.intValues["quality"] = 80

    let converted = try await runner.run(toolID: .imageConverter, input: inputURL.path, options: options)

    XCTAssertTrue(converted.output.contains(outputURL.path), converted.output)
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    XCTAssertEqual(FileResultMetadata.generatedFileURLs(from: converted.metadata), [outputURL])
  }

  func testPDFToolkitSplitsSelectedPagesIntoRealOnePagePDFs() async throws {
    let pdfURL = try makePDF(named: "eight-pages.pdf", pageCount: 8)
    let outputDirectoryURL = try tempDirectory(named: "split-output")
    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "split"
    options.textValues["pages"] = "2,4-5"
    options.textValues["outputDirectory"] = outputDirectoryURL.path

    let result = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path, options: options)

    let sourceName = pdfURL.deletingPathExtension().lastPathComponent
    let expectedURLs = [
      outputDirectoryURL.appendingPathComponent("\(sourceName)-page-2.pdf"),
      outputDirectoryURL.appendingPathComponent("\(sourceName)-page-4.pdf"),
      outputDirectoryURL.appendingPathComponent("\(sourceName)-page-5.pdf")
    ]
    XCTAssertTrue(result.output.contains("Wrote 3 PDF page files"), result.output)
    XCTAssertEqual(FileResultMetadata.generatedFileURLs(from: result.metadata), expectedURLs)
    for url in expectedURLs {
      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing split file: \(url.path)")
      XCTAssertEqual(PDFDocument(url: url)?.pageCount, 1, "Split file should contain exactly one page: \(url.path)")
    }
  }

  func testPDFToolkitSplitCreatesCollisionSafeFilesWhenOutputExists() async throws {
    let pdfURL = try makePDF(named: "collision.pdf", pageCount: 1)
    let outputDirectoryURL = try tempDirectory(named: "split-collision")
    let sourceName = pdfURL.deletingPathExtension().lastPathComponent
    let existingURL = outputDirectoryURL.appendingPathComponent("\(sourceName)-page-1.pdf")
    try Data("existing".utf8).write(to: existingURL)

    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "split"
    options.textValues["pages"] = "1"
    options.textValues["outputDirectory"] = outputDirectoryURL.path

    let result = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path, options: options)

    XCTAssertEqual(try Data(contentsOf: existingURL), Data("existing".utf8))
    XCTAssertFalse(result.output.contains(existingURL.path), result.output)
    let createdPath = result.output.split(separator: "\n").last.map(String.init) ?? ""
    XCTAssertTrue(FileManager.default.fileExists(atPath: createdPath), result.output)
    XCTAssertEqual(PDFDocument(url: URL(fileURLWithPath: createdPath))?.pageCount, 1)
    XCTAssertEqual(FileResultMetadata.generatedFileURLs(from: result.metadata).map(\.path), [createdPath])
  }

  func testImageConverterCreatesCollisionSafeOutputWithoutOverwritingExistingFile() async throws {
    let inputURL = try makePNG(named: "overwrite-input.png")
    let outputURL = tempURL(named: "existing.jpg")
    let original = Data("existing".utf8)
    try original.write(to: outputURL)
    tempURLs.append(outputURL)

    var options = ToolRegistry.definition(for: .imageConverter).defaultOptions
    options.operation = "convert"
    options.textValues["outputFormat"] = "jpeg"
    options.textValues["outputPath"] = outputURL.path

    let result = try await runner.run(toolID: .imageConverter, input: inputURL.path, options: options)

    XCTAssertEqual(try Data(contentsOf: outputURL), original)
    XCTAssertFalse(result.output.contains(outputURL.path), result.output)
    let createdPath = result.output.split(separator: "\n").last.map(String.init) ?? ""
    XCTAssertTrue(FileManager.default.fileExists(atPath: createdPath), result.output)
    XCTAssertEqual(FileResultMetadata.generatedFileURLs(from: result.metadata).map(\.path), [createdPath])
  }

  func testPDFMergeCreatesCollisionSafeOutputWithoutOverwritingExistingFile() async throws {
    let firstURL = try makePDF(named: "merge-a.pdf")
    let secondURL = try makePDF(named: "merge-b.pdf")
    let outputURL = tempURL(named: "existing-output.pdf")
    let original = Data("existing".utf8)
    try original.write(to: outputURL)
    tempURLs.append(outputURL)

    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "merge"
    options.textValues["outputPath"] = outputURL.path

    let result = try await runner.run(toolID: .pdfToolkit, input: "\(firstURL.path)\n\(secondURL.path)", options: options)

    XCTAssertEqual(try Data(contentsOf: outputURL), original)
    XCTAssertFalse(result.output.contains(outputURL.path), result.output)
    let createdPath = result.output.split(separator: "\n").last.map(String.init) ?? ""
    XCTAssertTrue(FileManager.default.fileExists(atPath: createdPath), result.output)
    XCTAssertEqual(PDFDocument(url: URL(fileURLWithPath: createdPath))?.pageCount, 2)
    XCTAssertEqual(FileResultMetadata.generatedFileURLs(from: result.metadata).map(\.path), [createdPath])
  }

  func testPDFToolkitExtractsSelectedPagesIntoOnePDF() async throws {
    let pdfURL = try makeSizedPDF(named: "extract-pages.pdf", pageSizes: [
      CGSize(width: 200, height: 120),
      CGSize(width: 220, height: 120),
      CGSize(width: 240, height: 120),
      CGSize(width: 260, height: 120)
    ])
    let outputURL = tempURL(named: "extracted-pages.pdf")
    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "extractPages"
    options.textValues["pages"] = "2,4"
    options.textValues["outputPath"] = outputURL.path

    let result = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path, options: options)

    let outputDocument = try XCTUnwrap(PDFDocument(url: outputURL))
    XCTAssertTrue(result.output.contains(outputURL.path), result.output)
    XCTAssertEqual(outputDocument.pageCount, 2)
    XCTAssertEqual(outputDocument.page(at: 0)?.bounds(for: .mediaBox).width, 220)
    XCTAssertEqual(outputDocument.page(at: 1)?.bounds(for: .mediaBox).width, 260)
    XCTAssertEqual(FileResultMetadata.generatedFileURLs(from: result.metadata), [outputURL])
  }

  func testPDFToolkitDeletesSelectedPages() async throws {
    let pdfURL = try makePDF(named: "delete-pages.pdf", pageCount: 4)
    let outputURL = tempURL(named: "deleted-pages.pdf")
    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "deletePages"
    options.textValues["pages"] = "2,3"
    options.textValues["outputPath"] = outputURL.path

    _ = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path, options: options)

    XCTAssertEqual(PDFDocument(url: outputURL)?.pageCount, 2)
  }

  func testPDFToolkitReordersPages() async throws {
    let pdfURL = try makeSizedPDF(named: "reorder-pages.pdf", pageSizes: [
      CGSize(width: 200, height: 120),
      CGSize(width: 220, height: 120),
      CGSize(width: 240, height: 120)
    ])
    let outputURL = tempURL(named: "reordered-pages.pdf")
    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "reorderPages"
    options.textValues["pages"] = "3,1"
    options.textValues["outputPath"] = outputURL.path

    _ = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path, options: options)

    let outputDocument = try XCTUnwrap(PDFDocument(url: outputURL))
    XCTAssertEqual(outputDocument.pageCount, 2)
    XCTAssertEqual(outputDocument.page(at: 0)?.bounds(for: .mediaBox).width, 240)
    XCTAssertEqual(outputDocument.page(at: 1)?.bounds(for: .mediaBox).width, 200)
  }

  func testPDFToolkitRotatesSelectedPages() async throws {
    let pdfURL = try makePDF(named: "rotate-pages.pdf", pageCount: 3)
    let outputURL = tempURL(named: "rotated-pages.pdf")
    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "rotatePages"
    options.textValues["pages"] = "1,3"
    options.textValues["rotation"] = "90"
    options.textValues["outputPath"] = outputURL.path

    _ = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path, options: options)

    let outputDocument = try XCTUnwrap(PDFDocument(url: outputURL))
    XCTAssertEqual(outputDocument.page(at: 0)?.rotation, 90)
    XCTAssertEqual(outputDocument.page(at: 1)?.rotation, 0)
    XCTAssertEqual(outputDocument.page(at: 2)?.rotation, 90)
  }

  func testPDFToolkitAppendsPagesFromAdditionalPDFs() async throws {
    let firstURL = try makePDF(named: "append-a.pdf", pageCount: 2)
    let secondURL = try makePDF(named: "append-b.pdf", pageCount: 3)
    let outputURL = tempURL(named: "appended-pages.pdf")
    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "appendPages"
    options.textValues["outputPath"] = outputURL.path

    _ = try await runner.run(toolID: .pdfToolkit, input: "\(firstURL.path)\n\(secondURL.path)", options: options)

    XCTAssertEqual(PDFDocument(url: outputURL)?.pageCount, 5)
  }

  func testNewDocumentAndMediaToolsHaveHelpfulEmptyInputOutput() async throws {
    for toolID in [ToolID.pdfToolkit, .imageConverter, .videoConverter] {
      let result = try await runner.run(toolID: toolID, input: "")
      XCTAssertFalse(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(toolID.rawValue) help output was empty")
    }
  }

  func testVideoConverterRegistryIncludesMP3Output() {
    let definition = ToolRegistry.definition(for: .videoConverter)
    let formatOption = definition.options.first { $0.key == "outputFormat" }

    XCTAssertTrue(formatOption?.choices.contains { $0.value == "mp3" } == true)
  }

  func testVideoConverterDefaultOutputUsesSourceFolder() async throws {
    guard let ffmpegURL = localExecutable(named: "ffmpeg") else {
      throw XCTSkip("ffmpeg is optional and is not installed on this runner.")
    }
    guard localExecutable(named: "ffprobe") != nil else {
      throw XCTSkip("ffprobe is optional and is not installed on this runner.")
    }
    let sourceURL = try makeTinyVideo(named: "source-video.mp4", ffmpegURL: ffmpegURL)
    var options = ToolRegistry.definition(for: .videoConverter).defaultOptions
    options.operation = "convert"
    options.textValues["outputFormat"] = "mp3"
    options.textValues["outputPath"] = "~/Desktop/workbench-labs-video.mp4"

    let result = try await runner.run(toolID: .videoConverter, input: sourceURL.path, options: options)

    let outputPath = result.output.split(separator: "\n").last.map(String.init) ?? ""
    XCTAssertTrue(outputPath.hasPrefix(sourceURL.deletingLastPathComponent().path), result.output)
    XCTAssertTrue(outputPath.hasSuffix(".mp3"), result.output)
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath), result.output)
    XCTAssertEqual(FileResultMetadata.generatedFileURLs(from: result.metadata).map(\.path), [outputPath])
    tempURLs.append(URL(fileURLWithPath: outputPath))
  }

  func testFileResultMetadataRoundTripsGeneratedFilePaths() {
    let urls = [
      URL(fileURLWithPath: "/tmp/Workbench Labs/output one.pdf"),
      URL(fileURLWithPath: "/tmp/Workbench Labs/output two.pdf")
    ]

    let metadata = FileResultMetadata.metadata(generatedFileURLs: urls)

    XCTAssertEqual(metadata[FileResultMetadata.generatedFileCountKey], "2")
    XCTAssertEqual(FileResultMetadata.generatedFileURLs(from: metadata), urls)
  }

  private func makePDF(named name: String, text: String = "Workbench Labs", pageCount: Int = 1) throws -> URL {
    try makePDF(named: name, text: text, pageSizes: Array(repeating: CGSize(width: 240, height: 120), count: pageCount))
  }

  private func makeSizedPDF(named name: String, pageSizes: [CGSize]) throws -> URL {
    let url = tempURL(named: name)
    let document = PDFDocument()
    for (index, size) in pageSizes.enumerated() {
      let image = NSImage(size: NSSize(width: size.width, height: size.height))
      image.lockFocus()
      NSColor(calibratedHue: CGFloat(index) / CGFloat(max(pageSizes.count, 1)), saturation: 0.7, brightness: 0.9, alpha: 1).setFill()
      NSRect(origin: .zero, size: image.size).fill()
      image.unlockFocus()
      guard let page = PDFPage(image: image) else {
        throw CocoaError(.fileWriteUnknown)
      }
      document.insert(page, at: document.pageCount)
    }
    guard document.write(to: url) else {
      throw CocoaError(.fileWriteUnknown)
    }
    tempURLs.append(url)
    return url
  }

  private func makePDF(named name: String, text: String = "Workbench Labs", pageSizes: [CGSize]) throws -> URL {
    let url = tempURL(named: name)
    let pdfData = NSMutableData()
    guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
      throw CocoaError(.fileWriteUnknown)
    }
    var mediaBox = CGRect(origin: .zero, size: pageSizes.first ?? CGSize(width: 240, height: 120))
    guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
      throw CocoaError(.fileWriteUnknown)
    }

    for (index, size) in pageSizes.enumerated() {
      mediaBox = CGRect(origin: .zero, size: size)
      context.beginPDFPage([
        kCGPDFContextMediaBox as String: mediaBox
      ] as CFDictionary)
      let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18),
        .foregroundColor: NSColor.black
      ]
      NSAttributedString(string: "\(text) \(index + 1)", attributes: attributes)
        .draw(in: CGRect(x: 20, y: 45, width: 200, height: 40))
      context.endPDFPage()
    }
    context.closePDF()

    try pdfData.write(to: url)
    tempURLs.append(url)
    return url
  }

  private func makePNG(named name: String) throws -> URL {
    let url = tempURL(named: name)
    let image = NSImage(size: NSSize(width: 8, height: 6))
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSRect(x: 0, y: 0, width: 8, height: 6).fill()
    image.unlockFocus()
    guard
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
    else {
      throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: url)
    tempURLs.append(url)
    return url
  }

  private func makeTinyVideo(named name: String, ffmpegURL: URL) throws -> URL {
    let url = tempURL(named: name)
    let process = Process()
    process.executableURL = ffmpegURL
    process.arguments = [
      "-hide_banner",
      "-loglevel", "error",
      "-f", "lavfi",
      "-i", "testsrc=size=32x32:rate=1",
      "-f", "lavfi",
      "-i", "sine=frequency=440:duration=1",
      "-t", "1",
      "-pix_fmt", "yuv420p",
      "-c:v", "libx264",
      "-c:a", "aac",
      url.path
    ]
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0)
    tempURLs.append(url)
    return url
  }

  private func localExecutable(named name: String) -> URL? {
    [
      "/opt/homebrew/bin/\(name)",
      "/usr/local/bin/\(name)",
      "/usr/bin/\(name)"
    ]
      .first { FileManager.default.isExecutableFile(atPath: $0) }
      .map(URL.init(fileURLWithPath:))
  }

  private func tempURL(named name: String) -> URL {
    FileManager.default.temporaryDirectory
      .appendingPathComponent("WorkbenchLabsTests-\(UUID().uuidString)-\(name)")
  }

  private func tempDirectory(named name: String) throws -> URL {
    let url = tempURL(named: name)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    tempURLs.append(url)
    return url
  }
}
