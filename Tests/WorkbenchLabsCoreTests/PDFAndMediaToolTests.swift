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
    tempURLs.append(URL(fileURLWithPath: outputPath))
  }

  private func makePDF(named name: String, text: String = "Workbench Labs", pageCount: Int = 1) throws -> URL {
    let url = tempURL(named: name)
    let pdfData = NSMutableData()
    guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
      throw CocoaError(.fileWriteUnknown)
    }
    var mediaBox = CGRect(x: 0, y: 0, width: 240, height: 120)
    guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
      throw CocoaError(.fileWriteUnknown)
    }

    for page in 1...pageCount {
      context.beginPDFPage(nil)
      let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 18),
        .foregroundColor: NSColor.black
      ]
      NSAttributedString(string: "\(text) \(page)", attributes: attributes)
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
