import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WorkbenchLabsCore

struct ImageConverterView: View {
  @EnvironmentObject private var store: WorkbenchStore
  @State private var imageURL: URL?
  @State private var operation = "inspect"
  @State private var outputFormat = "png"
  @State private var quality = 90
  @State private var outputURL: URL?
  @State private var output = ""
  @State private var errorMessage: String?
  @State private var generatedURL: URL?
  @State private var isRunning = false

  private let runner = ToolRunner()

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      HSplitView {
        controlsPane
          .frame(minWidth: 380, idealWidth: 460)
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
      title: "Image Converter",
      subtitle: "Inspect and convert image files locally with explicit save locations.",
      systemImage: "photo"
    ) {
      if isRunning {
        ProgressView()
          .controlSize(.small)
      }
      Button {
        run()
      } label: {
        Label(operation == "convert" ? "Convert" : "Inspect", systemImage: "play.fill")
      }
      .buttonStyle(.borderedProminent)
      .keyboardShortcut(.return, modifiers: [.command])
      .disabled(imageURL == nil || isRunning)
    }
  }

  private var controlsPane: some View {
    VStack(alignment: .leading, spacing: 16) {
      sourceSection
      Divider()
      operationSection
      if operation == "convert" {
        Divider()
        outputSection
      }
      Spacer(minLength: 0)
    }
    .padding()
  }

  private var sourceSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Source Image")
          .font(.headline)
        Spacer()
        Button {
          chooseImage()
        } label: {
          Label(imageURL == nil ? "Choose" : "Change", systemImage: "photo")
        }
        if imageURL != nil {
          Button {
            imageURL = nil
            output = ""
            generatedURL = nil
          } label: {
            Label("Clear", systemImage: "xmark")
          }
        }
      }

      if let imageURL {
        VStack(alignment: .leading, spacing: 10) {
          if let image = NSImage(contentsOf: imageURL) {
            Image(nsImage: image)
              .resizable()
              .scaledToFit()
              .frame(maxWidth: .infinity, maxHeight: 220)
              .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
          }
          Text(imageURL.lastPathComponent)
            .font(.body.weight(.medium))
          Text(imageURL.deletingLastPathComponent().path)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      } else {
        ContentUnavailableView(
          "No image selected",
          systemImage: "photo.badge.plus",
          description: Text("Choose a PNG, JPEG, HEIC, TIFF, or GIF to inspect or convert.")
        )
        .frame(maxWidth: .infinity, minHeight: 220)
      }
    }
  }

  private var operationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Operation")
        .font(.headline)

      Picker("Operation", selection: $operation) {
        Text("Inspect").tag("inspect")
        Text("Convert").tag("convert")
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      if operation == "convert" {
        Picker("Format", selection: $outputFormat) {
          Text("PNG").tag("png")
          Text("JPEG").tag("jpeg")
          Text("HEIC").tag("heic")
          Text("TIFF").tag("tiff")
          Text("GIF").tag("gif")
        }
        .pickerStyle(.segmented)

        HStack {
          Text("Quality")
            .foregroundStyle(.secondary)
          Slider(value: Binding(
            get: { Double(quality) },
            set: { quality = Int($0.rounded()) }
          ), in: 1...100, step: 1)
          Text("\(quality)")
            .monospacedDigit()
            .frame(width: 34, alignment: .trailing)
        }
        .disabled(!["jpeg", "heic"].contains(outputFormat))
      }
    }
  }

  private var outputSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Output File")
        .font(.headline)

      HStack {
        Text(outputURL?.path ?? suggestedOutputURL?.path ?? "Choose where to save the converted image")
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer()
        Button {
          chooseOutput()
        } label: {
          Label("Choose", systemImage: "square.and.arrow.down")
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
        placeholder: "Choose an image and run an operation.",
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
          if let generatedURL {
            FileResultActions.copyPaths([generatedURL])
          }
        } label: {
          Label("Copy Path", systemImage: "link")
        }
        .disabled(generatedURL == nil)

        Button {
          if let generatedURL {
            FileResultActions.reveal([generatedURL])
          }
        } label: {
          Label("Reveal File", systemImage: "finder")
        }
        .disabled(generatedURL == nil)

        Spacer()
      }
      .padding([.horizontal, .bottom])
    }
  }

  private var suggestedOutputURL: URL? {
    guard let imageURL else { return nil }
    return imageURL
      .deletingPathExtension()
      .appendingPathExtension(outputFormat == "jpeg" ? "jpg" : outputFormat)
  }

  private func restoreSession() {
    let session = store.sessions[.imageConverter] ?? ToolSessionState(definition: ToolRegistry.definition(for: .imageConverter))
    if let firstPath = session.input.split(whereSeparator: \.isNewline).first {
      let url = URL(fileURLWithPath: String(firstPath))
      if FileManager.default.fileExists(atPath: url.path) {
        imageURL = url
      }
    }
    operation = session.options.operation.isEmpty ? "inspect" : session.options.operation
    outputFormat = session.options.textValues["outputFormat"] ?? "png"
    quality = session.options.intValues["quality"] ?? 90
    if let path = session.options.textValues["outputPath"], !path.isEmpty {
      outputURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }
    output = session.output
    errorMessage = session.errorMessage
    generatedURL = FileResultMetadata.existingGeneratedFileURLs(from: session.metadata, outputFallback: session.output).first
  }

  private func chooseImage() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    if panel.runModal() == .OK {
      imageURL = panel.url
      outputURL = nil
      output = ""
      generatedURL = nil
      errorMessage = nil
    }
  }

  private func chooseOutput() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [contentType(for: outputFormat)]
    panel.nameFieldStringValue = suggestedOutputURL?.lastPathComponent ?? "converted.\(outputFormat)"
    if panel.runModal() == .OK {
      outputURL = panel.url
    }
  }

  private func run() {
    guard let imageURL else { return }
    if operation == "convert", outputURL == nil {
      chooseOutput()
    }
    guard operation != "convert" || outputURL != nil else { return }

    var options = ToolRegistry.definition(for: .imageConverter).defaultOptions
    options.operation = operation
    options.textValues["outputFormat"] = outputFormat
    options.intValues["quality"] = quality
    if let outputURL {
      options.textValues["outputPath"] = outputURL.path
    }

    let input = imageURL.path
    isRunning = true
    errorMessage = nil
    generatedURL = nil

    Task {
      do {
        let result = try await runner.run(toolID: .imageConverter, input: input, options: options)
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
    generatedURL = FileResultMetadata.existingGeneratedFileURLs(from: result.metadata, outputFallback: result.output).first
    var session = ToolSessionState(definition: ToolRegistry.definition(for: .imageConverter))
    session.input = input
    session.options = options
    session.output = result.output
    session.metadata = result.metadata
    session.diagnostics = result.diagnostics
    store.sessions[.imageConverter] = session
  }

  private func apply(error: Error, input: String, options: ToolOptions) {
    isRunning = false
    output = ""
    generatedURL = nil
    errorMessage = error.localizedDescription
    var session = ToolSessionState(definition: ToolRegistry.definition(for: .imageConverter))
    session.input = input
    session.options = options
    session.errorMessage = error.localizedDescription
    store.sessions[.imageConverter] = session
  }

  private func contentType(for format: String) -> UTType {
    switch format {
    case "jpeg": .jpeg
    case "heic": .heic
    case "tiff": .tiff
    case "gif": .gif
    default: .png
    }
  }

  private func copyOutput() {
    guard !output.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(output, forType: .string)
  }
}
