import XCTest
@testable import WorkbenchLabsCore

final class JSONFormatterOptionsTests: XCTestCase {
  private let runner = ToolRunner()

  func testAutoRepairQuotesKeysAndReplacesPythonConstants() async throws {
    var options = ToolRegistry.definition(for: .jsonFormatter).defaultOptions
    options.boolValues["autoRepair"] = true
    options.intValues["indent"] = 2

    let result = try await runner.run(toolID: .jsonFormatter, input: "{store: false, missing: None, active: True,}", options: options)

    XCTAssertTrue(result.output.contains(#""store": false"#))
    XCTAssertTrue(result.output.contains(#""missing": null"#))
    XCTAssertTrue(result.output.contains(#""active": true"#))
    XCTAssertEqual(result.metadata["repaired"], "true")
  }

  func testAllowTrailingCommasAndCommentsUsesJSON5Parsing() async throws {
    var options = ToolRegistry.definition(for: .jsonFormatter).defaultOptions
    options.boolValues["allowJSON5"] = true
    options.boolValues["autoRepair"] = false

    let result = try await runner.run(
      toolID: .jsonFormatter,
      input: """
      {
        // trailing comma is intentional
        "b": 2,
      }
      """,
      options: options
    )

    XCTAssertTrue(result.output.contains(#""b": 2"#))
    XCTAssertEqual(result.metadata["parser"], "json5")
  }

  func testSortKeysSortsNestedObjects() async throws {
    var options = ToolRegistry.definition(for: .jsonFormatter).defaultOptions
    options.boolValues["sortKeys"] = true

    let result = try await runner.run(toolID: .jsonFormatter, input: #"{"z":1,"a":{"d":4,"b":2}}"#, options: options)

    XCTAssertLessThan(result.output.range(of: #""a""#)!.lowerBound, result.output.range(of: #""z""#)!.lowerBound)
    XCTAssertLessThan(result.output.range(of: #""b""#)!.lowerBound, result.output.range(of: #""d""#)!.lowerBound)
  }

  func testPreserveEncodedStringsAndBigNumbersFormatsRawJSONTokens() async throws {
    var options = ToolRegistry.definition(for: .jsonFormatter).defaultOptions
    options.boolValues["autoRepair"] = false
    options.boolValues["sortKeys"] = false
    options.boolValues["preserveRaw"] = true
    options.intValues["indent"] = 2

    let result = try await runner.run(toolID: .jsonFormatter, input: #"{"text":"\u00e2","big":123456789012345678901234567890}"#, options: options)

    XCTAssertTrue(result.output.contains(#""text": "\u00e2""#))
    XCTAssertTrue(result.output.contains(#""big": 123456789012345678901234567890"#))
    XCTAssertEqual(result.metadata["preserved"], "true")
  }

  func testOneTabIndentUsesTabsForJSONOutput() async throws {
    var options = ToolRegistry.definition(for: .jsonFormatter).defaultOptions
    options.textValues["indentStyle"] = "tab"

    let result = try await runner.run(toolID: .jsonFormatter, input: #"{"a":{"b":1}}"#, options: options)

    XCTAssertTrue(result.output.contains("\n\t\"a\": {"))
    XCTAssertTrue(result.output.contains("\n\t\t\"b\": 1"))
  }

  func testMinifiedOutputRemovesWhitespace() async throws {
    var options = ToolRegistry.definition(for: .jsonFormatter).defaultOptions
    options.operation = "minify"

    let result = try await runner.run(toolID: .jsonFormatter, input: "{\n  \"a\": 1,\n  \"b\": true\n}", options: options)

    XCTAssertEqual(result.output, #"{"a":1,"b":true}"#)
  }
}
