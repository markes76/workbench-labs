import XCTest
@testable import WorkbenchLabsCore

final class AllToolsSmokeTests: XCTestCase {
  private let runner = ToolRunner()

  func testEveryDocumentedToolProducesAResultFromItsDefaultSample() async throws {
    for definition in ToolRegistry.all {
      var options = definition.defaultOptions
      if definition.id == .loremIpsum {
        options.operation = "words"
        options.intValues["count"] = 8
      }
      let result = try await runner.run(toolID: definition.id, input: definition.sampleInput, options: options)
      XCTAssertFalse(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(definition.title) produced empty output")
    }
  }
}
