import Foundation
import WorkbenchLabsCore

struct ToolSessionState: Equatable {
  var input: String
  var options: ToolOptions
  var output: String
  var diagnostics: [ToolDiagnostic]
  var metadata: [String: String]
  var htmlPreview: String?
  var imagePNGBase64: String?
  var errorMessage: String?

  init(definition: ToolDefinition) {
    input = definition.sampleInput
    options = definition.defaultOptions
    output = ""
    diagnostics = []
    metadata = [:]
    htmlPreview = nil
    imagePNGBase64 = nil
    errorMessage = nil
  }
}
