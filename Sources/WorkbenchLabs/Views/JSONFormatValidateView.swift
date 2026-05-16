import AppKit
import SwiftUI
import WorkbenchLabsCore

struct JSONFormatValidateView: View {
  @EnvironmentObject private var store: WorkbenchStore
  @AppStorage("json.autoDetect") private var autoDetect = true
  @AppStorage("json.allowJSON5") private var allowJSON5 = false
  @AppStorage("json.autoRepair") private var autoRepair = true
  @AppStorage("json.continuous") private var continuous = true
  @AppStorage("json.sortKeys") private var sortKeys = false
  @AppStorage("json.preserveRaw") private var preserveRaw = false
  @AppStorage("json.outputStyle") private var outputStyle = JSONOutputStyle.twoSpaces.rawValue

  @State private var input = ""
  @State private var output = ""
  @State private var errorMessage: String?
  @State private var metadata: [String: String] = [:]
  @State private var showSettings = false
  @State private var runTask: Task<Void, Never>?

  private let runner = ToolRunner()

  var body: some View {
    VStack(spacing: 0) {
      titleBar
      Divider()
      HSplitView {
        inputPane
          .frame(minWidth: 360, idealWidth: 520)
          .workbenchPaneBackground()
        outputPane
          .frame(minWidth: 420)
          .workbenchPaneBackground()
      }
    }
    .onAppear {
      input = store.selectedSession.input
      output = store.selectedSession.output
      errorMessage = store.selectedSession.errorMessage
      if output.isEmpty, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        scheduleRun(force: autoDetect || continuous)
      }
      if store.runRequest?.toolID == .jsonFormatter {
        runNow()
      }
    }
    .onChange(of: input) { _, _ in
      store.setInput(input, for: .jsonFormatter)
      scheduleRun(force: continuous || (autoDetect && isStrictJSON(input)))
    }
    .onChange(of: outputStyle) { _, _ in scheduleRun(force: true) }
    .onChange(of: allowJSON5) { _, _ in scheduleRun(force: true) }
    .onChange(of: autoRepair) { _, value in
      if value { preserveRaw = false }
      scheduleRun(force: true)
    }
    .onChange(of: sortKeys) { _, value in
      if value { preserveRaw = false }
      scheduleRun(force: true)
    }
    .onChange(of: preserveRaw) { _, _ in scheduleRun(force: true) }
    .onChange(of: store.runRequest) { _, request in
      guard request?.toolID == .jsonFormatter else { return }
      runNow()
    }
  }

  private var titleBar: some View {
    ToolWorkspaceHeader(
      title: "JSON Formatter & Validator",
      subtitle: "Validate, format, repair, minify, and normalize JSON without leaving the app.",
      systemImage: "curlybraces.square"
    ) {
      WorkbenchStatusPill(continuous ? "Continuous" : "Manual", systemImage: continuous ? "bolt.fill" : "pause")
    }
  }

  private var inputPane: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Text("Input:")
          .font(.headline)

        Button {
          runNow()
        } label: {
          Image(systemName: "bolt.fill")
        }
        .help("Format / Validate")

        Button("Clipboard") {
          if let text = NSPasteboard.general.string(forType: .string) {
            input = text
            runNow()
          }
        }

        Button("Sample") {
          input = sampleJSON
          runNow()
        }

        Button("Clear") {
          input = ""
          output = ""
          errorMessage = nil
          metadata = [:]
          store.setInput("", for: .jsonFormatter)
          updateStoreOutput()
        }

        Button {
          showSettings.toggle()
        } label: {
          Image(systemName: "gearshape.fill")
        }
        .popover(isPresented: $showSettings, arrowEdge: .bottom) {
          settingsPopover
        }
        .help("JSON settings")

        Picker("", selection: .constant("json")) {
          Text("JSON").tag("json")
        }
        .labelsHidden()
        .frame(width: 145)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(.bar)

      CodeEditorView(
        title: "Input",
        placeholder: "Paste JSON, JSON5, or malformed JSON to validate and format.",
        text: $input,
        isReadOnly: false,
        showsHeader: false
      )
        .padding(12)
    }
  }

  private var outputPane: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Output:")
          .font(.headline)

        if let errorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .lineLimit(1)
        } else if !metadata.isEmpty {
          Text(metadataText)
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Picker("", selection: $outputStyle) {
          ForEach(JSONOutputStyle.allCases) { style in
            Text(style.title).tag(style.rawValue)
          }
        }
        .labelsHidden()
        .frame(width: 130)

        Button {
          copy(output)
        } label: {
          Label("Copy", systemImage: "doc.on.doc")
        }
        .disabled(output.isEmpty)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(.bar)

      CodeEditorView(
        title: "Output",
        placeholder: "Formatted JSON output",
        text: .constant(output),
        isReadOnly: true,
        showsHeader: false
      )
        .padding(12)
    }
  }

  private var settingsPopover: some View {
    VStack(alignment: .leading, spacing: 14) {
      Toggle("Auto detect when input is a valid JSON", isOn: $autoDetect)
      Toggle("Allow trailing commas and comments in JSON", isOn: $allowJSON5)
      VStack(alignment: .leading, spacing: 3) {
        Toggle("Auto repair invalid JSON if possible", isOn: $autoRepair)
        Text("Fix missing quotes, replace Python constants, strip trailing commas, etc.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.leading, 24)
      }
      Toggle("Continuous Mode: format the input continuously as you type", isOn: $continuous)
      Toggle("Sort keys in output", isOn: $sortKeys)
      VStack(alignment: .leading, spacing: 3) {
        Toggle("Preserves encoded strings (like \"\\u00e2\") and big numbers", isOn: $preserveRaw)
          .disabled(autoRepair || sortKeys)
        Text("Only works when \"Sort keys\" and \"Auto repair\" options are off.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.leading, 24)
      }
      Button("Reset to Defaults") {
        resetDefaults()
      }
    }
    .toggleStyle(.checkbox)
    .padding(22)
    .frame(width: 560, alignment: .leading)
  }

  private var metadataText: String {
    let pairs = metadata
      .filter { $0.value == "true" || $0.key == "parser" }
      .map { "\($0.key): \($0.value)" }
      .sorted()
    return pairs.joined(separator: "  ")
  }

  private func scheduleRun(force: Bool) {
    guard force else { return }
    runTask?.cancel()
    runTask = Task {
      try? await Task.sleep(nanoseconds: 250_000_000)
      guard !Task.isCancelled else { return }
      await runJSON()
    }
  }

  private func runNow() {
    runTask?.cancel()
    Task { await runJSON() }
  }

  @MainActor
  private func runJSON() async {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      output = ""
      errorMessage = nil
      metadata = [:]
      updateStoreOutput()
      return
    }

    do {
      let result = try await runner.run(toolID: .jsonFormatter, input: input, options: jsonOptions)
      output = result.output
      metadata = result.metadata
      errorMessage = nil
    } catch {
      output = ""
      metadata = [:]
      errorMessage = error.localizedDescription
    }
    updateStoreOutput()
  }

  private var jsonOptions: ToolOptions {
    var options = ToolRegistry.definition(for: .jsonFormatter).defaultOptions
    let style = JSONOutputStyle(rawValue: outputStyle) ?? .twoSpaces
    options.operation = style == .minified ? "minify" : "format"
    options.intValues["indent"] = style.spaces
    options.textValues["indentStyle"] = style.indentStyle
    options.boolValues["autoDetect"] = autoDetect
    options.boolValues["allowJSON5"] = allowJSON5
    options.boolValues["autoRepair"] = autoRepair
    options.boolValues["continuous"] = continuous
    options.boolValues["sortKeys"] = sortKeys
    options.boolValues["preserveRaw"] = preserveRaw
    options.textValues["inputMode"] = "json"
    return options
  }

  private func updateStoreOutput() {
    var session = store.sessions[.jsonFormatter] ?? ToolSessionState(definition: ToolRegistry.definition(for: .jsonFormatter))
    session.input = input
    session.output = output
    session.errorMessage = errorMessage
    session.metadata = metadata
    session.options = jsonOptions
    store.sessions[.jsonFormatter] = session
  }

  private func resetDefaults() {
    autoDetect = true
    allowJSON5 = false
    autoRepair = true
    continuous = true
    sortKeys = false
    preserveRaw = false
    outputStyle = JSONOutputStyle.twoSpaces.rawValue
    scheduleRun(force: true)
  }

  private func isStrictJSON(_ value: String) -> Bool {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    return (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) != nil
  }

  private func copy(_ value: String) {
    guard !value.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
  }

  private var sampleJSON: String {
    """
    {"store":{"book":[{"category":"reference","author":"Nigel Rees","title":"Sayings of the Century","price":8.95},{"category":"fiction","author":"Evelyn Waugh","title":"Sword of Honour","price":12.99},{"category":"fiction","author":"J. R. R. Tolkien","title":"The Lord of the Rings","isbn":"0-395-19395-8","price":22.99}],"bicycle":{"color":"red","price":19.95}}}
    """
  }
}

private enum JSONOutputStyle: String, CaseIterable, Identifiable {
  case twoSpaces
  case fourSpaces
  case oneTab
  case minified

  var id: String { rawValue }

  var title: String {
    switch self {
    case .twoSpaces: "2 spaces"
    case .fourSpaces: "4 spaces"
    case .oneTab: "1 tab"
    case .minified: "Minified"
    }
  }

  var spaces: Int {
    switch self {
    case .fourSpaces: 4
    default: 2
    }
  }

  var indentStyle: String {
    switch self {
    case .fourSpaces: "4spaces"
    case .oneTab: "tab"
    default: "2spaces"
    }
  }
}
