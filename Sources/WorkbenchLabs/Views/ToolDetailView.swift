import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WorkbenchLabsCore

struct ToolDetailView: View {
  @EnvironmentObject private var store: WorkbenchStore
  @AppStorage("editor.runOnInputChange") private var runOnInputChange = false
  let definition: ToolDefinition
  @State private var isDropTargeted = false
  @State private var autoRunTask: Task<Void, Never>?

  private var session: Binding<ToolSessionState> {
    Binding(
      get: { store.selectedSession },
      set: { store.sessions[definition.id] = $0 }
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      optionsBar
      HSplitView {
        inputPane
          .frame(minWidth: 360, idealWidth: 520)
          .workbenchPaneBackground()
        outputPane
          .frame(minWidth: 360)
          .workbenchPaneBackground()
      }
    }
  }

  @ViewBuilder
  private var optionsBar: some View {
    if !definition.options.isEmpty {
      ToolOptionsView(definition: definition, session: session, onChange: scheduleAutoRun)
      Divider()
    }
  }

  private var header: some View {
    ToolWorkspaceHeader(
      title: definition.title,
      subtitle: definition.subtitle,
      systemImage: definition.systemImage
    ) {
      if store.isRunning {
        ProgressView()
          .controlSize(.small)
      }
      Button {
        store.runSelectedTool()
      } label: {
        Label(definition.primaryActionTitle, systemImage: "play.fill")
      }
      .keyboardShortcut(.return, modifiers: [.command])
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
    }
  }

