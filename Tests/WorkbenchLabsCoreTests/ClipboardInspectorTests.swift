import XCTest
@testable import WorkbenchLabsCore

final class ClipboardInspectorTests: XCTestCase {
  func testDetectsJSON() {
    let suggestions = ClipboardInspector.suggestions(for: #"{"name":"WorkbenchLabs"}"#)
    XCTAssertEqual(suggestions.first?.toolID, .jsonFormatter)
  }

  func testDetectsJWT() {
    let suggestions = ClipboardInspector.suggestions(for: "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature")
    XCTAssertEqual(suggestions.first?.toolID, .jwtDebugger)
  }

  func testDetectsSecretLookingText() {
    let suggestions = ClipboardInspector.suggestions(for: "API_KEY=sk-live-abcdefghijklmnopqrstuvwxyz123456")
    XCTAssertEqual(suggestions.first?.toolID, .secretScanner)
  }

  func testDetectsUUID() {
    let suggestions = ClipboardInspector.suggestions(for: "550e8400-e29b-41d4-a716-446655440000")
    XCTAssertEqual(suggestions.first?.toolID, .uuidTool)
  }

  func testFallbacksToStringInspector() {
    let suggestions = ClipboardInspector.suggestions(for: "plain text")
    XCTAssertEqual(suggestions.first?.toolID, .stringInspector)
  }
}
