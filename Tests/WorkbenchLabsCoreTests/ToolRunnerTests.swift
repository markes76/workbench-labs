import XCTest
@testable import WorkbenchLabsCore

final class ToolRunnerTests: XCTestCase {
  private let runner = ToolRunner()

  func testRegistryContainsDocumentedToolSet() {
    XCTAssertEqual(ToolRegistry.all.count, 37)
    XCTAssertEqual(Set(ToolRegistry.all.map(\.id)).count, 37)
    XCTAssertEqual(Set(ToolRegistry.all.map(\.id)), Set(ToolID.allCases))
    XCTAssertTrue(ToolRegistry.all.contains { $0.title == "JSON Schema Validator" })
    XCTAssertTrue(ToolRegistry.all.contains { $0.title == ".env Inspector & Comparator" })
    XCTAssertTrue(ToolRegistry.all.contains { $0.title == "Git Diff & Ignore Helper" })
  }

  func testRoadmapCategoriesExistInStableSidebarOrder() {
    XCTAssertEqual(ToolCategory.allCases, [
      .inspect,
      .security,
      .format,
      .encode,
      .apiNetwork,
      .generate,
      .developer,
      .document,
      .database,
      .media
    ])
  }

  func testGroupedRegistryCategorizesEveryToolExactlyOnce() {
    let groupedIDs = ToolRegistry.grouped().flatMap { $0.1.map(\.id) }
    let registeredIDs = ToolRegistry.all.map(\.id)

    XCTAssertEqual(groupedIDs.count, registeredIDs.count)
    XCTAssertEqual(Set(groupedIDs), Set(registeredIDs))
    XCTAssertEqual(Set(groupedIDs).count, groupedIDs.count)
  }

  func testHTMLPreviewPolicyBlocksExternalRequestsByDefault() {
    let html = "<html><head><title>x</title></head><body><img src=\"https://example.com/pixel.png\"></body></html>"
    let output = HTMLPreviewPolicy.injectContentSecurityPolicy(into: html, allowJavaScript: false)

    XCTAssertTrue(output.contains("Content-Security-Policy"))
    XCTAssertTrue(output.contains("default-src 'none'"))
    XCTAssertTrue(output.contains("connect-src 'none'"))
    XCTAssertTrue(output.contains("script-src 'none'"))
    XCTAssertTrue(output.contains("<head>\n<meta"))
  }

  func testURLCodecRoundTripsPercentEncoding() async throws {
    var options = ToolRegistry.definition(for: .urlCodec).defaultOptions
    options.operation = "encode"
    let encoded = try await runner.run(toolID: .urlCodec, input: "hello world?", options: options)
    XCTAssertEqual(encoded.output, "hello%20world%3F")

    options.operation = "decode"
    let decoded = try await runner.run(toolID: .urlCodec, input: encoded.output, options: options)
    XCTAssertEqual(decoded.output, "hello world?")
  }

  func testBase64CodecRoundTripsText() async throws {
    var options = ToolRegistry.definition(for: .base64Codec).defaultOptions
    options.operation = "encode"
    let encoded = try await runner.run(toolID: .base64Codec, input: "WorkbenchLabs", options: options)
    XCTAssertEqual(encoded.output, "V29ya2JlbmNoTGFicw==")

    options.operation = "decode"
    let decoded = try await runner.run(toolID: .base64Codec, input: encoded.output, options: options)
    XCTAssertEqual(decoded.output, "WorkbenchLabs")
  }

  func testBase64CodecEncodesURLSafeAlphabetWhenEnabled() async throws {
    var options = ToolRegistry.definition(for: .base64Codec).defaultOptions
    options.operation = "encode"
    options.boolValues["urlSafe"] = true

    let result = try await runner.run(toolID: .base64Codec, input: "\u{f8ff}", options: options)

    XCTAssertEqual(result.output, "76O_")
  }

