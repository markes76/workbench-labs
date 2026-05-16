import AppKit
import Foundation
import WorkbenchLabsCore

@MainActor
final class WorkbenchStore: ObservableObject {
  @Published var selectedToolID: ToolID = .jsonFormatter
  @Published var searchText: String = ""
  @Published var sessions: [ToolID: ToolSessionState] = Dictionary(
    uniqueKeysWithValues: ToolRegistry.all.map { ($0.id, ToolSessionState(definition: $0)) }
  )
  @Published var suggestions: [ToolSuggestion] = []
  @Published var isRunning = false
  @Published var detailRefreshID = UUID()
  @Published var runRequest: ToolRunRequest?

  private let runner = ToolRunner()
  private var runGenerationByTool: [ToolID: Int] = [:]
  private var runningGenerations: Set<String> = []

  var selectedDefinition: ToolDefinition {
    ToolRegistry.definition(for: selectedToolID)
  }

  var selectedSession: ToolSessionState {
    sessions[selectedToolID] ?? ToolSessionState(definition: selectedDefinition)
  }

  func bindingForSelectedSession() -> BindingBox {
    BindingBox(
      get: { [weak self] in self?.selectedSession ?? ToolSessionState(definition: ToolRegistry.definition(for: .jsonFormatter)) },
      set: { [weak self] value in self?.sessions[self?.selectedToolID ?? .jsonFormatter] = value }
    )
  }

  func filteredTools(in category: ToolCategory) -> [ToolDefinition] {
    let tools = ToolRegistry.all.filter { $0.category == category }
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !query.isEmpty else { return tools }
    return tools.filter {
      $0.title.lowercased().contains(query) ||
      $0.subtitle.lowercased().contains(query) ||
      $0.id.rawValue.lowercased().contains(query)
    }
  }

  func setInput(_ input: String, for toolID: ToolID? = nil) {
    let id = toolID ?? selectedToolID
    var session = sessions[id] ?? ToolSessionState(definition: ToolRegistry.definition(for: id))
    session.input = input
    sessions[id] = session
  }

  func inspectClipboard() {
    guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else { return }
    inspect(text: text)
  }

  func inspect(text: String) {
    suggestions = ClipboardInspector.suggestions(for: text)
    if let suggestion = suggestions.first {
      selectedToolID = suggestion.toolID
    }
    setInput(text)
    detailRefreshID = UUID()
    runSelectedTool()
  }

  func runSelectedTool() {
    let toolID = selectedToolID
    let session = selectedSession
    let generation = (runGenerationByTool[toolID] ?? 0) + 1
    runGenerationByTool[toolID] = generation
    let runningKey = "\(toolID.rawValue)-\(generation)"
    runningGenerations.insert(runningKey)
    isRunning = true
    Task {
      do {
        let result = try await runner.run(toolID: toolID, input: session.input, options: session.options)
        guard self.runGenerationByTool[toolID] == generation else {
          self.finishRun(key: runningKey)
          return
        }
        var next = self.sessions[toolID] ?? ToolSessionState(definition: ToolRegistry.definition(for: toolID))
        next.output = result.output
        next.diagnostics = result.diagnostics
        next.metadata = result.metadata
        next.htmlPreview = result.htmlPreview
        next.imagePNGBase64 = result.imagePNGBase64
        next.errorMessage = nil
        self.sessions[toolID] = next
      } catch {
        guard self.runGenerationByTool[toolID] == generation else {
          self.finishRun(key: runningKey)
          return
        }
        var next = self.sessions[toolID] ?? ToolSessionState(definition: ToolRegistry.definition(for: toolID))
        next.output = ""
        next.diagnostics = []
        next.htmlPreview = nil
        next.imagePNGBase64 = nil
        next.errorMessage = error.localizedDescription
        self.sessions[toolID] = next
      }
      self.finishRun(key: runningKey)
    }
  }

  func runSelectedToolFromCommand() {
    switch selectedToolID {
    case .unixTimestamp, .jsonFormatter, .base64Codec:
      runRequest = ToolRunRequest(toolID: selectedToolID)
    default:
      runSelectedTool()
    }
  }

  func copyOutput() {
    let output = selectedSession.output
    guard !output.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(output, forType: .string)
  }

  func copyImageOutput() {
    guard
      let base64 = selectedSession.imagePNGBase64,
      let data = Data(base64Encoded: base64),
      let image = NSImage(data: data)
    else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.writeObjects([image])
  }

  func useOutputAsInput() {
    let output = selectedSession.output
    guard !output.isEmpty else { return }
    var session = selectedSession
    session.input = output
    if let nextOperation = ToolOperationBehavior.inverseOperation(
      for: selectedToolID,
      currentOperation: session.options.operation
    ) {
      session.options.operation = nextOperation
    }
    sessions[selectedToolID] = session
    detailRefreshID = UUID()
  }

  func loadFile(url: URL) {
    loadFiles(urls: [url])
  }

  func loadFiles(urls: [URL]) {
    guard !urls.isEmpty else { return }
    if selectedToolID == .qrCode {
      var session = selectedSession
      session.input = urls[0].path
      session.options.operation = "read"
      sessions[.qrCode] = session
      detailRefreshID = UUID()
      return
    }

    if selectedDefinition.capabilities.contains(.fileInput) {
      setInput(urls.map(\.path).joined(separator: "\n"))
      detailRefreshID = UUID()
      return
    }

    guard let text = try? String(contentsOf: urls[0], encoding: .utf8) else { return }
    setInput(text)
    detailRefreshID = UUID()
  }

  func saveOutput(to url: URL) throws {
    try selectedSession.output.write(to: url, atomically: true, encoding: .utf8)
  }

  func saveImageOutput(to url: URL) throws {
    guard let base64 = selectedSession.imagePNGBase64, let data = Data(base64Encoded: base64) else {
      throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
  }

  private func finishRun(key: String) {
    runningGenerations.remove(key)
    isRunning = !runningGenerations.isEmpty
  }
}

struct BindingBox {
  var get: () -> ToolSessionState
  var set: (ToolSessionState) -> Void
}

struct ToolRunRequest: Equatable {
  let id = UUID()
  let toolID: ToolID
}
