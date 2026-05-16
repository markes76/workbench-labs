import Foundation

public enum Base64InputDetector {
  public static func isDecodableUTF8(_ input: String, stripDataURLPrefix: Bool = true) -> Bool {
    do {
      let data = try decodedData(input, stripDataURLPrefix: stripDataURLPrefix)
      return String(data: data, encoding: .utf8) != nil
    } catch {
      return false
    }
  }

  private static func decodedData(_ input: String, stripDataURLPrefix: Bool) throws -> Data {
    var normalized = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalized.isEmpty else {
      throw ToolEngineError.emptyInput
    }
    if stripDataURLPrefix, let range = normalized.range(of: ";base64,", options: .caseInsensitive) {
      normalized = String(normalized[range.upperBound...])
    }
    normalized = normalized
      .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    while normalized.count % 4 != 0 { normalized.append("=") }
    guard let data = Data(base64Encoded: normalized), !data.isEmpty else {
      throw ToolEngineError.invalidInput("Input is not valid Base64.")
    }
    return data
  }
}
