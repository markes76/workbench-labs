import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WorkbenchLabsCore

struct VideoConverterView: View {
  @EnvironmentObject private var store: WorkbenchStore
  @State private var videoURL: URL?
  @State private var operation = "info"
  @State private var outputFormat = "mp4"
  @State private var startTime = ""
  @State private var endTime = ""
  @State private var outputURL: URL?
  @State private var output = ""
  @State private var errorMessage: String?
  @State private var generatedURLs: [URL] = []
  @State private var isRunning = false

  private let runner = ToolRunner()

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      HSplitView {
        controlsPane
          .frame(minWidth: 360, idealWidth: 440)
          .workbenchPaneBackground()
        outputPane
          .frame(minWidth: 420)
          .workbenchPaneBackground()
      }
    }
    .onAppear(perform: restoreSession)
    .onChange(of: operation) { _, _ in normalizeFormatForOperation() }
  }

  private var header: some View {
    ToolWorkspaceHeader(
      title: "Video Converter",
      subtitle: "Inspect, trim, transcode, extract audio, and generate thumbnails locally with ffmpeg.",
      systemImage: "film"
    ) {
      if isRunning {
        ProgressView()
          .controlSize(.small)
      }
      Button {
        run()
      } label: {
        Label(primaryActionTitle, systemImage: "play.fill")
      }
      .buttonStyle(.borderedProminent)
      .keyboardShortcut(.return, modifiers: [.command])
      .disabled(videoURL == nil || isRunning)
    }
  }

  private var controlsPane: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        sourceSection
        Divider()
        operationSection
        if operation != "info" {
          Divider()
          trimSection
          Divider()
          outputSection
        }
        Spacer(minLength: 0)
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var sourceSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Source Video")
          .font(.headline)
        Spacer()
        Button {
          chooseVideo()
        } label: {
          Label(videoURL == nil ? "Choose" : "Change", systemImage: "film")
        }
        if videoURL != nil {
          Button {
            videoURL = nil
            outputURL = nil
            output = ""
            generatedURLs.removeAll()
            errorMessage = nil
          } label: {
            Label("Clear", systemImage: "xmark")
          }
        }
      }

      if let videoURL {
        VStack(alignment: .leading, spacing: 4) {
          Text(videoURL.lastPathComponent)
            .font(.body.weight(.medium))
            .lineLimit(2)
          Text(videoURL.deletingLastPathComponent().path)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      } else {
        ContentUnavailableView(
          "No video selected",
          systemImage: "film.badge.plus",
          description: Text("Choose a video file to inspect, trim, transcode, extract audio, or generate a thumbnail.")
        )
        .frame(maxWidth: .infinity, minHeight: 180)
      }
    }
  }

  private var operationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Operation")
        .font(.headline)

      Picker("Operation", selection: $operation) {
        Text("Info").tag("info")
        Text("Convert").tag("convert")
        Text("Audio").tag("extractAudio")
        Text("Thumbnail").tag("thumbnail")
      }
      .pickerStyle(.segmented)
      .labelsHidden()

      if operation != "info" {
        Picker("Format", selection: $outputFormat) {
          ForEach(formatChoices, id: \.self) { format in
            Text(format.uppercased()).tag(format)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
      }
    }
  }

  private var trimSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(operation == "thumbnail" ? "Frame Time" : "Trim")
        .font(.headline)

      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 4) {
          Text(operation == "thumbnail" ? "Time" : "Start")
            .font(.caption)
            .foregroundStyle(.secondary)
          TextField("0 or 00:00:00", text: $startTime)
            .textFieldStyle(.roundedBorder)
        }

        if operation != "thumbnail" {
          VStack(alignment: .leading, spacing: 4) {
            Text("End")
              .font(.caption)
              .foregroundStyle(.secondary)
            TextField("Optional", text: $endTime)
              .textFieldStyle(.roundedBorder)
          }
        }
      }
    }
  }

  private var outputSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Output")
        .font(.headline)

      HStack {
        Text(outputURL?.path ?? suggestedOutputDescription)
          .font(.callout)
          .lineLimit(1)
          .truncationMode(.middle)
        Spacer()
        Button {
          chooseOutput()
        } label: {
          Label("Choose", systemImage: "square.and.arrow.down")
        }
        if outputURL != nil {
          Button {
            outputURL = nil
          } label: {
            Label("Use Source Folder", systemImage: "arrow.uturn.backward")
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
        placeholder: "Choose a video and run an operation.",
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
          FileResultActions.copyPaths(generatedURLs)
        } label: {
          Label(generatedURLs.count == 1 ? "Copy Path" : "Copy Paths", systemImage: "link")
        }
        .disabled(generatedURLs.isEmpty)

        Button {
          FileResultActions.reveal(generatedURLs)
        } label: {
          Label(generatedURLs.count == 1 ? "Reveal File" : "Reveal Files", systemImage: "finder")
        }
        .disabled(generatedURLs.isEmpty)

        Spacer()
      }
      .padding([.horizontal, .bottom])
    }
  }

  private var primaryActionTitle: String {
    switch operation {
    case "convert": "Convert"
    case "extractAudio": "Extract"
    case "thumbnail": "Thumbnail"
    default: "Inspect"
    }
  }

  private var formatChoices: [String] {
    switch operation {
    case "extractAudio": ["mp3", "wav", "aac"]
    case "thumbnail": ["jpg", "png"]
    default: ["mp4", "mov", "webm", "gif"]
    }
  }

  private var suggestedOutputDescription: String {
    guard videoURL != nil else { return "Output beside the source video" }
    return "Output beside the source video"
  }

  private func restoreSession() {
    let session = store.sessions[.videoConverter] ?? ToolSessionState(definition: ToolRegistry.definition(for: .videoConverter))
    if let firstPath = session.input.split(whereSeparator: \.isNewline).first {
      let url = URL(fileURLWithPath: String(firstPath))
      if FileManager.default.fileExists(atPath: url.path) {
        videoURL = url
      }
    }
    operation = session.options.operation.isEmpty ? "info" : session.options.operation
    outputFormat = session.options.textValues["outputFormat"] ?? "mp4"
    startTime = session.options.textValues["startTime"] ?? ""
    endTime = session.options.textValues["endTime"] ?? ""
    if let path = session.options.textValues["outputPath"], !path.isEmpty {
      outputURL = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }
    output = session.output
    errorMessage = session.errorMessage
    generatedURLs = FileResultMetadata.existingGeneratedFileURLs(from: session.metadata, outputFallback: session.output)
    normalizeFormatForOperation()
  }

  private func chooseVideo() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.movie, .video]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    if panel.runModal() == .OK {
      videoURL = panel.url
      outputURL = nil
      output = ""
      generatedURLs.removeAll()
      errorMessage = nil
    }
  }

  private func chooseOutput() {
    let panel = NSSavePanel()
    if let type = UTType(filenameExtension: outputFormat == "jpg" ? "jpeg" : outputFormat) {
      panel.allowedContentTypes = [type]
    }
    panel.nameFieldStringValue = suggestedOutputFilename
    if panel.runModal() == .OK {
      outputURL = panel.url
    }
  }

  private var suggestedOutputFilename: String {
    let base = videoURL?.deletingPathExtension().lastPathComponent ?? "output"
    let suffix = switch operation {
    case "extractAudio": "-audio"
    case "thumbnail": "-thumbnail"
    case "convert" where !startTime.isEmpty || !endTime.isEmpty: "-clip"
    default: ""
    }
    return "\(base)\(suffix).\(outputFormat)"
  }

  private func run() {
    guard let videoURL else { return }
    var options = ToolRegistry.definition(for: .videoConverter).defaultOptions
    options.operation = operation
    options.textValues["outputFormat"] = outputFormat
    options.textValues["startTime"] = startTime
    options.textValues["endTime"] = operation == "thumbnail" ? "" : endTime
    if let outputURL {
      options.textValues["outputPath"] = outputURL.path
    }

    let input = videoURL.path
    isRunning = true
    errorMessage = nil
    generatedURLs.removeAll()

    Task {
      do {
        let result = try await runner.run(toolID: .videoConverter, input: input, options: options)
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
    generatedURLs = FileResultMetadata.existingGeneratedFileURLs(from: result.metadata, outputFallback: result.output)
    var session = ToolSessionState(definition: ToolRegistry.definition(for: .videoConverter))
    session.input = input
    session.options = options
    session.output = result.output
    session.metadata = result.metadata
    session.diagnostics = result.diagnostics
    store.sessions[.videoConverter] = session
  }

  private func apply(error: Error, input: String, options: ToolOptions) {
    isRunning = false
    output = ""
    generatedURLs.removeAll()
    errorMessage = error.localizedDescription
    var session = ToolSessionState(definition: ToolRegistry.definition(for: .videoConverter))
    session.input = input
    session.options = options
    session.errorMessage = error.localizedDescription
    store.sessions[.videoConverter] = session
  }

  private func normalizeFormatForOperation() {
    let choices = formatChoices
    if !choices.contains(outputFormat) {
      outputFormat = choices[0]
      outputURL = nil
    }
  }

  private func copyOutput() {
    guard !output.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(output, forType: .string)
  }
}
