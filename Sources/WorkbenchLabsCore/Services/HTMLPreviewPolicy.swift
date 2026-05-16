import Foundation

public enum HTMLPreviewPolicy {
  public static func injectContentSecurityPolicy(into html: String, allowJavaScript: Bool) -> String {
    let scriptSource = allowJavaScript ? "'unsafe-inline'" : "'none'"
    let policy = """
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data: blob:; style-src 'unsafe-inline' data:; font-src data:; script-src \(scriptSource); connect-src 'none'; frame-src 'none'; media-src data: blob:; object-src 'none'; base-uri 'none'; form-action 'none'; navigate-to 'none'">
    """

    guard let headStart = html.range(of: "<head", options: [.caseInsensitive]) else {
      return "<head>\(policy)</head>\n\(html)"
    }
    guard let headTagEnd = html[headStart.upperBound...].firstIndex(of: ">") else {
      return "\(policy)\n\(html)"
    }
    var updated = html
    updated.insert(contentsOf: "\n\(policy)", at: html.index(after: headTagEnd))
    return updated
  }
}
