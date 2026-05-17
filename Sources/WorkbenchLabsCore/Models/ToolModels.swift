import Foundation

public enum ToolCategory: String, CaseIterable, Codable, Identifiable, Sendable {
  case inspect = "Inspect & Test"
  case security = "Security"
  case format = "Format & Convert"
  case encode = "Encode & Decode"
  case apiNetwork = "API & Network"
  case generate = "Generate & Crypto"
  case developer = "Developer"
  case document = "PDF & Documents"
  case database = "Databases"
  case media = "Image & Video"

  public var id: String { rawValue }

  public var systemImage: String {
    switch self {
    case .inspect: "scope"
    case .security: "lock.shield"
    case .format: "curlybraces"
    case .encode: "lock.open"
    case .apiNetwork: "network"
    case .generate: "sparkles"
    case .developer: "hammer"
    case .document: "doc.richtext"
    case .database: "cylinder"
    case .media: "photo.on.rectangle.angled"
    }
  }
}

public enum ToolID: String, CaseIterable, Codable, Identifiable, Sendable {
  case unixTimestamp
  case regexTester
  case jwtDebugger
  case htmlPreview
  case textDiff
  case markdownPreview
  case stringInspector
  case secretScanner
  case jsonSchemaValidator
  case envInspector
  case jsonFormatter
  case htmlFormatter
  case cssFormatter
  case javascriptFormatter
  case xmlFormatter
  case yamlToJson
  case jsonToYaml
  case htmlToJSX
  case sqlFormatter
  case numberBase
  case stringCase
  case urlCodec
  case base64Codec
  case queryParser
  case htmlEntities
  case backslashCodec
  case uuidTool
  case loremIpsum
  case qrCode
  case hashGenerator
  case pdfToolkit
  case pdfOCR
  case imageConverter
  case batchImageResizer
  case imageMetadataInspector
  case videoConverter

  public var id: String { rawValue }
}

public enum ToolOptionKind: String, Codable, Sendable {
  case operation
  case text
  case secureText
  case integer
  case boolean
  case picker
}

public struct ToolOptionChoice: Codable, Hashable, Sendable {
  public var value: String
  public var label: String

  public init(_ value: String, _ label: String) {
    self.value = value
    self.label = label
  }
}

public struct ToolOption: Codable, Identifiable, Hashable, Sendable {
  public var id: String { key }

  public var key: String
  public var label: String
  public var kind: ToolOptionKind
  public var defaultValue: String
  public var choices: [ToolOptionChoice]
  public var help: String?
  public var minimumValue: Int?
  public var maximumValue: Int?

  public init(
    key: String,
    label: String,
    kind: ToolOptionKind,
    defaultValue: String,
    choices: [ToolOptionChoice] = [],
    help: String? = nil,
    minimumValue: Int? = nil,
    maximumValue: Int? = nil
  ) {
    self.key = key
    self.label = label
    self.kind = kind
    self.defaultValue = defaultValue
    self.choices = choices
    self.help = help
    self.minimumValue = minimumValue
    self.maximumValue = maximumValue
  }
}

public enum ToolCapability: String, Codable, Sendable {
  case textInput
  case secondaryInput
  case noInput
  case generatedOutput
  case htmlPreview
  case imageOutput
  case fileInput
}

public struct ToolDefinition: Codable, Identifiable, Hashable, Sendable {
  public var id: ToolID
  public var title: String
  public var subtitle: String
  public var category: ToolCategory
  public var systemImage: String
  public var inputPlaceholder: String
  public var primaryActionTitle: String
  public var sampleInput: String
  public var capabilities: Set<ToolCapability>
  public var options: [ToolOption]

  public init(
    id: ToolID,
    title: String,
    subtitle: String,
    category: ToolCategory,
    systemImage: String,
    inputPlaceholder: String,
    primaryActionTitle: String = "Run",
    sampleInput: String = "",
    capabilities: Set<ToolCapability> = [.textInput],
    options: [ToolOption] = []
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.category = category
    self.systemImage = systemImage
    self.inputPlaceholder = inputPlaceholder
    self.primaryActionTitle = primaryActionTitle
    self.sampleInput = sampleInput
    self.capabilities = capabilities
    self.options = options
  }

  public var defaultOptions: ToolOptions {
    var options = ToolOptions()
    for option in self.options {
      switch option.kind {
      case .operation:
        options.operation = option.defaultValue
      case .boolean:
        options.boolValues[option.key] = option.defaultValue == "true"
      case .integer:
        options.intValues[option.key] = Int(option.defaultValue) ?? 0
      case .text, .secureText, .picker:
        if option.key == "secondaryInput" {
          options.secondaryInput = option.defaultValue
        } else {
          options.textValues[option.key] = option.defaultValue
        }
      }
    }
    return options
  }
}

public struct ToolOptions: Codable, Equatable, Sendable {
  public var operation: String
  public var secondaryInput: String
  public var textValues: [String: String]
  public var boolValues: [String: Bool]
  public var intValues: [String: Int]

  public init(
    operation: String = "",
    secondaryInput: String = "",
    textValues: [String: String] = [:],
    boolValues: [String: Bool] = [:],
    intValues: [String: Int] = [:]
  ) {
    self.operation = operation
    self.secondaryInput = secondaryInput
    self.textValues = textValues
    self.boolValues = boolValues
    self.intValues = intValues
  }

  public subscript(text key: String) -> String {
    get { textValues[key] ?? "" }
    set { textValues[key] = newValue }
  }

  public subscript(bool key: String) -> Bool {
    get { boolValues[key] ?? false }
    set { boolValues[key] = newValue }
  }

  public subscript(int key: String) -> Int {
    get { intValues[key] ?? 0 }
    set { intValues[key] = newValue }
  }
}

public struct ToolDiagnostic: Codable, Hashable, Sendable {
  public enum Severity: String, Codable, Sendable {
    case info
    case warning
    case error
  }

  public var severity: Severity
  public var message: String

  public init(_ severity: Severity, _ message: String) {
    self.severity = severity
    self.message = message
  }
}

public struct ToolResult: Codable, Equatable, Sendable {
  public var output: String
  public var diagnostics: [ToolDiagnostic]
  public var metadata: [String: String]
  public var htmlPreview: String?
  public var imagePNGBase64: String?

  public init(
    output: String,
    diagnostics: [ToolDiagnostic] = [],
    metadata: [String: String] = [:],
    htmlPreview: String? = nil,
    imagePNGBase64: String? = nil
  ) {
    self.output = output
    self.diagnostics = diagnostics
    self.metadata = metadata
    self.htmlPreview = htmlPreview
    self.imagePNGBase64 = imagePNGBase64
  }
}

public struct ToolSuggestion: Codable, Hashable, Sendable {
  public var toolID: ToolID
  public var confidence: Double
  public var reason: String

  public init(toolID: ToolID, confidence: Double, reason: String) {
    self.toolID = toolID
    self.confidence = confidence
    self.reason = reason
  }
}

public enum ToolEngineError: LocalizedError, Equatable {
  case emptyInput
  case invalidInput(String)
  case runtimeUnavailable(String)
  case unsupported(String)

  public var errorDescription: String? {
    switch self {
    case .emptyInput:
      "Input is empty."
    case .invalidInput(let message):
      message
    case .runtimeUnavailable(let message):
      message
    case .unsupported(let message):
      message
    }
  }
}
