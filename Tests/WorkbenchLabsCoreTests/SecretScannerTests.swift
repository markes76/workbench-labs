import XCTest
@testable import WorkbenchLabsCore

final class SecretScannerTests: XCTestCase {
  private let runner = ToolRunner()

  func testScannerReportsFindingsWithoutEchoingFullSecret() async throws {
    var options = ToolRegistry.definition(for: .secretScanner).defaultOptions
    options.operation = "scan"
    let secret = "sk-live-abcdefghijklmnopqrstuvwxyz123456"
    let input = "API_KEY=\(secret)\nmode=development"

    let result = try await runner.run(toolID: .secretScanner, input: input, options: options)

    XCTAssertTrue(result.output.contains("Findings: 1"))
    XCTAssertTrue(result.output.contains("Secret-looking assignment"))
    XCTAssertFalse(result.output.contains(secret))
    XCTAssertEqual(result.metadata["findings"], "1")
  }

  func testRedactOperationReturnsRedactedText() async throws {
    var options = ToolRegistry.definition(for: .secretScanner).defaultOptions
    options.operation = "redact"

    let result = try await runner.run(
      toolID: .secretScanner,
      input: "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature",
      options: options
    )

    XCTAssertTrue(result.output.contains("<redacted authorization bearer token>"))
    XCTAssertFalse(result.output.contains("eyJhbGciOiJIUzI1NiJ9"))
  }

  func testScannerReportsNoFindingsForPlainText() async throws {
    let result = try await runner.run(toolID: .secretScanner, input: "ordinary log line")

    XCTAssertEqual(result.output, "No secret-looking values found.")
    XCTAssertEqual(result.metadata["findings"], "0")
  }
}