  func testJSONFormatterUsesBundledRuntime() async throws {
    var options = ToolRegistry.definition(for: .jsonFormatter).defaultOptions
    options.operation = "format"
    let result = try await runner.run(toolID: .jsonFormatter, input: #"{"b":2,"a":1}"#, options: options)
    XCTAssertTrue(result.output.contains(#""a": 1"#))
    XCTAssertTrue(result.output.contains(#""b": 2"#))
  }

  func testJSONSchemaRuntimeReportsValidDocuments() throws {
    var options = ToolOptions()
    options.secondaryInput = #"{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}"#

    let result = try JavaScriptToolRunner().run(
      tool: "json-schema",
      input: #"{"name":"Workbench Labs"}"#,
      options: options
    )

    XCTAssertTrue(result.output.contains("Valid JSON"))
    XCTAssertEqual(result.metadata["valid"], "true")
    XCTAssertEqual(result.metadata["errorCount"], "0")
  }

  func testJSONSchemaRuntimeReportsValidationErrorsWithPaths() throws {
    var options = ToolOptions()
    options.secondaryInput = #"{"type":"object","required":["name"],"properties":{"name":{"type":"string"},"count":{"type":"integer","minimum":1}}}"#

    let result = try JavaScriptToolRunner().run(
      tool: "json-schema",
      input: #"{"count":0}"#,
      options: options
    )

    XCTAssertTrue(result.output.contains("Invalid JSON"))
    XCTAssertTrue(result.output.contains("/count"))
    XCTAssertTrue(result.output.contains("must be >= 1"))
    XCTAssertTrue(result.output.contains("must have required property 'name'"))
    XCTAssertEqual(result.metadata["valid"], "false")
    XCTAssertEqual(result.metadata["errorCount"], "2")
  }

  func testJSONSchemaValidatorRunsThroughToolRunner() async throws {
    var options = ToolRegistry.definition(for: .jsonSchemaValidator).defaultOptions
    options.secondaryInput = #"{"type":"object","required":["enabled"],"properties":{"enabled":{"type":"boolean"}}}"#

    let result = try await runner.run(toolID: .jsonSchemaValidator, input: #"{"enabled":true}"#, options: options)

    XCTAssertTrue(result.output.contains("Valid JSON"))
    XCTAssertEqual(result.metadata["valid"], "true")
  }

  func testEnvInspectorSummarizesWithoutLeakingValuesByDefault() async throws {
    var options = ToolRegistry.definition(for: .envInspector).defaultOptions
    options.operation = "inspect"

    let result = try await runner.run(
      toolID: .envInspector,
      input: "API_KEY=super-secret-token\nPUBLIC_URL=https://example.com\nEMPTY=\n",
      options: options
    )

    XCTAssertTrue(result.output.contains("3 keys"))
    XCTAssertTrue(result.output.contains("API_KEY"))
    XCTAssertTrue(result.output.contains("PUBLIC_URL"))
    XCTAssertFalse(result.output.contains("super-secret-token"))
    XCTAssertFalse(result.output.contains("https://example.com"))
    XCTAssertEqual(result.metadata["keyCount"], "3")
  }

  func testEnvInspectorCompareReportsAddedRemovedChangedAndMissingKeys() async throws {
    var options = ToolRegistry.definition(for: .envInspector).defaultOptions
    options.operation = "compare"
    options.secondaryInput = "API_KEY=changed\nDATABASE_URL=postgres://example\nNEW_FLAG=true\n"

    let result = try await runner.run(
      toolID: .envInspector,
      input: "API_KEY=old\nPUBLIC_URL=https://example.com\n",
      options: options
    )

    XCTAssertTrue(result.output.contains("Changed keys: API_KEY"))
    XCTAssertTrue(result.output.contains("Removed keys: PUBLIC_URL"))
    XCTAssertTrue(result.output.contains("Added keys: DATABASE_URL, NEW_FLAG"))
    XCTAssertTrue(result.output.contains("Missing in right: PUBLIC_URL"))
    XCTAssertTrue(result.output.contains("Missing in left: DATABASE_URL, NEW_FLAG"))
    XCTAssertFalse(result.output.contains("postgres://example"))
    XCTAssertFalse(result.output.contains("https://example.com"))
  }

  func testEnvInspectorRedactsValuesAndPreservesKeyNames() async throws {
    var options = ToolRegistry.definition(for: .envInspector).defaultOptions
    options.operation = "redact"

    let result = try await runner.run(
      toolID: .envInspector,
      input: "API_KEY=super-secret-token\nexport PUBLIC_URL=https://example.com\n# comment\n",
      options: options
    )

    XCTAssertTrue(result.output.contains("API_KEY=<redacted>"))
    XCTAssertTrue(result.output.contains("export PUBLIC_URL=<redacted>"))
    XCTAssertTrue(result.output.contains("# comment"))
    XCTAssertFalse(result.output.contains("super-secret-token"))
    XCTAssertFalse(result.output.contains("https://example.com"))
  }

  func testGitDiffIgnoreHelperSummarizesChangedFiles() async throws {
    let gitURL = try XCTUnwrap(localExecutable(named: "git"))
    let repoURL = try makeTemporaryGitRepository(gitURL: gitURL)
    defer { try? FileManager.default.removeItem(at: repoURL) }

    try "first\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
    try runGit(gitURL, ["add", "tracked.txt"], in: repoURL)
    try runGit(gitURL, ["-c", "user.name=Workbench Labs", "-c", "user.email=workbench@example.com", "commit", "-m", "initial"], in: repoURL)
    try "changed\n".write(to: repoURL.appendingPathComponent("tracked.txt"), atomically: true, encoding: .utf8)
    try "scratch\n".write(to: repoURL.appendingPathComponent("scratch.log"), atomically: true, encoding: .utf8)

    var options = ToolRegistry.definition(for: .gitDiffIgnoreHelper).defaultOptions
    options.operation = "inspect"
    let result = try await runner.run(toolID: .gitDiffIgnoreHelper, input: repoURL.path, options: options)

    XCTAssertTrue(result.output.contains("Git Repository Inspect"))
    XCTAssertTrue(result.output.contains("Modified: tracked.txt"), result.output)
    XCTAssertTrue(result.output.contains("Untracked: scratch.log"), result.output)
    XCTAssertTrue(result.output.contains("Read-only git commands"), result.output)
    XCTAssertEqual(result.metadata["changedFileCount"], "2")
  }

  func testGitDiffIgnoreHelperTestsIgnorePatternsAgainstPaths() async throws {
    var options = ToolRegistry.definition(for: .gitDiffIgnoreHelper).defaultOptions
    options.operation = "ignoreCheck"
    options.secondaryInput = "build/app.o\nnotes.txt\nerror.log\nimportant.log\n"

    let result = try await runner.run(
      toolID: .gitDiffIgnoreHelper,
      input: "build/\n*.log\n!important.log\n",
      options: options
    )

    XCTAssertTrue(result.output.contains("IGNORED  build/app.o"), result.output)
    XCTAssertTrue(result.output.contains("IGNORED  error.log"), result.output)
    XCTAssertTrue(result.output.contains("KEPT     notes.txt"), result.output)
    XCTAssertTrue(result.output.contains("KEPT     important.log"), result.output)
    XCTAssertEqual(result.metadata["ignoredCount"], "2")
    XCTAssertEqual(result.metadata["keptCount"], "2")
  }

  func testYAMLToJSONUsesBundledRuntime() async throws {
    let result = try await runner.run(toolID: .yamlToJson, input: "name: WorkbenchLabs\ncount: 27")
    XCTAssertTrue(result.output.contains(#""name": "WorkbenchLabs""#))
    XCTAssertTrue(result.output.contains(#""count": 27"#))
  }

  func testHTMLToJSXUsesLocalConverterWithoutTransitiveRuntimeDependency() async throws {
    var options = ToolRegistry.definition(for: .htmlToJSX).defaultOptions
    options.textValues["componentName"] = "Icon"
    let result = try await runner.run(toolID: .htmlToJSX, input: #"<svg viewBox="0 0 10 10" stroke-width="2" class="mark"></svg>"#, options: options)
    XCTAssertTrue(result.output.contains("function Icon"))
    XCTAssertTrue(result.output.contains("strokeWidth"))
    XCTAssertTrue(result.output.contains("className"))
  }

  func testHashGeneratorProducesKnownSHA256() async throws {
    var options = ToolRegistry.definition(for: .hashGenerator).defaultOptions
    options.textValues["algorithm"] = "sha256"
    let result = try await runner.run(toolID: .hashGenerator, input: "abc", options: options)
    XCTAssertTrue(result.output.contains("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))
  }

  func testBackslashCodecUnescapesUnicodeBraceSequences() async throws {
    var options = ToolRegistry.definition(for: .backslashCodec).defaultOptions
    options.operation = "escape"
    let escaped = try await runner.run(toolID: .backslashCodec, input: "A\u{001B}B", options: options)
    XCTAssertEqual(escaped.output, "A\\u{1B}B")

    options.operation = "unescape"
    let unescaped = try await runner.run(toolID: .backslashCodec, input: escaped.output, options: options)
    XCTAssertEqual(unescaped.output, "A\u{001B}B")
  }

  func testUUIDToolRejectsInvalidNonEmptyInput() async throws {
    do {
      _ = try await runner.run(toolID: .uuidTool, input: "not-a-uuid")
      XCTFail("Expected invalid UUID input to throw.")
    } catch let error as ToolEngineError {
      XCTAssertEqual(error, .invalidInput("Input is not a valid UUID."))
    }
  }

  func testUUIDToolGeneratesWhenInputIsEmpty() async throws {
    var options = ToolRegistry.definition(for: .uuidTool).defaultOptions
    options.intValues["count"] = 2

    let result = try await runner.run(toolID: .uuidTool, input: "", options: options)
    let uuids = result.output.split(separator: "\n")

    XCTAssertEqual(uuids.count, 2)
    XCTAssertTrue(uuids.allSatisfy { UUID(uuidString: String($0)) != nil })
  }

  func testJWTDebuggerDecodesHeaderAndPayload() async throws {
    let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjMifQ.jROrizwXV3Yj14Ofaz1zAq07YgNrxjQNyL-0slLq5Tw"
    var options = ToolRegistry.definition(for: .jwtDebugger).defaultOptions
    options.textValues["secret"] = "secret"
    let result = try await runner.run(toolID: .jwtDebugger, input: token, options: options)
    XCTAssertTrue(result.output.contains("HS256"))
    XCTAssertTrue(result.output.contains("123"))
    XCTAssertEqual(result.diagnostics.first?.severity, .info)
  }

  func testQRCodeGeneratorProducesPNGData() async throws {
    var options = ToolRegistry.definition(for: .qrCode).defaultOptions
    options.operation = "generate"
    let result = try await runner.run(toolID: .qrCode, input: "https://example.com", options: options)
    XCTAssertEqual(result.output, "QR code generated.")
    XCTAssertNotNil(result.imagePNGBase64)
    XCTAssertGreaterThan(Data(base64Encoded: result.imagePNGBase64 ?? "")?.count ?? 0, 100)
  }

  private func makeTemporaryGitRepository(gitURL: URL) throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("WorkbenchLabsGitTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    try runGit(gitURL, ["init"], in: url)
    return url
  }

  private func runGit(_ gitURL: URL, _ arguments: [String], in directoryURL: URL) throws {
    let process = Process()
    process.executableURL = gitURL
    process.arguments = arguments
    process.currentDirectoryURL = directoryURL
    process.standardOutput = Pipe()
    process.standardError = Pipe()
    try process.run()
    process.waitUntilExit()
    XCTAssertEqual(process.terminationStatus, 0, "git \(arguments.joined(separator: " ")) failed")
  }

  private func localExecutable(named name: String) -> URL? {
    [
      "/opt/homebrew/bin/\(name)",
      "/usr/local/bin/\(name)",
      "/usr/bin/\(name)",
      "/bin/\(name)"
    ]
      .first { FileManager.default.isExecutableFile(atPath: $0) }
      .map(URL.init(fileURLWithPath:))
  }
}
