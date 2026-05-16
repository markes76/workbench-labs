import SwiftUI
import WebKit
import WorkbenchLabsCore

struct WebPreviewView: NSViewRepresentable {
  @AppStorage("preview.allowJavaScript") private var allowJavaScript = false
  @AppStorage("preview.allowNavigation") private var allowNavigation = false
  @AppStorage("preview.allowExternalRequests") private var allowExternalRequests = false

  var html: String
  var allowJavaScriptOverride: Bool?
  var allowNavigationOverride: Bool?
  var allowExternalRequestsOverride: Bool?

  private var effectiveAllowJavaScript: Bool {
    allowJavaScriptOverride ?? allowJavaScript
  }

  private var effectiveAllowNavigation: Bool {
    allowNavigationOverride ?? allowNavigation
  }

  private var effectiveAllowExternalRequests: Bool {
    allowExternalRequestsOverride ?? allowExternalRequests
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(
      allowJavaScript: effectiveAllowJavaScript,
      allowNavigation: effectiveAllowNavigation,
      allowExternalRequests: effectiveAllowExternalRequests
    )
  }

  func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
    configuration.defaultWebpagePreferences.allowsContentJavaScript = effectiveAllowJavaScript

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.setValue(false, forKey: "drawsBackground")
    return webView
  }

  func updateNSView(_ webView: WKWebView, context: Context) {
    context.coordinator.allowJavaScript = effectiveAllowJavaScript
    context.coordinator.allowNavigation = effectiveAllowNavigation
    context.coordinator.allowExternalRequests = effectiveAllowExternalRequests
    webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = effectiveAllowJavaScript
    webView.loadHTMLString(previewHTML, baseURL: nil)
  }

  private var previewHTML: String {
    guard !effectiveAllowExternalRequests else { return html }
    return HTMLPreviewPolicy.injectContentSecurityPolicy(
      into: html,
      allowJavaScript: effectiveAllowJavaScript
    )
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    var allowJavaScript: Bool
    var allowNavigation: Bool
    var allowExternalRequests: Bool

    init(allowJavaScript: Bool, allowNavigation: Bool, allowExternalRequests: Bool) {
      self.allowJavaScript = allowJavaScript
      self.allowNavigation = allowNavigation
      self.allowExternalRequests = allowExternalRequests
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      preferences: WKWebpagePreferences,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
      preferences.allowsContentJavaScript = allowJavaScript
      if shouldAllow(navigationAction) {
        decisionHandler(.allow, preferences)
      } else {
        decisionHandler(.cancel, preferences)
      }
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
      if shouldAllow(navigationAction) {
        decisionHandler(.allow)
      } else {
        decisionHandler(.cancel)
      }
    }

    private func shouldAllow(_ action: WKNavigationAction) -> Bool {
      let isLocalURL = isLocalPreviewURL(action.request.url)
      guard isLocalURL || allowExternalRequests else {
        return false
      }
      if action.navigationType == .other {
        return true
      }
      return allowNavigation
    }

    private func isLocalPreviewURL(_ url: URL?) -> Bool {
      guard let url else { return true }
      guard let scheme = url.scheme?.lowercased() else { return true }
      return ["about", "data", "blob", "file"].contains(scheme)
    }
  }
}
