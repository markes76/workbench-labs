import XCTest
@testable import WorkbenchLabsCore

final class Base64OptionsTests: XCTestCase {
  private let runner = ToolRunner()

  func testDecodeRemovesDataURLPrefixWhenEnabled() async throws {
    var options = ToolRegistry.definition(for: .base64Codec).defaultOptions
    options.operation = "decode"
    options.boolValues["stripDataURLPrefix"] = true

    let result = try await runner.run(
      toolID: .base64Codec,
      input: "data:text/plain;base64,V29ya2JlbmNoTGFicw==",
      options: options
    )

    XCTAssertEqual(result.output, "WorkbenchLabs")
    XCTAssertEqual(result.metadata["strippedDataURLPrefix"], "true")
  }

  func testDecodeRemovesTrailingNullByteWhenEnabled() async throws {
    var options = ToolRegistry.definition(for: .base64Codec).defaultOptions
    options.operation = "decode"
    options.boolValues["removeTrailingNullByte"] = true

    let result = try await runner.run(toolID: .base64Codec, input: "SGVsbG8A", options: options)

    XCTAssertEqual(result.output, "Hello")
    XCTAssertEqual(result.metadata["removedTrailingNullByte"], "true")
  }

  func testExplicitDecodeBase64DecodableUTF8() async throws {
    var options = ToolRegistry.definition(for: .base64Codec).defaultOptions
    options.operation = "decode"
    options.boolValues["autoDetectUTF8"] = true

    let result = try await runner.run(toolID: .base64Codec, input: "V29ya2JlbmNoTGFicw==", options: options)

    XCTAssertEqual(result.output, "WorkbenchLabs")
    XCTAssertEqual(result.metadata["operation"], "decode")
  }

  func testEncodePreservesTrailingWhitespaceExactly() async throws {
    var options = ToolRegistry.definition(for: .base64Codec).defaultOptions
    options.operation = "encode"
    options.boolValues["autoDetectUTF8"] = false

    let result = try await runner.run(
      toolID: .base64Codec,
      input: "this is one that has been approved to ",
      options: options
    )

    XCTAssertEqual(result.output, "dGhpcyBpcyBvbmUgdGhhdCBoYXMgYmVlbiBhcHByb3ZlZCB0byA=")
  }

  func testExplicitEncodeDoesNotAutoDecodeBase64LookingInput() async throws {
    var options = ToolRegistry.definition(for: .base64Codec).defaultOptions
    options.operation = "encode"
    options.boolValues["autoDetectUTF8"] = true

    let result = try await runner.run(
      toolID: .base64Codec,
      input: "RXQgcXVpYSBpcHN1bSByZWN1c2FuZGFlIHZlcml0YXRpcyBudWxsYSBldCBxdW8gaXBzdW0u",
      options: options
    )

    XCTAssertEqual(
      result.output,
      "UlhRZ2NYVnBZU0JwY0hOMWJTQnlaV04xYzJGdVpHRmxJSFpsY21sMFlYUnBjeUJ1ZFd4c1lTQmxkQ0J4ZFc4Z2FYQnpkVzB1"
    )
    XCTAssertEqual(result.metadata["operation"], "encode")
  }

  func testDetectsBase64UTF8InputForClipboardRouting() {
    XCTAssertTrue(Base64InputDetector.isDecodableUTF8("RXQgcXVpYSBpcHN1bSByZWN1c2FuZGFlIHZlcml0YXRpcyBudWxsYSBldCBxdW8gaXBzdW0u"))
    XCTAssertFalse(Base64InputDetector.isDecodableUTF8("Et quia ipsum recusandae veritatis nulla et quo ipsum."))
  }

  func testDecodePreservesTrailingWhitespaceExactly() async throws {
    var options = ToolRegistry.definition(for: .base64Codec).defaultOptions
    options.operation = "decode"

    let result = try await runner.run(
      toolID: .base64Codec,
      input: "dGhpcyBpcyBvbmUgdGhhdCBoYXMgYmVlbiBhcHByb3ZlZCB0byA=",
      options: options
    )

    XCTAssertEqual(result.output, "this is one that has been approved to ")
  }

  func testUseOutputAsInputSwitchesEncodeToDecode() {
    XCTAssertEqual(
      ToolOperationBehavior.inverseOperation(for: .base64Codec, currentOperation: "encode"),
      "decode"
    )
  }
}
