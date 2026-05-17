import CryptoKit
import Foundation

public final class ToolRunner: @unchecked Sendable {
  private let jsRunner: JavaScriptToolRunner

  public init(jsRunner: JavaScriptToolRunner = JavaScriptToolRunner()) {
    self.jsRunner = jsRunner
  }

  public func run(toolID: ToolID, input: String, options: ToolOptions = ToolOptions()) async throws -> ToolResult {
    try await Task.detached(priority: .userInitiated) {
      try self.runSync(toolID: toolID, input: input, options: self.normalizedOptions(toolID: toolID, options: options))
    }.value
  }

  private func runSync(toolID: ToolID, input: String, options: ToolOptions) throws -> ToolResult {
    switch toolID {
    case .unixTimestamp:
      return try timestamp(input, options: options)
    case .regexTester:
      return try regex(input, options: options)
    case .jwtDebugger:
      return try jwt(input, options: options)
    case .htmlPreview:
      return ToolResult(output: "HTML preview ready.", htmlPreview: input)
    case .textDiff:
      return try jsRunner.run(tool: "text-diff", input: input, options: options)
    case .markdownPreview:
      var result = try jsRunner.run(tool: "markdown-preview", input: input, options: options)
      result.htmlPreview = result.output
      return result
    case .stringInspector:
      return stringInspector(input)
    case .secretScanner:
      return try secretScanner(input, options: options)
    case .jsonSchemaValidator:
      return try jsRunner.run(tool: "json-schema", input: input, options: options)
    case .envInspector:
      return EnvInspector.run(input: input, options: options)
    case .jsonFormatter:
      return try json(input, options: options)
    case .htmlFormatter:
      return try jsRunner.run(tool: options.operation == "minify" ? "html-minify" : "html-beautify", input: input, options: options)
    case .cssFormatter:
      return try jsRunner.run(tool: options.operation == "minify" ? "css-minify" : "css-beautify", input: input, options: options)
    case .javascriptFormatter:
      return try jsRunner.run(tool: options.operation == "minify" ? "js-minify" : "js-beautify", input: input, options: options)
    case .xmlFormatter:
      return try jsRunner.run(tool: options.operation == "minify" ? "xml-minify" : "xml-beautify", input: input, options: options)
    case .yamlToJson:
      return try jsRunner.run(tool: "yaml-to-json", input: input, options: options)
    case .jsonToYaml:
      return try jsRunner.run(tool: "json-to-yaml", input: input, options: options)
    case .htmlToJSX:
      return try jsRunner.run(tool: "html-to-jsx", input: input, options: options)
    case .sqlFormatter:
      return try jsRunner.run(tool: "sql-format", input: input, options: options)
    case .numberBase:
      return try numberBase(input, options: options)
    case .stringCase:
      return stringCase(input, options: options)
    case .urlCodec:
      return try urlCodec(input, options: options)
    case .base64Codec:
      return try base64(input, options: options)
    case .queryParser:
      return try queryParser(input)
    case .htmlEntities:
      return try jsRunner.run(tool: options.operation == "decode" ? "html-entities-decode" : "html-entities-encode", input: input, options: options)
    case .backslashCodec:
      return try backslash(input, options: options)
    case .uuidTool:
      return try uuid(input, options: options)
    case .loremIpsum:
      return lorem(input, options: options)
    case .qrCode:
      return try qr(input, options: options)
    case .hashGenerator:
      return hash(input, options: options)
    case .pdfToolkit:
      return try PDFToolkit.run(input: input, options: options)
    case .pdfOCR:
      return try PDFOCRExtractor.run(input: input, options: options)
    case .imageConverter:
      return try ImageConverter.run(input: input, options: options)
    case .batchImageResizer:
      return try BatchImageResizer.run(input: input, options: options)
    case .imageMetadataInspector:
      return try ImageMetadataInspector.run(input: input, options: options)
    case .videoConverter:
      return try VideoConverter.run(input: input, options: options)
    }
  }

  private func normalizedOptions(toolID: ToolID, options: ToolOptions) -> ToolOptions {
    var merged = ToolRegistry.definition(for: toolID).defaultOptions
    if !options.operation.isEmpty { merged.operation = options.operation }
    if !options.secondaryInput.isEmpty { merged.secondaryInput = options.secondaryInput }
    for (key, value) in options.textValues { merged.textValues[key] = value }
    for (key, value) in options.boolValues { merged.boolValues[key] = value }
    for (key, value) in options.intValues { merged.intValues[key] = value }
    return merged
  }

