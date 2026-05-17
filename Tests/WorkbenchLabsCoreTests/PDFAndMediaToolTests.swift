import AppKit
import ImageIO
import PDFKit
import UniformTypeIdentifiers
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

  func testPDFToolkitInspectShowsMetadataFields() async throws {
    let pdfURL = try makeMetadataPDF(named: "metadata.pdf", pageCount: 2)

    let result = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path)

    XCTAssertTrue(result.output.contains("Title: Internal Roadmap"), result.output)
    XCTAssertTrue(result.output.contains("Author: Workbench Labs"), result.output)
    XCTAssertTrue(result.output.contains("Subject: Metadata Scrubber Test"), result.output)
    XCTAssertTrue(result.output.contains("Creator: Workbench Test Suite"), result.output)
    XCTAssertTrue(result.output.contains("Producer: "), result.output)
    XCTAssertFalse(result.output.contains("Producer: -"), result.output)
    XCTAssertTrue(result.output.contains("Keywords: private, draft"), result.output)
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

  func testBatchImageResizerProcessesMultipleImagesBesideSource() async throws {
    let firstURL = try makePNG(named: "batch-a.png", size: CGSize(width: 12, height: 8))
    let secondURL = try makePNG(named: "batch-b.png", size: CGSize(width: 20, height: 10))
    var options = ToolRegistry.definition(for: .batchImageResizer).defaultOptions
    options.textValues["resizeMode"] = "max"
    options.intValues["maxDimension"] = 6
    options.textValues["outputFormat"] = "png"

    let result = try await runner.run(toolID: .batchImageResizer, input: "\(firstURL.path)\n\(secondURL.path)", options: options)

    let outputURLs = FileResultMetadata.generatedFileURLs(from: result.metadata)
    XCTAssertEqual(outputURLs.count, 2, result.output)
    XCTAssertEqual(outputURLs[0].deletingLastPathComponent(), firstURL.deletingLastPathComponent())
    XCTAssertEqual(imagePixelSize(outputURLs[0]), CGSize(width: 6, height: 4))
    XCTAssertEqual(imagePixelSize(outputURLs[1]), CGSize(width: 6, height: 3))
  }

  func testBatchImageResizerScaleModeUsesOutputFolderAndAvoidsOverwrites() async throws {
    let inputURL = try makePNG(named: "batch-overwrite.png", size: CGSize(width: 10, height: 6))
    let outputDirectoryURL = try tempDirectory(named: "batch-output")
    let existingURL = outputDirectoryURL.appendingPathComponent("batch-overwrite-resized.jpg")
    try Data("existing".utf8).write(to: existingURL)

    var options = ToolRegistry.definition(for: .batchImageResizer).defaultOptions
    options.textValues["resizeMode"] = "scale"
    options.intValues["scalePercent"] = 50
    options.textValues["outputFormat"] = "jpeg"
    options.textValues["outputDirectory"] = outputDirectoryURL.path
    options.boolValues["stripMetadata"] = true

    let result = try await runner.run(toolID: .batchImageResizer, input: inputURL.path, options: options)

    XCTAssertEqual(try Data(contentsOf: existingURL), Data("existing".utf8))
    let outputURLs = FileResultMetadata.generatedFileURLs(from: result.metadata)
    XCTAssertEqual(outputURLs.count, 1, result.output)
    XCTAssertNotEqual(outputURLs[0], existingURL)
    XCTAssertTrue(outputURLs[0].path.hasPrefix(outputDirectoryURL.path), result.output)
    XCTAssertEqual(imagePixelSize(outputURLs[0]), CGSize(width: 5, height: 3))
  }

  func testImageMetadataInspectorReportsGPSCoordinatesAndPrivacyRisk() async throws {
    let inputURL = try makeJPEGWithGPS(named: "gps-source.jpg")

    let result = try await runner.run(toolID: .imageMetadataInspector, input: inputURL.path)

    XCTAssertTrue(result.output.contains("GPS: present"), result.output)
    XCTAssertTrue(result.output.contains("Latitude: 32.0853"), result.output)
    XCTAssertTrue(result.output.contains("Longitude: 34.7818"), result.output)
    XCTAssertTrue(result.output.contains("Privacy: geolocation metadata found"), result.output)
    XCTAssertEqual(result.metadata["gps"], "present")
  }

  func testImageMetadataInspectorScrubsGeolocationBesideSourceWithoutChangingOriginal() async throws {
    let inputURL = try makeJPEGWithGPS(named: "gps-private.jpg")
    XCTAssertNotNil(imageMetadataDictionary(inputURL, key: kCGImagePropertyGPSDictionary))

    var options = ToolRegistry.definition(for: .imageMetadataInspector).defaultOptions
    options.operation = "scrub"
    options.boolValues["removeGPS"] = true
    options.boolValues["removeCameraMetadata"] = false
    options.boolValues["removeDescriptiveMetadata"] = false

    let result = try await runner.run(toolID: .imageMetadataInspector, input: inputURL.path, options: options)

    let outputURLs = FileResultMetadata.generatedFileURLs(from: result.metadata)
    XCTAssertEqual(outputURLs.count, 1, result.output)
    XCTAssertEqual(outputURLs[0].deletingLastPathComponent(), inputURL.deletingLastPathComponent())
    XCTAssertNotEqual(outputURLs[0], inputURL)
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURLs[0].path))
    XCTAssertNotNil(imageMetadataDictionary(inputURL, key: kCGImagePropertyGPSDictionary), "Original image should be untouched.")
    XCTAssertNil(imageMetadataDictionary(outputURLs[0], key: kCGImagePropertyGPSDictionary), result.output)
    XCTAssertTrue(result.output.contains("Removed: GPS location"), result.output)
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

  func testPDFToolkitScrubsMetadataAndPreservesPages() async throws {
    let pdfURL = try makeMetadataPDF(named: "metadata-source.pdf", pageCount: 3)
    let outputURL = tempURL(named: "metadata-scrubbed.pdf")
    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "scrubMetadata"
    options.textValues["outputPath"] = outputURL.path

    let result = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path, options: options)

    let outputDocument = try XCTUnwrap(PDFDocument(url: outputURL))
    XCTAssertEqual(outputDocument.pageCount, 3)
    XCTAssertMetadataScrubbed(outputDocument)
    XCTAssertTrue(result.output.contains(outputURL.path), result.output)
    XCTAssertEqual(FileResultMetadata.generatedFileURLs(from: result.metadata), [outputURL])

    let sourceDocument = try XCTUnwrap(PDFDocument(url: pdfURL))
    XCTAssertEqual(metadataString(sourceDocument, .titleAttribute), "Internal Roadmap")
  }

  func testPDFToolkitScrubsOnlySelectedMetadataFields() async throws {
    let pdfURL = try makeMetadataPDF(named: "metadata-selective.pdf", pageCount: 1)
    let outputURL = tempURL(named: "metadata-selective-scrubbed.pdf")
    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = "scrubMetadata"
    options.textValues["outputPath"] = outputURL.path
    options.boolValues["scrubAuthor"] = false
    options.boolValues["scrubSubject"] = false

    _ = try await runner.run(toolID: .pdfToolkit, input: pdfURL.path, options: options)

    let outputDocument = try XCTUnwrap(PDFDocument(url: outputURL))
    XCTAssertTrue(metadataString(outputDocument, .titleAttribute).isEmpty)
    XCTAssertEqual(metadataString(outputDocument, .authorAttribute), "Workbench Labs")
    XCTAssertEqual(metadataString(outputDocument, .subjectAttribute), "Metadata Scrubber Test")
  }

  func testPDFOCRExtractsTextFromImageBasedPDF() async throws {
    let pdfURL = try makeImageTextPDF(named: "ocr-image.pdf", text: "WORKBENCH OCR")
    var options = ToolRegistry.definition(for: .pdfOCR).defaultOptions
    options.textValues["pages"] = "1"

    let result = try await runner.run(toolID: .pdfOCR, input: pdfURL.path, options: options)

    XCTAssertTrue(result.output.localizedCaseInsensitiveContains("WORKBENCH"), result.output)
    XCTAssertTrue(result.output.localizedCaseInsensitiveContains("OCR"), result.output)
    XCTAssertEqual(result.metadata["pages"], "1")
    XCTAssertNotNil(result.metadata["recognizedTextLines"])
  }

  func testPDFOCROffersEnglishAndHebrewRecognition() {
    let definition = ToolRegistry.definition(for: .pdfOCR)
    let languageOption = definition.options.first { $0.key == "languages" }

    XCTAssertEqual(languageOption?.defaultValue, "en")
    XCTAssertTrue(languageOption?.choices.contains { $0.value == "en" } == true)
    XCTAssertTrue(languageOption?.choices.contains { $0.value == "he" } == true)
    XCTAssertTrue(languageOption?.choices.contains { $0.value == "en-he" } == true)
    XCTAssertEqual(definition.defaultOptions.textValues["languages"], "en")
  }

  func testPDFOCRUsesSelectedEnglishVisionLanguage() async throws {
    let pdfURL = try makeImageTextPDF(named: "ocr-language.pdf", text: "WORKBENCH OCR")
    var options = ToolRegistry.definition(for: .pdfOCR).defaultOptions
    options.textValues["pages"] = "1"
    options.textValues["languages"] = "en"

    let result = try await runner.run(toolID: .pdfOCR, input: pdfURL.path, options: options)

    XCTAssertEqual(result.metadata["recognitionEngine"], "vision")
    XCTAssertEqual(result.metadata["recognitionLanguages"], "en-US")
  }

  func testPDFOCRExtractsHebrewWithTesseractWhenAvailable() async throws {
    guard PDFOCRExtractor.hasTesseractLanguages(["heb"]) else {
      throw XCTSkip("Hebrew OCR requires local Tesseract with heb.traineddata.")
    }

    let pdfURL = try makeImageTextPDF(named: "ocr-hebrew.pdf", text: "שלום עולם", fontSize: 84)
    var options = ToolRegistry.definition(for: .pdfOCR).defaultOptions
    options.textValues["pages"] = "1"
    options.textValues["languages"] = "he"

    let result = try await runner.run(toolID: .pdfOCR, input: pdfURL.path, options: options)

    XCTAssertEqual(result.metadata["recognitionEngine"], "tesseract")
    XCTAssertEqual(result.metadata["recognitionLanguages"], "heb")
    XCTAssertTrue(result.output.contains("שלום") || result.output.contains("עולם"), result.output)
  }

  func testPDFOCRReportsMissingHebrewRuntimeWhenTesseractIsUnavailable() async throws {
    guard !PDFOCRExtractor.hasTesseractLanguages(["heb"]) else {
      throw XCTSkip("Hebrew OCR runtime is installed on this runner.")
    }

    let pdfURL = try makeImageTextPDF(named: "ocr-missing-hebrew-runtime.pdf", text: "שלום עולם", fontSize: 84)
    var options = ToolRegistry.definition(for: .pdfOCR).defaultOptions
    options.textValues["pages"] = "1"
    options.textValues["languages"] = "he"

    do {
      _ = try await runner.run(toolID: .pdfOCR, input: pdfURL.path, options: options)
      XCTFail("Expected Hebrew OCR to report a missing local runtime.")
    } catch let error as ToolEngineError {
      guard case .runtimeUnavailable(let message) = error else {
        return XCTFail("Expected runtimeUnavailable, got \(error).")
      }
      XCTAssertTrue(message.contains("Tesseract"), message)
      XCTAssertTrue(message.contains("tesseract-lang") || message.contains("heb"), message)
    }
  }

  func testPDFOCRValidatesPageRanges() async throws {
    let pdfURL = try makePDF(named: "ocr-range.pdf", pageCount: 1)
    var options = ToolRegistry.definition(for: .pdfOCR).defaultOptions
    options.textValues["pages"] = "2"

    do {
      _ = try await runner.run(toolID: .pdfOCR, input: pdfURL.path, options: options)
      XCTFail("Expected invalid OCR page range to throw.")
    } catch let error as ToolEngineError {
      XCTAssertEqual(error, .invalidInput("Page 2 is outside the valid range 1-1."))
    }
  }

  func testNewDocumentAndMediaToolsHaveHelpfulEmptyInputOutput() async throws {
    for toolID in [ToolID.pdfToolkit, .imageConverter, .batchImageResizer, .videoConverter] {
      let result = try await runner.run(toolID: toolID, input: "")
      XCTAssertFalse(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(toolID.rawValue) help output was empty")
    }
  }

  func testVideoConverterRegistryIncludesMP3Output() {
    let definition = ToolRegistry.definition(for: .videoConverter)
    let formatOption = definition.options.first { $0.key == "outputFormat" }

    XCTAssertTrue(formatOption?.choices.contains { $0.value == "mp3" } == true)
  }

  func testVideoConverterRegistryIncludesClipAudioAndThumbnailControls() {
    let definition = ToolRegistry.definition(for: .videoConverter)
    let operationOption = definition.options.first { $0.kind == .operation }
    let formatOption = definition.options.first { $0.key == "outputFormat" }

    XCTAssertTrue(operationOption?.choices.contains { $0.value == "extractAudio" } == true)
    XCTAssertTrue(operationOption?.choices.contains { $0.value == "thumbnail" } == true)
    XCTAssertTrue(formatOption?.choices.contains { $0.value == "wav" } == true)
    XCTAssertTrue(formatOption?.choices.contains { $0.value == "aac" } == true)
    XCTAssertTrue(formatOption?.choices.contains { $0.value == "jpg" } == true)
    XCTAssertTrue(definition.options.contains { $0.key == "startTime" })
    XCTAssertTrue(definition.options.contains { $0.key == "endTime" })
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

  func testVideoConverterTrimsClipBesideSource() async throws {
    guard let ffmpegURL = localExecutable(named: "ffmpeg") else {
      throw XCTSkip("ffmpeg is optional and is not installed on this runner.")
    }
    guard let ffprobeURL = localExecutable(named: "ffprobe") else {
      throw XCTSkip("ffprobe is optional and is not installed on this runner.")
    }
    let sourceURL = try makeTinyVideo(named: "trim-source.mp4", ffmpegURL: ffmpegURL, duration: 2)
    var options = ToolRegistry.definition(for: .videoConverter).defaultOptions
    options.operation = "convert"
    options.textValues["outputFormat"] = "mp4"
    options.textValues["startTime"] = "0.25"
    options.textValues["endTime"] = "1.00"

    let result = try await runner.run(toolID: .videoConverter, input: sourceURL.path, options: options)

    let outputURL = try XCTUnwrap(FileResultMetadata.generatedFileURLs(from: result.metadata).first)
    tempURLs.append(outputURL)
    XCTAssertEqual(outputURL.deletingLastPathComponent(), sourceURL.deletingLastPathComponent())
    XCTAssertTrue(outputURL.lastPathComponent.contains("-clip"), outputURL.path)
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), result.output)
    let sourceDuration = try mediaDuration(sourceURL, ffprobeURL: ffprobeURL)
    let clipDuration = try mediaDuration(outputURL, ffprobeURL: ffprobeURL)
    XCTAssertLessThan(clipDuration, sourceDuration)
    XCTAssertLessThan(clipDuration, 1.5)
  }

  func testVideoConverterExtractsWAVAudioBesideSource() async throws {
    guard let ffmpegURL = localExecutable(named: "ffmpeg") else {
      throw XCTSkip("ffmpeg is optional and is not installed on this runner.")
    }
    let sourceURL = try makeTinyVideo(named: "audio-source.mp4", ffmpegURL: ffmpegURL)
    var options = ToolRegistry.definition(for: .videoConverter).defaultOptions
    options.operation = "extractAudio"
    options.textValues["outputFormat"] = "wav"

    let result = try await runner.run(toolID: .videoConverter, input: sourceURL.path, options: options)

    let outputURL = try XCTUnwrap(FileResultMetadata.generatedFileURLs(from: result.metadata).first)
    tempURLs.append(outputURL)
    XCTAssertEqual(outputURL.deletingLastPathComponent(), sourceURL.deletingLastPathComponent())
    XCTAssertTrue(outputURL.lastPathComponent.hasSuffix("-audio.wav"), outputURL.path)
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), result.output)
  }

  func testVideoConverterGeneratesThumbnailBesideSource() async throws {
    guard let ffmpegURL = localExecutable(named: "ffmpeg") else {
      throw XCTSkip("ffmpeg is optional and is not installed on this runner.")
    }
    let sourceURL = try makeTinyVideo(named: "thumbnail-source.mp4", ffmpegURL: ffmpegURL)
    var options = ToolRegistry.definition(for: .videoConverter).defaultOptions
    options.operation = "thumbnail"
    options.textValues["outputFormat"] = "jpg"
    options.textValues["startTime"] = "0"

    let result = try await runner.run(toolID: .videoConverter, input: sourceURL.path, options: options)

    let outputURL = try XCTUnwrap(FileResultMetadata.generatedFileURLs(from: result.metadata).first)
    tempURLs.append(outputURL)
    XCTAssertEqual(outputURL.deletingLastPathComponent(), sourceURL.deletingLastPathComponent())
    XCTAssertTrue(outputURL.lastPathComponent.hasSuffix("-thumbnail.jpg"), outputURL.path)
    XCTAssertEqual(imagePixelSize(outputURL), CGSize(width: 32, height: 32))
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

  private func makeMetadataPDF(named name: String, pageCount: Int) throws -> URL {
    let url = try makePDF(named: name, pageCount: pageCount)
    guard let document = PDFDocument(url: url) else {
      throw CocoaError(.fileReadUnknown)
    }
    document.documentAttributes = [
      PDFDocumentAttribute.titleAttribute: "Internal Roadmap",
      PDFDocumentAttribute.authorAttribute: "Workbench Labs",
      PDFDocumentAttribute.subjectAttribute: "Metadata Scrubber Test",
      PDFDocumentAttribute.creatorAttribute: "Workbench Test Suite",
      PDFDocumentAttribute.producerAttribute: "Workbench PDF Fixture",
      PDFDocumentAttribute.keywordsAttribute: "private, draft"
    ]
    guard document.write(to: url) else {
      throw CocoaError(.fileWriteUnknown)
    }
    return url
  }

  private func XCTAssertMetadataScrubbed(_ document: PDFDocument, file: StaticString = #filePath, line: UInt = #line) {
    let scrubbedAttributes: [PDFDocumentAttribute] = [
      .titleAttribute,
      .authorAttribute,
      .subjectAttribute,
      .creatorAttribute,
      .producerAttribute,
      .keywordsAttribute
    ]
    for attribute in scrubbedAttributes {
      XCTAssertTrue(metadataString(document, attribute).isEmpty, "Expected \(attribute) to be scrubbed.", file: file, line: line)
    }
  }

  private func metadataString(_ document: PDFDocument, _ attribute: PDFDocumentAttribute) -> String {
    guard let value = document.documentAttributes?[attribute] else { return "" }
    if let string = value as? String {
      return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let strings = value as? [String] {
      return strings.joined(separator: ", ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private func makePNG(named name: String, size: CGSize = CGSize(width: 8, height: 6)) throws -> URL {
    let url = tempURL(named: name)
    let image = NSImage(size: NSSize(width: size.width, height: size.height))
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSRect(x: 0, y: 0, width: size.width, height: size.height).fill()
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

  private func makeJPEGWithGPS(named name: String) throws -> URL {
    let url = tempURL(named: name)
    let image = NSImage(size: NSSize(width: 12, height: 8))
    image.lockFocus()
    NSColor.systemGreen.setFill()
    NSRect(x: 0, y: 0, width: 12, height: 8).fill()
    image.unlockFocus()
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
    else {
      throw CocoaError(.fileWriteUnknown)
    }

    let metadata: [CFString: Any] = [
      kCGImagePropertyGPSDictionary: [
        kCGImagePropertyGPSLatitude: 32.0853,
        kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 34.7818,
        kCGImagePropertyGPSLongitudeRef: "E",
        kCGImagePropertyGPSDateStamp: "2026:05:17"
      ],
      kCGImagePropertyExifDictionary: [
        kCGImagePropertyExifLensModel: "Private Lens"
      ],
      kCGImagePropertyTIFFDictionary: [
        kCGImagePropertyTIFFMake: "Workbench Camera"
      ]
    ]
    CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
    guard CGImageDestinationFinalize(destination) else {
      throw CocoaError(.fileWriteUnknown)
    }
    tempURLs.append(url)
    return url
  }

  private func imageMetadataDictionary(_ url: URL, key: CFString) -> [CFString: Any]? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    else {
      return nil
    }
    return properties[key] as? [CFString: Any]
  }

  private func imagePixelSize(_ url: URL) -> CGSize? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
          let height = properties[kCGImagePropertyPixelHeight] as? CGFloat
    else {
      return nil
    }
    return CGSize(width: width, height: height)
  }

  private func makeImageTextPDF(named name: String, text: String, fontSize: CGFloat = 72) throws -> URL {
    let url = tempURL(named: name)
    let image = NSImage(size: NSSize(width: 900, height: 300))
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: 900, height: 300).fill()
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.boldSystemFont(ofSize: fontSize),
      .foregroundColor: NSColor.black
    ]
    NSAttributedString(string: text, attributes: attributes)
      .draw(in: NSRect(x: 60, y: 105, width: 780, height: 110))
    image.unlockFocus()

    let document = PDFDocument()
    guard let page = PDFPage(image: image) else {
      throw CocoaError(.fileWriteUnknown)
    }
    document.insert(page, at: 0)
    guard document.write(to: url) else {
      throw CocoaError(.fileWriteUnknown)
    }
    tempURLs.append(url)
    return url
  }

  private func makeTinyVideo(named name: String, ffmpegURL: URL, duration: Double = 1) throws -> URL {
    let url = tempURL(named: name)
    let process = Process()
    process.executableURL = ffmpegURL
    process.arguments = [
      "-hide_banner",
      "-loglevel", "error",
      "-f", "lavfi",
      "-i", "testsrc=size=32x32:rate=1",
      "-f", "lavfi",
      "-i", "sine=frequency=440:duration=\(duration)",
      "-t", "\(duration)",
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

  private func mediaDuration(_ url: URL, ffprobeURL: URL) throws -> Double {
    let process = Process()
    process.executableURL = ffprobeURL
    process.arguments = [
      "-v", "error",
      "-show_entries", "format=duration",
      "-of", "default=noprint_wrappers=1:nokey=1",
      url.path
    ]
    let pipe = Pipe()
    process.standardOutput = pipe
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0)
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    return Double(output) ?? 0
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