  private var inputPane: some View {
    VStack(spacing: 0) {
      VStack(spacing: 10) {
        CodeEditorView(
          title: "Input",
          placeholder: definition.inputPlaceholder,
          text: Binding(
            get: { session.wrappedValue.input },
            set: { value in
              var next = session.wrappedValue
              next.input = value
              session.wrappedValue = next
              scheduleAutoRun()
            }
          )
        )
        .overlay {
          if isDropTargeted {
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.accentColor, lineWidth: 2)
              .padding(6)
          }
        }
        .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
          handleDrop(providers)
        }

        if definition.id == .textDiff {
          CodeEditorView(
            title: "Changed",
            placeholder: "Changed text",
            text: Binding(
              get: { session.wrappedValue.options.secondaryInput },
              set: { value in
                var next = session.wrappedValue
                next.options.secondaryInput = value
                session.wrappedValue = next
                scheduleAutoRun()
              }
            )
          )
        }

        HStack {
          Button {
            openFile()
          } label: {
            Label("Open", systemImage: "folder")
          }
          .help("Open File")

          Button {
            var next = session.wrappedValue
            next.input = definition.sampleInput
            session.wrappedValue = next
          } label: {
            Label("Sample", systemImage: "text.badge.plus")
          }
          .help("Load Sample")

          Button {
            store.inspectClipboard()
          } label: {
            Label("Clipboard", systemImage: "doc.on.clipboard")
          }
          .help("Inspect Clipboard")

          Spacer()

          Button {
            store.useOutputAsInput()
          } label: {
            Label("Use Output", systemImage: "arrow.up.doc")
          }
          .help("Use Output as Input")
        }
      }
      .padding()
    }
  }

  private var outputPane: some View {
    VStack(spacing: 0) {
      diagnostics
      if let html = session.wrappedValue.htmlPreview {
        WebPreviewView(
          html: html,
          allowJavaScriptOverride: htmlPreviewOption("allowJavaScript"),
          allowNavigationOverride: htmlPreviewOption("allowNavigation"),
          allowExternalRequestsOverride: htmlPreviewOption("allowExternalRequests")
        )
          .frame(minHeight: 260)
        Divider()
      }
      if let image = imageOutput {
        VStack(spacing: 12) {
          Image(nsImage: image)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 260)
          HStack {
            Button {
              store.copyImageOutput()
            } label: {
              Label("Copy Image", systemImage: "photo.on.rectangle")
            }
            Button {
              saveImage()
            } label: {
              Label("Save PNG", systemImage: "square.and.arrow.down")
            }
          }
        }
        .padding()
        Divider()
      }
      CodeEditorView(
        title: "Output",
        placeholder: "Output",
        text: .constant(session.wrappedValue.output),
        isReadOnly: true
      )
      .padding()
      HStack {
        Button {
          store.copyOutput()
        } label: {
          Label("Copy", systemImage: "doc.on.doc")
        }
        .disabled(session.wrappedValue.output.isEmpty)

        Button {
          saveOutput()
        } label: {
          Label("Save", systemImage: "square.and.arrow.down")
        }
        .disabled(session.wrappedValue.output.isEmpty)

        Button {
          FileResultActions.copyPaths(generatedFileURLs)
        } label: {
          Label(generatedFileURLs.count == 1 ? "Copy Path" : "Copy Paths", systemImage: "link")
        }
        .disabled(generatedFileURLs.isEmpty)

        Button {
          FileResultActions.reveal(generatedFileURLs)
        } label: {
          Label(generatedFileURLs.count == 1 ? "Reveal File" : "Reveal Files", systemImage: "finder")
        }
        .disabled(generatedFileURLs.isEmpty)

        Spacer()
      }
      .padding([.horizontal, .bottom])
    }
  }

  private var diagnostics: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let error = session.wrappedValue.errorMessage {
        Label(error, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
          .lineLimit(3)
      }
      ForEach(session.wrappedValue.diagnostics, id: \.self) { diagnostic in
        Label(diagnostic.message, systemImage: icon(for: diagnostic.severity))
          .foregroundStyle(color(for: diagnostic.severity))
      }
      if !visibleMetadata.isEmpty {
        Text(visibleMetadata.map { "\($0.key): \($0.value)" }.sorted().joined(separator: "  "))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal)
    .padding(.vertical, diagnosticsVisible ? 10 : 0)
  }

  private var diagnosticsVisible: Bool {
    session.wrappedValue.errorMessage != nil ||
    !session.wrappedValue.diagnostics.isEmpty ||
    !visibleMetadata.isEmpty
  }

  private var visibleMetadata: [String: String] {
    session.wrappedValue.metadata.filter { key, _ in
      key != FileResultMetadata.generatedFilePathsKey
    }
  }

  private var generatedFileURLs: [URL] {
    FileResultMetadata.existingGeneratedFileURLs(
      from: session.wrappedValue.metadata,
      outputFallback: session.wrappedValue.output
    )
  }

  private var imageOutput: NSImage? {
    guard let base64 = session.wrappedValue.imagePNGBase64, let data = Data(base64Encoded: base64) else { return nil }
    return NSImage(data: data)
  }

  private func icon(for severity: ToolDiagnostic.Severity) -> String {
    switch severity {
    case .info: "checkmark.circle"
    case .warning: "exclamationmark.triangle"
    case .error: "xmark.octagon"
    }
  }

  private func color(for severity: ToolDiagnostic.Severity) -> Color {
    switch severity {
    case .info: .green
    case .warning: .orange
    case .error: .red
    }
  }

  private func htmlPreviewOption(_ key: String) -> Bool? {
    guard definition.id == .htmlPreview else { return nil }
    return session.wrappedValue.options.boolValues[key] ?? false
  }

  private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
          guard
            let data = item as? Data,
            let url = URL(dataRepresentation: data, relativeTo: nil)
          else { return }
          Task { @MainActor in store.loadFile(url: url) }
        }
        return true
      }
      if provider.canLoadObject(ofClass: NSString.self) {
        _ = provider.loadObject(ofClass: NSString.self) { text, _ in
          guard let text = text as? String else { return }
          Task { @MainActor in store.setInput(text) }
        }
        return true
      }
    }
    return false
  }

  private func scheduleAutoRun() {
    guard runOnInputChange else { return }
    autoRunTask?.cancel()
    autoRunTask = Task {
      try? await Task.sleep(nanoseconds: 450_000_000)
      guard !Task.isCancelled else { return }
      await MainActor.run {
        store.runSelectedTool()
      }
    }
  }

  private func openFile() {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = definition.capabilities.contains(.fileInput)
    panel.canChooseDirectories = false
    if panel.runModal() == .OK {
      store.loadFiles(urls: panel.urls)
    }
  }

  private func saveOutput() {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "\(definition.id.rawValue)-output.txt"
    if panel.runModal() == .OK, let url = panel.url {
      try? store.saveOutput(to: url)
    }
  }

  private func saveImage() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.png]
    panel.nameFieldStringValue = "qr-code.png"
    if panel.runModal() == .OK, let url = panel.url {
      try? store.saveImageOutput(to: url)
    }
  }

}
