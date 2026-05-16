import Foundation

enum StringTransforms {
  static func escaped(_ input: String) -> String {
    var output = ""
    for scalar in input.unicodeScalars {
      switch scalar {
      case "\\": output += "\\\\"
      case "\"": output += "\\\""
      case "\n": output += "\\n"
      case "\r": output += "\\r"
      case "\t": output += "\\t"
      case "\0": output += "\\0"
      default:
        if scalar.value < 32 {
          output += String(format: "\\u{%X}", scalar.value)
        } else {
          output.unicodeScalars.append(scalar)
        }
      }
    }
    return output
  }

  static func unescaped(_ input: String) throws -> String {
    var output = ""
    var iterator = input.makeIterator()
    while let character = iterator.next() {
      guard character == "\\" else {
        output.append(character)
        continue
      }
      guard let escaped = iterator.next() else {
        output.append("\\")
        break
      }
      switch escaped {
      case "\\": output.append("\\")
      case "\"": output.append("\"")
      case "n": output.append("\n")
      case "r": output.append("\r")
      case "t": output.append("\t")
      case "0": output.append("\0")
      case "u":
        guard let brace = iterator.next() else {
          output.append("\\u")
          break
        }
        guard brace == "{" else {
          output.append("\\u")
          output.append(brace)
          break
        }

        var hex = ""
        var foundClosingBrace = false
        while let next = iterator.next() {
          if next == "}" {
            foundClosingBrace = true
            break
          }
          hex.append(next)
        }

        if
          foundClosingBrace,
          let value = UInt32(hex, radix: 16),
          let scalar = UnicodeScalar(value)
        {
          output.unicodeScalars.append(scalar)
        } else {
          output.append("\\u{")
          output.append(hex)
          if foundClosingBrace {
            output.append("}")
          }
        }
      default:
        output.append("\\")
        output.append(escaped)
      }
    }
    return output
  }

  static func words(from input: String) -> [String] {
    let camelSeparated = input.replacingOccurrences(
      of: "([a-z0-9])([A-Z])",
      with: "$1 $2",
      options: .regularExpression
    )
    return camelSeparated
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
      .map { $0.lowercased() }
  }

  static func cases(for input: String) -> [String: String] {
    let parts = words(from: input)
    guard !parts.isEmpty else { return [:] }
    let capitalized = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }
    let camel = parts[0] + capitalized.dropFirst().joined()
    return [
      "camelCase": camel,
      "PascalCase": capitalized.joined(),
      "snake_case": parts.joined(separator: "_"),
      "kebab-case": parts.joined(separator: "-"),
      "CONSTANT_CASE": parts.map { $0.uppercased() }.joined(separator: "_"),
      "Title Case": capitalized.joined(separator: " ")
    ]
  }
}

extension Data {
  var hexadecimalString: String {
    map { String(format: "%02x", $0) }.joined()
  }
}

extension String {
  var trimmedForTool: String {
    trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
