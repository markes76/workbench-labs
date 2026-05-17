import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WorkbenchLabsCore

struct BatchImageResizerView: View {
  @EnvironmentObject private var store: WorkbenchStore
  @State private var imageURLs: [URL] = []
  @State private var resizeMode = "max"
  @State private var outputFormat = "jpeg"
  @State private var width = 1024
  @State private var height = 1024
  @State private var maxDimension = 1600
  @State private var scalePercent = 50
  @State private var quality = 82
  @State private var stripMetadata = true
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
      title: "Batch Image Resizer & Compressor",
      subtitle: "Resize, compress, and strip metadata from multiple images locally.",
      systemImage: "rectangle.resize"
    ) {
      if isRunning {
        ProgressView()
          .controlSize(.small)
      }
      Button {
        run()
      } label: {
        Label("Process", systemImage: "play.fill")
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
      resizeSection
      Divider()
      outputSection
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
        } label: {
          Label("Clear", systemImage: "xmark")
        }
        .disabled(imageURLs.isEmpty)
      }

      if imageURLs.isEmpty {
        ContentUnavailableView(
          "No images selected",
          systemImage: "photo.badge.plus",
          description: Text("Choose PNG, JPEG, HEIC, TIFF, or other ImageIO-readable files.")
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

  private var resizeSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Resize")
        .font(.headline)

      Picker("Resize", selection: $resizeMode) {
        Text("No resize").tag("none")
        Text("Width").tag("width")
        Text("Height").tag("height")
        Text("Max").tag("max")
        Text("Scale").tag("scale")
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      if resizeMode == "width" {
        labeledStepper("Width", value: $width, range: 1...20000, suffix: "px")
      } else if resizeMode == "height" {
        labeledStepper("Height", value: $height, range: 1...20000, suffix: "px")
      } else if resizeMode == "max" {
        labeledStepper("Max dimension", value: $maxDimension, range: 1...20000, suffix: "px")
      } else if resizeMode == "scale" {
        labeledStepper("Scale", value: $scalePercent, range: 1...1000, suffix: "%")
      }
    }
  }

  private var outputSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Output")
        .font(.headline)

      Picker("Format", selection: $outputFormat) {
        Text("Original").tag("original")
        Text("PNG").tag("png")
        Text("JPEG").tag("jpeg")
        Text("HEIC").tag("heic")
        Text("TIFF").tag("tiff")
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

      Toggle("Strip metadata", isOn: $stripMetadata)

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
        placeholder: "Choose images and run the batch processor.",
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

  private func labeledStepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
    HStack {
      Text(label)
        .foregroundStyle(.secondary)
      Stepper(value: value, in: range) {
        Text("\(value.wrappedValue) \(suffix)")
          .monospacedDigit()
      }
    }
  }

  private func restoreSession() {
    let session = store.sessions[.batchImageResizer] ?? ToolSessionState(definition: ToolRegistry.definition(for: .batchImageResizer))
    imageURLs = session.input
      .split(whereSeparator: \.isNewline)
      .map { URL(fileURLWithPath: String($0)) }
      .filter { FileManager.default.fileExists(atPath: $0.path) }
    resizeMode = session.options.textValues["resizeMode"] ?? "max"
    outputFormat = session.options.textValues["outputFormat"] ?? "jpeg"
    width = session.options.intValues["width"] ?? 1024
    height = session.options.intValues["height"] ?? 1024
    maxDimension = session.options.intValues["maxDimension"] ?? 1600
    scalePercent = session.options.intValues["scalePercent"] ?? 50
    quality = session.options.intValues["quality"] ?? 82
    stripMetadata = session.options.boolValues["stripMetadata"] ?? true
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
    var options = ToolRegistry.definition(for: .batchImageResizer).defaultOptions
    options.textValues["resizeMode"] = resizeMode
    options.textValues["outputFormat"] = outputFormat
    options.intValues["width"] = width
    options.intValues["height"] = height
    options.intValues["maxDimension"] = maxDimension
    options.intValues["scalePercent"] = scalePercent
    options.intValues["quality"] = quality
    options.boolValues["stripMetadata"] = stripMetadata
    if let outputDirectoryURL {
      options.textValues["outputDirectory"] = outputDirectoryURL.path
    }

    let input = imageURLs.map(\.path).joined(separator: "\n")
    isRunning = true
    errorMessage = nil
    outputURLs.removeAll()

    Task {
      do {
        let result = try await runner.run(toolID: .batchImageResizer, input: input, options: options)
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
    var session = ToolSessionState(definition: ToolRegistry.definition(for: .batchImageResizer))
    session.input = input
    session.options = options
    session.output = result.output
    session.metadata = result.metadata
    session.diagnostics = result.diagnostics
    store.sessions[.batchImageResizer] = session
  }

  private func apply(error: Error, input: String, options: ToolOptions) {
    isRunning = false
    output = ""
    outputURLs.removeAll()
    errorMessage = error.localizedDescription
    var session = ToolSessionState(definition: ToolRegistry.definition(for: .batchImageResizer))
    session.input = input
    session.options = options
    session.errorMessage = error.localizedDescription
    store.sessions[.batchImageResizer] = session
  }

  private func copyOutput() {
    guard !output.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(output, forType: .string)
  }
}