  private func requireInput(_ input: String) throws -> String {
    let trimmed = input.trimmedForTool
    guard !trimmed.isEmpty else { throw ToolEngineError.emptyInput }
    return trimmed
  }

  private func json(_ input: String, options: ToolOptions) throws -> ToolResult {
    let tool = options.operation == "minify" ? "json-minify" : "json"
    do {
      return try jsRunner.run(tool: tool, input: input, options: options)
    } catch {
      let data = Data(input.utf8)
      let object = try JSONSerialization.jsonObject(with: data)
      let outputData = try JSONSerialization.data(
        withJSONObject: object,
        options: options.operation == "minify" ? [] : [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      )
      return ToolResult(output: String(decoding: outputData, as: UTF8.self), metadata: ["valid": "true"])
    }
  }

  private func urlCodec(_ input: String, options: ToolOptions) throws -> ToolResult {
    let text = try requireInput(input)
    if options.operation == "decode" {
      return ToolResult(output: text.removingPercentEncoding ?? text)
    }
    let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: ":#[]@!$&'()*+,;=?"))
    return ToolResult(output: text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text)
  }

  private func base64(_ input: String, options: ToolOptions) throws -> ToolResult {
    let urlSafe = options.boolValues["urlSafe"] ?? false
    let stripDataURLPrefix = options.boolValues["stripDataURLPrefix"] ?? false
    let removeTrailingNullByte = options.boolValues["removeTrailingNullByte"] ?? false
    var metadata: [String: String] = [:]
    let operation = options.operation

    if operation == "decode" {
      guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw ToolEngineError.emptyInput
      }
      let decodeResult = try decodeBase64(
        input,
        stripDataURLPrefix: stripDataURLPrefix,
        removeTrailingNullByte: removeTrailingNullByte
      )
      metadata.merge(decodeResult.metadata) { _, new in new }
      metadata["operation"] = "decode"
      return ToolResult(output: decodeResult.output, metadata: metadata)
    }

    guard !input.isEmpty else {
      throw ToolEngineError.emptyInput
    }

    var encoded = Data(input.utf8).base64EncodedString()
    if urlSafe {
      encoded = encoded.replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
    }
    metadata["operation"] = "encode"
    return ToolResult(output: encoded, metadata: metadata)
  }

  private func decodedUTF8(from input: String, stripDataURLPrefix: Bool) -> String? {
    guard let data = try? decodedBase64Data(input, stripDataURLPrefix: stripDataURLPrefix) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  private func decodeBase64(
    _ input: String,
    stripDataURLPrefix: Bool,
    removeTrailingNullByte: Bool
  ) throws -> (output: String, metadata: [String: String]) {
    var data = try decodedBase64Data(input, stripDataURLPrefix: stripDataURLPrefix)
    var metadata: [String: String] = [:]
    if stripDataURLPrefix, input.range(of: ";base64,", options: .caseInsensitive) != nil {
      metadata["strippedDataURLPrefix"] = "true"
    }
    if removeTrailingNullByte {
      var removed = false
      while data.last == 0 {
        data.removeLast()
        removed = true
      }
      if removed {
        metadata["removedTrailingNullByte"] = "true"
      }
    }
    return (String(data: data, encoding: .utf8) ?? data.hexadecimalString, metadata)
  }

  private func decodedBase64Data(_ input: String, stripDataURLPrefix: Bool) throws -> Data {
    var normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if stripDataURLPrefix, let range = normalized.range(of: ";base64,", options: .caseInsensitive) {
      normalized = String(normalized[range.upperBound...])
    }
    normalized = normalized
      .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    while normalized.count % 4 != 0 { normalized.append("=") }
    guard let data = Data(base64Encoded: normalized) else {
      throw ToolEngineError.invalidInput("Input is not valid Base64.")
    }
    return data
  }

  private func queryParser(_ input: String) throws -> ToolResult {
    let text = try requireInput(input)
    let components: URLComponents
    if text.contains("://"), let parsed = URLComponents(string: text) {
      components = parsed
    } else {
      let query = text.hasPrefix("?") ? String(text.dropFirst()) : text
      guard let parsed = URLComponents(string: "workbenchlabs://local?\(query)") else {
        throw ToolEngineError.invalidInput("Could not parse the URL or query string.")
      }
      components = parsed
    }
    var object: [String: Any] = [:]
    object["scheme"] = components.scheme ?? ""
    object["host"] = components.host ?? ""
    object["path"] = components.path
    object["fragment"] = components.fragment ?? ""
    object["queryItems"] = (components.queryItems ?? []).map { ["name": $0.name, "value": $0.value ?? ""] }
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    return ToolResult(output: String(decoding: data, as: UTF8.self))
  }

  private func backslash(_ input: String, options: ToolOptions) throws -> ToolResult {
    if options.operation == "unescape" {
      return ToolResult(output: try StringTransforms.unescaped(input))
    }
    return ToolResult(output: StringTransforms.escaped(input))
  }

  private func numberBase(_ input: String, options: ToolOptions) throws -> ToolResult {
    let raw = try requireInput(input).replacingOccurrences(of: "_", with: "")
    let sourceBase = options.textValues["sourceBase"] ?? "auto"
    let (digits, base): (String, Int) = {
      if sourceBase != "auto", let base = Int(sourceBase) { return (raw, base) }
      if raw.lowercased().hasPrefix("0x") { return (String(raw.dropFirst(2)), 16) }
      if raw.lowercased().hasPrefix("0b") { return (String(raw.dropFirst(2)), 2) }
      if raw.lowercased().hasPrefix("0o") { return (String(raw.dropFirst(2)), 8) }
      return (raw, 10)
    }()
    guard let value = Int64(digits, radix: base) else {
      throw ToolEngineError.invalidInput("Could not parse \(raw) as base \(base).")
    }
    let unsigned = UInt64(bitPattern: value)
    let output = """
    Decimal: \(value)
    Hex: 0x\(String(unsigned, radix: 16, uppercase: true))
    Octal: 0o\(String(unsigned, radix: 8))
    Binary: 0b\(String(unsigned, radix: 2))
    """
    return ToolResult(output: output)
  }

  private func stringCase(_ input: String, options: ToolOptions) -> ToolResult {
    let cases = StringTransforms.cases(for: input)
    if options.operation != "all" {
      let key: String = switch options.operation {
      case "camel": "camelCase"
      case "pascal": "PascalCase"
      case "snake": "snake_case"
      case "kebab": "kebab-case"
      case "constant": "CONSTANT_CASE"
      case "title": "Title Case"
      default: "camelCase"
      }
      return ToolResult(output: cases[key] ?? "")
    }
    return ToolResult(output: cases.map { "\($0.key): \($0.value)" }.sorted().joined(separator: "\n"))
  }

  private func stringInspector(_ input: String) -> ToolResult {
    let scalars = input.unicodeScalars.map { scalar in
      "U+\(String(format: "%04X", scalar.value)) \(scalar)"
    }.joined(separator: "\n")
    let lines = input.split(separator: "\n", omittingEmptySubsequences: false).count
    let output = """
    Characters: \(input.count)
    Unicode scalars: \(input.unicodeScalars.count)
    UTF-8 bytes: \(Data(input.utf8).count)
    UTF-16 code units: \(input.utf16.count)
    Lines: \(lines)

    Escaped:
    \(StringTransforms.escaped(input))

    Unicode Scalars:
    \(scalars)
    """
    return ToolResult(output: output)
  }

  private func secretScanner(_ input: String, options: ToolOptions) throws -> ToolResult {
    let text = try requireInput(input)
    let result = SecretScanner.scan(text)
    if options.operation == "redact" {
      return ToolResult(
        output: result.redactedText,
        diagnostics: result.diagnostics,
        metadata: [
          "findings": String(result.findings.count),
          "highConfidence": String(result.findings.filter { $0.confidence == .high }.count)
        ]
      )
    }

    return ToolResult(
      output: result.report,
      diagnostics: result.diagnostics,
      metadata: [
        "findings": String(result.findings.count),
        "highConfidence": String(result.findings.filter { $0.confidence == .high }.count)
      ]
    )
  }

  private func hash(_ input: String, options: ToolOptions) -> ToolResult {
    let data = Data(input.utf8)
    let algorithm = options.textValues["algorithm"] ?? "all"
    let values: [(String, String)] = [
      ("md5", Insecure.MD5.hash(data: data).hexString),
      ("sha1", Insecure.SHA1.hash(data: data).hexString),
      ("sha256", SHA256.hash(data: data).hexString),
      ("sha384", SHA384.hash(data: data).hexString),
      ("sha512", SHA512.hash(data: data).hexString)
    ]
    let filtered = algorithm == "all" ? values : values.filter { $0.0 == algorithm }
    let output = filtered.map { "\($0.0.uppercased()): \($0.1)" }.joined(separator: "\n")
    return ToolResult(output: output)
  }

  private func uuid(_ input: String, options: ToolOptions) throws -> ToolResult {
    let text = input.trimmedForTool
    if !text.isEmpty {
      guard let uuid = UUID(uuidString: text) else {
        throw ToolEngineError.invalidInput("Input is not a valid UUID.")
      }
      let normalized = uuid.uuidString.lowercased()
      let version = normalized.split(separator: "-")[2].first.map(String.init) ?? "?"
      let variantNibble = normalized.split(separator: "-")[3].first.flatMap { Int(String($0), radix: 16) } ?? 0
      let variant = switch variantNibble {
      case 8...11: "RFC 4122"
      case 12...13: "Microsoft"
      case 14...15: "Future"
      default: "NCS"
      }
      return ToolResult(output: """
      UUID: \(normalized)
      Version: \(version)
      Variant: \(variant)
      Uppercase: \(uuid.uuidString)
      URN: urn:uuid:\(normalized)
      """)
    }

    let count = min(max(options.intValues["count"] ?? 4, 1), 100)
    return ToolResult(output: (0..<count).map { _ in UUID().uuidString.lowercased() }.joined(separator: "\n"))
  }

  private func lorem(_ input: String, options: ToolOptions) -> ToolResult {
    let baseWords = (input.trimmedForTool.isEmpty ? loremWords : StringTransforms.words(from: input))
    let count = min(max(options.intValues["count"] ?? 3, 1), 200)
    let operation = options.operation
    switch operation {
    case "words":
      return ToolResult(output: generatedWords(baseWords, count: count).joined(separator: " "))
    case "sentences":
      return ToolResult(output: (0..<count).map { _ in sentence(from: baseWords) }.joined(separator: " "))
    default:
      return ToolResult(output: (0..<count).map { _ in paragraph(from: baseWords) }.joined(separator: "\n\n"))
    }
  }

  private func timestamp(_ input: String, options: ToolOptions) throws -> ToolResult {
    let kind = UnixTimeInputKind(rawValue: options.textValues["inputKind"] ?? "") ?? .unixSeconds
    let result = try UnixTimeConverter.convert(input: input, inputKind: kind)
    return ToolResult(output: """
    Local: \(result.local)
    UTC (ISO 8601): \(result.utcISO8601)
    Relative: \(result.relative)
    Unix time: \(result.unixSeconds)
    Milliseconds: \(result.unixMilliseconds)
    Day of year: \(result.dayOfYear)
    Week of year: \(result.weekOfYear)
    Is leap year?: \(result.isLeapYear)

    Other formats (local):
    \(result.localFormats.joined(separator: "\n"))
    """)
  }

  private func regex(_ input: String, options: ToolOptions) throws -> ToolResult {
    let pattern = options.textValues["pattern"]?.isEmpty == false ? options.textValues["pattern"]! : options.secondaryInput
    guard !pattern.isEmpty else { throw ToolEngineError.invalidInput("Enter a regular expression pattern.") }
    var regexOptions: NSRegularExpression.Options = []
    if options.boolValues["caseInsensitive"] == true { regexOptions.insert(.caseInsensitive) }
    let regex = try NSRegularExpression(pattern: pattern, options: regexOptions)
    let range = NSRange(input.startIndex..<input.endIndex, in: input)
    let matches = regex.matches(in: input, range: range)
    let lines = matches.enumerated().map { index, match in
      var parts = ["Match \(index + 1):"]
      for groupIndex in 0..<match.numberOfRanges {
        let nsRange = match.range(at: groupIndex)
        if let range = Range(nsRange, in: input) {
          parts.append("  Group \(groupIndex): \(input[range])")
        }
      }
      return parts.joined(separator: "\n")
    }
    return ToolResult(output: lines.isEmpty ? "No matches." : lines.joined(separator: "\n\n"), metadata: ["matches": "\(matches.count)"])
  }

  private func jwt(_ input: String, options: ToolOptions) throws -> ToolResult {
    let token = try requireInput(input)
    let parts = token.split(separator: ".").map(String.init)
    guard parts.count == 3 else { throw ToolEngineError.invalidInput("A JWT must have three dot-separated parts.") }
    let headerData = try base64URLDecode(parts[0])
    let payloadData = try base64URLDecode(parts[1])
    let signatureData = try base64URLDecode(parts[2])
    let headerObject = try JSONSerialization.jsonObject(with: headerData) as? [String: Any] ?? [:]
    let algorithm = headerObject["alg"] as? String ?? "unknown"
    let header = prettyJSON(headerData)
    let payload = prettyJSON(payloadData)
    var diagnostics: [ToolDiagnostic] = []
    if let secret = options.textValues["secret"], !secret.isEmpty {
      if ["HS256", "HS384", "HS512"].contains(algorithm) {
        let signingInput = Data("\(parts[0]).\(parts[1])".utf8)
        let key = SymmetricKey(data: Data(secret.utf8))
        let expected: Data
        switch algorithm {
        case "HS384": expected = Data(HMAC<SHA384>.authenticationCode(for: signingInput, using: key))
        case "HS512": expected = Data(HMAC<SHA512>.authenticationCode(for: signingInput, using: key))
        default: expected = Data(HMAC<SHA256>.authenticationCode(for: signingInput, using: key))
        }
        diagnostics.append(.init(expected == signatureData ? .info : .error, expected == signatureData ? "Signature verified." : "Signature does not match this secret."))
      } else {
        diagnostics.append(.init(.warning, "Signature verification is implemented for HS256, HS384, and HS512."))
      }
    }
    return ToolResult(output: """
    Header:
    \(header)

    Payload:
    \(payload)

    Algorithm: \(algorithm)
    Signature bytes: \(signatureData.count)
    """, diagnostics: diagnostics)
  }

  private func qr(_ input: String, options: ToolOptions) throws -> ToolResult {
    if options.operation == "read" {
      let decoded = try QRCodeService.readQRCode(fromImageAt: try requireInput(input))
      return ToolResult(output: decoded)
    }
    let png = try QRCodeService.pngData(for: try requireInput(input))
    return ToolResult(output: "QR code generated.", imagePNGBase64: png.base64EncodedString())
  }

  private func prettyJSON(_ data: Data) -> String {
    guard
      let object = try? JSONSerialization.jsonObject(with: data),
      let formatted = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    else {
      return String(decoding: data, as: UTF8.self)
    }
    return String(decoding: formatted, as: UTF8.self)
  }

  private func base64URLDecode(_ segment: String) throws -> Data {
    var normalized = segment.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while normalized.count % 4 != 0 { normalized.append("=") }
    guard let data = Data(base64Encoded: normalized) else {
      throw ToolEngineError.invalidInput("Invalid Base64URL segment.")
    }
    return data
  }

  private let loremWords = [
    "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit",
    "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore", "et", "dolore",
    "magna", "aliqua", "enim", "ad", "minim", "veniam"
  ]

  private func generatedWords(_ words: [String], count: Int) -> [String] {
    guard !words.isEmpty else { return Array(loremWords.prefix(count)) }
    return (0..<count).map { words[$0 % words.count] }
  }

  private func sentence(from words: [String]) -> String {
    let length = Int.random(in: 7...14)
    var text = generatedWords(words.isEmpty ? loremWords : words, count: length).joined(separator: " ")
    text.replaceSubrange(text.startIndex...text.startIndex, with: text[text.startIndex].uppercased())
    return text + "."
  }

  private func paragraph(from words: [String]) -> String {
    (0..<Int.random(in: 3...5)).map { _ in sentence(from: words) }.joined(separator: " ")
  }
}

private extension Digest {
  var hexString: String {
    map { String(format: "%02x", $0) }.joined()
  }
}
