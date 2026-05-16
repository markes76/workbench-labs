import Foundation

public enum ClipboardInspector {
  public static func suggestions(for rawText: String) -> [ToolSuggestion] {
    let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return [] }

    var suggestions: [ToolSuggestion] = []

    if looksLikeJSON(text) {
      suggestions.append(.init(toolID: .jsonFormatter, confidence: 0.98, reason: "Looks like JSON."))
    }
    if looksLikeJWT(text) {
      suggestions.append(.init(toolID: .jwtDebugger, confidence: 0.96, reason: "Looks like a JSON Web Token."))
    }
    if SecretScanner.likelyContainsSecret(text), !looksLikeJWT(text) {
      suggestions.append(.init(toolID: .secretScanner, confidence: 0.97, reason: "Contains secret-looking values."))
    }
    if UUID(uuidString: text) != nil {
      suggestions.append(.init(toolID: .uuidTool, confidence: 0.95, reason: "Looks like a UUID."))
    }
    if looksLikeTimestamp(text) {
      suggestions.append(.init(toolID: .unixTimestamp, confidence: 0.9, reason: "Looks like a Unix timestamp."))
    }
    if looksLikeURLOrQuery(text) {
      suggestions.append(.init(toolID: .queryParser, confidence: 0.86, reason: "Looks like a URL or query string."))
    }
    if looksLikeBase64(text) {
      suggestions.append(.init(toolID: .base64Codec, confidence: 0.76, reason: "Looks like Base64."))
    }
    if text.contains("&lt;") || text.contains("&amp;") || text.contains("&#") {
      suggestions.append(.init(toolID: .htmlEntities, confidence: 0.74, reason: "Contains HTML entities."))
    }
    if text.contains("%20") || text.contains("%3A") || text.contains("%2F") {
      suggestions.append(.init(toolID: .urlCodec, confidence: 0.72, reason: "Contains percent-encoded URL text."))
    }
    if text.contains("<html") || text.contains("<div") || text.contains("<svg") {
      suggestions.append(.init(toolID: .htmlPreview, confidence: 0.7, reason: "Looks like HTML or SVG."))
    }

    if suggestions.isEmpty {
      suggestions.append(.init(toolID: .stringInspector, confidence: 0.2, reason: "Fallback text inspection."))
    }

    return suggestions.sorted { $0.confidence > $1.confidence }
  }

  private static func looksLikeJSON(_ text: String) -> Bool {
    guard let first = text.first, ["{", "["].contains(String(first)) else { return false }
    return (try? JSONSerialization.jsonObject(with: Data(text.utf8))) != nil
  }

  private static func looksLikeJWT(_ text: String) -> Bool {
    let parts = text.split(separator: ".")
    guard parts.count == 3 else { return false }
    return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } }
  }

  private static func looksLikeTimestamp(_ text: String) -> Bool {
    guard let value = Double(text), value > 0 else { return false }
    if text.count == 10 {
      return value > 946_684_800 && value < 4_102_444_800
    }
    if text.count == 13 {
      return value > 946_684_800_000 && value < 4_102_444_800_000
    }
    return false
  }

  private static func looksLikeURLOrQuery(_ text: String) -> Bool {
    if URL(string: text)?.scheme?.isEmpty == false { return true }
    return text.contains("=") && text.contains("&")
  }

  private static func looksLikeBase64(_ text: String) -> Bool {
    guard text.count >= 8, text.count % 4 == 0 else { return false }
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=_-")
    return text.rangeOfCharacter(from: allowed.inverted) == nil && Data(base64Encoded: text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")) != nil
  }
}
