import AppKit
import SwiftUI
import WorkbenchLabsCore

struct ImageMetadataInspectorView: View {
  @EnvironmentObject private var store: WorkbenchStore
  @State private var imageURLs: [URL] = []
  @State private var operation = "inspect"
  @State private var removeGPS = true
  @State private var removeCameraMetadata = false
  @State private var removeDescriptiveMetadata = false
  @State private var removeAllMetadata = false
  @State private var outputDirectoryURL: URL?
  @State private var output = ""
  @State private var errorMessage: String?
  @State private var outputURLs: [URL] = []
  @State private var isRunning = false

  private let runner = ToolRunner()

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      HSplitView {
        controlsPane
          .frame(minWidth: 400, idealWidth: 500)
          .workbenchPaneBackground()
        outputPane
          .frame(minWidth: 420)
          .workbenchPaneBackground()
      }
    }
    .onAppear(perform: restoreSession)
  }

  private var header: some View {
    ToolWorkspaceHeader(
      title: "Image Metadata Inspector",
      subtitle: "Inspect image metadata and remove GPS location data before sharing.",
      systemImage: "location.slash"
    ) {
      if isRunning {
        ProgressView()
          .controlSize(.small)
      }
      Button {
        run()
      } label: {
        Label(operation == "scrub" ? "Scrub" : "Inspect", systemImage: "play.fill")
      }
      .buttonStyle(.borderedProminent)
      .keyboardShortcut(.return, modifiers: [.command])
      .disabled(imageURLs.isEmpty || isRunning)
    }
  }

  private var controlsPane: some View {
    VStack(alignment: .leading, spacing: 16) {
      sourceSection
      Divider()
      operationSection
      if operation == "scrub" {
        Divider()
        scrubSection
      }
      Spacer(minLength: 0)
    }
    .padding()
  }

  private var sourceSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Images")
          .font(.headline)
        Spacer()
        Button {
          chooseImages()
        } label: {
          Label("Add", systemImage: "plus")
        }
        Button {
          imageURLs.removeAll()
          outputURLs.removeAll()
          output = ""
          errorMessage = nil
        } label: {
          Label("Clear", systemImage: "xmark")
        }
        .disabled(imageURLs.isEmpty)
      }

      if imageURLs.isEmpty {
        ContentUnavailableView(
          "No image selected",
          systemImage: "photo.badge.plus",
          description: Text("Choose images to inspect EXIF, GPS, camera, and color metadata.")
        )
        .frame(maxWidth: .infinity, minHeight: 180)
      } else {
        List {
          ForEach(imageURLs, id: \.path) { url in
            VStack(alignment: .leading, spacing: 2) {
              Text(url.lastPathComponent)
                .font(.body.weight(.medium))
              Text(url.deletingLastPathComponent().path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
          .onDelete { indexes in
            imageURLs.remove(atOffsets: indexes)
          }
        }
        .frame(minHeight: 180)
      }
    }
  }

  private var operationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Operation")
        .font(.headline)

      Picker("Operation", selection: $operation) {
        Text("Inspect").tag("inspect")
        Text("Scrub").tag("scrub")
      }
      .pickerStyle(.segmented)
      .labelsHidden()
    }
  }

  private var scrubSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Scrub Options")
        .font(.headline)

      Toggle("Remove GPS location", isOn: $removeGPS)
        .disabled(removeAllMetadata)
      Toggle("Remove camera metadata", isOn: $removeCameraMetadata)
        .disabled(removeAllMetadata)
      Toggle("Remove descriptive metadata", isOn: $removeDescriptiveMetadata)
        .disabled(removeAllMetadata)
      Toggle("Remove all metadata", isOn: $removeAllMetadata)

      HStack {
        Text(outputDirectoryURL?.path ?? "Output beside each source image")
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer()
        Button {
          chooseOutputFolder()
        } label: {
          Label("Choose", systemImage: "folder")
        }
        if outputDirectoryURL != nil {
          Button {
            outputDirectoryURL = nil
          } label: {
            Label("Use Source Folders", systemImage: "arrow.uturn.backward")
          }
        }
      }
    }
  }

  private var outputPane: some View {
    VStack(spacing: 0) {
      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding()
        Divider()
      }

      CodeEditorView(
        title: "Result",
        placeholder: "Choose images and inspect metadata, or scrub location data.",
        text: .constant(output),
        isReadOnly: true
      )
      .padding()

      HStack {
        Button {
          copyOutput()
        } label: {
          Label("Copy", systemImage: "doc.on.doc")
        }
        .disabled(output.isEmpty)

        Button {
          FileResultActions.copyPaths(outputURLs)
        } label: {
          Label("Copy Paths", systemImage: "link")
        }
        .disabled(outputURLs.isEmpty)

        Button {
          FileResultActions.reveal(outputURLs)
        } label: {
          Label("Reveal Files", systemImage: "finder")
        }
        .disabled(outputURLs.isEmpty)

        Spacer()
      }
      .padding([.horizontal, .bottom])
    }
  }

  private func restoreSession() {
    let session = store.sessions[.imageMetadataInspector] ?? ToolSessionState(definition: ToolRegistry.definition(for: .imageMetadataInspector))
    imageURLs = session.input
      .split(whereSeparator: \.isNewline)
      .map { URL(fileURLWithPath: String($0)) }
      .filter { FileManager.default.fileExists(atPath: $0.path) }
    operation = session.options.operation.isEmpty ? "inspect" : session.options.operation
    removeGPS = session.options.boolValues["removeGPS"] ?? true
    removeCameraMetadata = session.options.boolValues["removeCameraMetadata"] ?? false
    removeDescriptiveMetadata = session.options.boolValues["removeDescriptiveMetadata"] ?? false
    removeAllMetadata = session.options.boolValues["removeAllMetadata"] ?? false
    if let folder = session.options.textValues["outputDirectory"], !folder.isEmpty {
      outputDirectoryURL = URL(fileURLWithPath: NSString(string: folder).expandingTildeInPath)
    }
    output = session.output
    errorMessage = session.errorMessage
    outputURLs = FileResultMetadata.existingGeneratedFileURLs(from: session.metadata, outputFallback: session.output)
  }

  private func chooseImages() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    if panel.runModal() == .OK {
      imageURLs = panel.urls
      outputURLs.removeAll()
      output = ""
      errorMessage = nil
    }
  }

  private func chooseOutputFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.allowsMultipleSelection = false
    if panel.runModal() == .OK {
      outputDirectoryURL = panel.url
    }
  }

  private func run() {
    guard !imageURLs.isEmpty else { return }
    var options = ToolRegistry.definition(for: .imageMetadataInspector).defaultOptions
    options.operation = operation
    options.boolValues["removeGPS"] = removeGPS
    options.boolValues["removeCameraMetadata"] = removeCameraMetadata
    options.boolValues["removeDescriptiveMetadata"] = removeDescriptiveMetadata
    options.boolValues["removeAllMetadata"] = removeAllMetadata
    if let outputDirectoryURL {
      options.textValues["outputDirectory"] = outputDirectoryURL.path
    }

    let input = imageURLs.map(\.path).joined(separator: "\n")
    isRunning = true
    errorMessage = nil
    outputURLs.removeAll()

    Task {
      do {
        let result = try await runner.run(toolID: .imageMetadataInspector, input: input, options: options)
        await MainActor.run {
          apply(result: result, input: input, options: options)
        }
      } catch {
        await MainActor.run {
          apply(error: error, input: input, options: options)
        }
      }
    }
  }

  private func apply(result: ToolResult, input: String, options: ToolOptions) {
    isRunning = false
    output = result.output
    errorMessage = nil
    outputURLs = FileResultMetadata.existingGeneratedFileURLs(from: result.metadata, outputFallback: result.output)
    var session = ToolSessionState(definition: ToolRegistry.definition(for: .imageMetadataInspector))
    session.input = input
    session.options = options
    session.output = result.output
    session.metadata = result.metadata
    session.diagnostics = result.diagnostics
    store.sessions[.imageMetadataInspector] = session
  }

  private func apply(error: Error, input: String, options: ToolOptions) {
    isRunning = false
    output = ""
    outputURLs.removeAll()
    errorMessage = error.localizedDescription
    var session = ToolSessionState(definition: ToolRegistry.definition(for: .imageMetadataInspector))
    session.input = input
    session.options = options
    session.errorMessage = error.localizedDescription
    store.sessions[.imageMetadataInspector] = session
  }

  private func copyOutput() {
    guard !output.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(output, forType: .string)
  }
}
