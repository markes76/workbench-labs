import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WorkbenchLabsCore

struct Base64StringEncodeDecodeView: View {
  @EnvironmentObject private var store: WorkbenchStore
  @AppStorage("base64.autoDetectUTF8") private var autoDetectUTF8 = true
  @AppStorage("base64.stripDataURLPrefix") private var stripDataURLPrefix = true
  @AppStorage("base64.removeTrailingNullByte") private var removeTrailingNullByte = true
  @AppStorage("base64.urlSafe") private var urlSafe = false

  @State private var input = ""
  @State private var output = ""
  @State private var operation = "encode"
  @State private var errorMessage: String?
  @State private var metadata: [String: String] = [:]
  @State private var showSettings = false
  @State private var isInputDropTargeted = false
  @State private var runTask: Task<Void, Never>?

  private let runner = ToolRunner()

  var body: some View {
    VStack(spacing: 0) {
      titleBar
      Divider()
      inputHeader
      inputEditor
      Divider()
      outputHeader
      outputEditor
    }
    .workbenchPaneBackground()
    .onAppear {
      let session = store.selectedSession
      input = session.input
      output = session.output
      errorMessage = session.errorMessage
      operation = session.options.operation.isEmpty ? "encode" : session.options.operation
      if output.isEmpty, !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        scheduleRun()
      }
      if store.runRequest?.toolID == .base64Codec {
        runNow()
      }
    }
    .onChange(of: input) { _, _ in
      store.setInput(input, for: .base64Codec)
      scheduleRun()
    }
    .onChange(of: operation) { _, _ in scheduleRun() }
    .onChange(of: autoDetectUTF8) { _, _ in scheduleRun() }
    .onChange(of: stripDataURLPrefix) { _, _ in scheduleRun() }
    .onChange(of: removeTrailingNullByte) { _, _ in scheduleRun() }
    .onChange(of: urlSafe) { _, _ in scheduleRun() }
    .onChange(of: store.runRequest) { _, request in
      guard request?.toolID == .base64Codec else { return }
      runNow()
    }
  }

  private var titleBar: some View {
    ToolWorkspaceHeader(
      title: "Base64 String Encode/Decode",
      subtitle: "Encode, decode, auto-detect UTF-8 payloads, and clean transport wrappers.",
      systemImage: "lock.open"
    ) {
      WorkbenchStatusPill(operation == "decode" ? "Decode" : "Encode", systemImage: "arrow.left.arrow.right")
    }
  }

  private var inputHeader: some View {
    HStack(spacing: 10) {
      Text("Input:")
        .font(.headline)

      Button {
        runNow()
      } label: {
        Image(systemName: "bolt.fill")
      }
      .help("Encode / Decode")

      Button("Clipboard") {
        if let text = NSPasteboard.general.string(forType: .string) {
          applyDetectedOperation(for: text)
          input = text
          runNow()
        }
      }

      Button {
        openInputFile()
      } label: {
        Label("Open", systemImage: "folder")
      }
      .help("Open text file")

      Button("Sample") {
        input = operation == "decode" ? "V29ya2JlbmNoTGFicw==" : "WorkbenchLabs"
        runNow()
      }

      Button("Clear") {
        input = ""
        output = ""
        errorMessage = nil
        metadata = [:]
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
      .help("Base64 settings")

      Spacer()

      Picker("", selection: $operation) {
        Text("Encode").tag("encode")
        Text("Decode").tag("decode")
      }
      .pickerStyle(.radioGroup)
      .horizontalRadioGroupLayout()
      .labelsHidden()
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 10)
    .background(.bar)
  }

  private var inputEditor: some View {
    CodeEditorView(
      title: "Input",
      placeholder: "Paste or type text to encode/decode.\nDrop a text file here or use Open.",
      text: $input,
      isReadOnly: false,
      showsHeader: false
    )
    .frame(minHeight: 260)
    .overlay {
      if isInputDropTargeted {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(Color.accentColor, lineWidth: 2)
          .padding(3)
      }
    }
    .onDrop(of: [.fileURL, .plainText], isTargeted: $isInputDropTargeted) { providers in
      handleInputDrop(providers)
    }
    .padding(12)
  }

  private var outputHeader: some View {
    HStack(spacing: 10) {
      Text("Output:")
        .font(.headline)

      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
          .lineLimit(1)
      } else if !metadataText.isEmpty {
        Text(metadataText)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      Button {
        saveOutputToFile()
      } label: {
        Label("Save", systemImage: "square.and.arrow.down")
      }
      .disabled(output.isEmpty)

      Button {
        copy(output)
      } label: {
        Label("Copy", systemImage: "doc.on.doc")
      }
      .disabled(output.isEmpty)

      Button {
        useOutputAsInput()
      } label: {
        Label("Use as input", systemImage: "arrow.turn.up.left")
      }
      .disabled(output.isEmpty)
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 10)
    .background(.bar)
  }

  private var outputEditor: some View {
    CodeEditorView(
      title: "Output",
      placeholder: "Encoded or decoded text appears here.",
      text: .constant(output),
      isReadOnly: true,
      showsHeader: false
    )
    .frame(minHeight: 170)
    .padding(12)
  }

  private var settingsPopover: some View {
    VStack(alignment: .leading, spacing: 14) {
      Toggle("Auto select Decode when clipboard input is Base64 and decodeable to UTF8", isOn: $autoDetectUTF8)
      Toggle("Auto remove \"data:...;base64,\" from the input when decoding", isOn: $stripDataURLPrefix)
      Toggle("Auto remove null byte (\"\\0\") at the end of decoded string", isOn: $removeTrailingNullByte)
      Toggle("Use URL-safe alphabet when encoding", isOn: $urlSafe)

      Button("Restore to Defaults") {
        autoDetectUTF8 = true
        stripDataURLPrefix = true
        removeTrailingNullByte = true
        urlSafe = false
        scheduleRun()
      }
      .padding(.top, 8)
    }
    .toggleStyle(.checkbox)
    .padding(22)
    .frame(width: 560, alignment: .leading)
  }

  private var metadataText: String {
    let labels: [String] = [
      metadata["autoDetected"] == "true" ? "auto-detected decode" : nil,
      metadata["strippedDataURLPrefix"] == "true" ? "removed data URL prefix" : nil,
      metadata["removedTrailingNullByte"] == "true" ? "removed trailing null byte" : nil
    ].compactMap { $0 }
    return labels.joined(separator: "  ")
  }

  private var base64Options: ToolOptions {
    var options = ToolRegistry.definition(for: .base64Codec).defaultOptions
    options.operation = operation
    options.boolValues["autoDetectUTF8"] = autoDetectUTF8
    options.boolValues["stripDataURLPrefix"] = stripDataURLPrefix
    options.boolValues["removeTrailingNullByte"] = removeTrailingNullByte
    options.boolValues["urlSafe"] = urlSafe
    return options
  }

  private func scheduleRun() {
    runTask?.cancel()
    runTask = Task {
      try? await Task.sleep(nanoseconds: 250_000_000)
      guard !Task.isCancelled else { return }
      await runBase64()
    }
  }

  private func runNow() {
    runTask?.cancel()
    Task { await runBase64() }
  }

  @MainActor
  private func runBase64() async {
    guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      output = ""
      errorMessage = nil
      metadata = [:]
      updateStoreOutput()
      return
    }

    do {
      let result = try await runner.run(toolID: .base64Codec, input: input, options: base64Options)
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

  private func updateStoreOutput() {
    var session = store.sessions[.base64Codec] ?? ToolSessionState(definition: ToolRegistry.definition(for: .base64Codec))
    session.input = input
    session.output = output
    session.errorMessage = errorMessage
    session.metadata = metadata
    session.options = base64Options
    store.sessions[.base64Codec] = session
  }

  private func useOutputAsInput() {
    guard !output.isEmpty else { return }
    if let nextOperation = ToolOperationBehavior.inverseOperation(for: .base64Codec, currentOperation: operation) {
      operation = nextOperation
    }
    input = output
  }

  private func openInputFile() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    if panel.runModal() == .OK, let url = panel.url {
      loadInputFile(url)
    }
  }

  private func saveOutputToFile() {
    guard !output.isEmpty else { return }
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.plainText]
    panel.nameFieldStringValue = operation == "decode" ? "base64-decoded.txt" : "base64-encoded.txt"
    if panel.runModal() == .OK, let url = panel.url {
      do {
        try output.write(to: url, atomically: true, encoding: .utf8)
      } catch {
        errorMessage = "Could not save file: \(error.localizedDescription)"
        updateStoreOutput()
      }
    }
  }

  private func handleInputDrop(_ providers: [NSItemProvider]) -> Bool {
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
          let url: URL?
          if let droppedURL = item as? URL {
            url = droppedURL
          } else if let data = item as? Data {
            url = URL(dataRepresentation: data, relativeTo: nil)
          } else {
            url = nil
          }

          guard let url else { return }
          Task { @MainActor in loadInputFile(url) }
        }
        return true
      }

      if provider.canLoadObject(ofClass: NSString.self) {
        _ = provider.loadObject(ofClass: NSString.self) { text, _ in
          guard let text = text as? String else { return }
          Task { @MainActor in loadInputText(text) }
        }
        return true
      }
    }
    return false
  }

  private func loadInputFile(_ url: URL) {
    do {
      let text = try String(contentsOf: url, encoding: .utf8)
      loadInputText(text)
    } catch {
      errorMessage = "Could not load file: \(error.localizedDescription)"
      updateStoreOutput()
    }
  }

  private func loadInputText(_ text: String) {
    errorMessage = nil
    applyDetectedOperation(for: text)
    input = text
    runNow()
  }

  private func applyDetectedOperation(for text: String) {
    if autoDetectUTF8, Base64InputDetector.isDecodableUTF8(text, stripDataURLPrefix: stripDataURLPrefix) {
      operation = "decode"
    }
  }

  private func copy(_ value: String) {
    guard !value.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
  }
}
