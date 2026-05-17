import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WorkbenchLabsCore

struct PDFToolkitView: View {
  @EnvironmentObject private var store: WorkbenchStore
  @State private var selectedPDFURLs: [URL] = []
  @State private var operation = "inspect"
  @State private var splitMode = "all"
  @State private var selectedPages = "1"
  @State private var rotationDegrees = "90"
  @State private var scrubTitle = true
  @State private var scrubAuthor = true
  @State private var scrubSubject = true
  @State private var scrubCreator = true
  @State private var scrubProducer = true
  @State private var scrubKeywords = true
  @State private var scrubCreationDate = true
  @State private var scrubModificationDate = true
  @State private var outputDirectoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
  @State private var mergeOutputURL: URL?
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
      title: "PDF Toolkit",
      subtitle: "Inspect, scrub metadata, extract text, merge, split, edit, and append PDF pages into real files.",
      systemImage: "doc.richtext"
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
      .disabled(!canRun)
    }
  }

  private var controlsPane: some View {
    VStack(alignment: .leading, spacing: 16) {
      filePickerSection
      Divider()
      operationSection
      Divider()
      outputLocationSection
      Spacer(minLength: 0)
    }
    .padding()
  }

  private var filePickerSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("PDF Files")
          .font(.headline)
        Spacer()
        Button {
          choosePDFs()
        } label: {
          Label("Add", systemImage: "plus")
        }
        Button {
          selectedPDFURLs.removeAll()
          outputURLs.removeAll()
        } label: {
          Label("Clear", systemImage: "xmark")
        }
        .disabled(selectedPDFURLs.isEmpty)
      }

      if selectedPDFURLs.isEmpty {
        ContentUnavailableView(
          "No PDF selected",
          systemImage: "doc.badge.plus",
          description: Text("Choose one PDF for page edits, or multiple PDFs for merge and append.")
        )
        .frame(maxWidth: .infinity, minHeight: 160)
      } else {
        List {
          ForEach(selectedPDFURLs, id: \.path) { url in
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
            selectedPDFURLs.remove(atOffsets: indexes)
          }
        }
        .frame(minHeight: 160)
      }
    }
  }

  private var operationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Operation")
        .font(.headline)

      HStack {
        Picker("Operation", selection: $operation) {
          Text("Inspect").tag("inspect")
          Text("Extract Text").tag("extractText")
          Text("Merge PDFs").tag("merge")
          Text("Split Pages").tag("split")
          Text("Extract Pages").tag("extractPages")
          Text("Delete Pages").tag("deletePages")
          Text("Reorder Pages").tag("reorderPages")
          Text("Rotate Pages").tag("rotatePages")
          Text("Append Pages").tag("appendPages")
          Text("Scrub Metadata").tag("scrubMetadata")
        }
        .pickerStyle(.menu)
        .frame(width: 220)
        Spacer()
      }

      if operation == "split" {
        VStack(alignment: .leading, spacing: 10) {
          Picker("Split scope", selection: $splitMode) {
            Text("All pages").tag("all")
            Text("Selected pages").tag("selected")
          }
          .pickerStyle(.segmented)

          if splitMode == "selected" {
            TextField("Pages, for example 1,3-5", text: $selectedPages)
              .textFieldStyle(.roundedBorder)
            Text("Use comma-separated pages or ranges, such as 2,4-6.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      } else if operation == "extractPages" || operation == "rotatePages" {
        VStack(alignment: .leading, spacing: 10) {
          Picker("Page scope", selection: $splitMode) {
            Text("All pages").tag("all")
            Text("Selected pages").tag("selected")
          }
          .pickerStyle(.segmented)

          if splitMode == "selected" {
            TextField("Pages, for example 1,3-5", text: $selectedPages)
              .textFieldStyle(.roundedBorder)
          }

          if operation == "rotatePages" {
            Picker("Rotation", selection: $rotationDegrees) {
              Text("90 degrees").tag("90")
              Text("180 degrees").tag("180")
              Text("270 degrees").tag("270")
            }
            .pickerStyle(.segmented)
          }
        }
      } else if operation == "deletePages" {
        TextField("Pages to delete, for example 2,4-6", text: $selectedPages)
          .textFieldStyle(.roundedBorder)
      } else if operation == "reorderPages" {
        VStack(alignment: .leading, spacing: 8) {
          TextField("New page order, for example 3,1,2,4-6", text: $selectedPages)
            .textFieldStyle(.roundedBorder)
          Text("Only pages listed here are written to the new PDF, in this exact order.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } else if operation == "scrubMetadata" {
        VStack(alignment: .leading, spacing: 8) {
          Text("Remove Fields")
            .font(.subheadline.weight(.semibold))
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            Toggle("Title", isOn: $scrubTitle)
            Toggle("Author", isOn: $scrubAuthor)
            Toggle("Subject", isOn: $scrubSubject)
            Toggle("Creator", isOn: $scrubCreator)
            Toggle("Producer", isOn: $scrubProducer)
            Toggle("Keywords", isOn: $scrubKeywords)
            Toggle("Creation date", isOn: $scrubCreationDate)
            Toggle("Modified date", isOn: $scrubModificationDate)
          }
          Text("The scrubbed PDF is written as a new file; the original stays unchanged.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      if requiresMultiplePDFs, selectedPDFURLs.count < 2 {
        Label("\(primaryActionTitle) requires at least two PDFs.", systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
      }
    }
  }

  @ViewBuilder
  private var outputLocationSection: some View {
    if operation == "split" {
      VStack(alignment: .leading, spacing: 10) {
        Text("Output Folder")
          .font(.headline)
        HStack {
          Text(outputDirectoryURL?.path ?? "Choose an output folder")
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer()
          Button {
            chooseOutputFolder()
          } label: {
            Label("Choose", systemImage: "folder")
          }
        }
      }
    } else if usesOutputFile {
      VStack(alignment: .leading, spacing: 10) {
        Text("Output File")
          .font(.headline)
        HStack {
          Text(mergeOutputURL?.path ?? suggestedOutputURL?.path ?? "Choose where to save the output PDF")
            .lineLimit(1)
            .truncationMode(.middle)
          Spacer()
          Button {
            chooseMergeOutput()
          } label: {
            Label("Choose", systemImage: "square.and.arrow.down")
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
        placeholder: "Choose files and run a PDF operation.",
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

  private var primaryActionTitle: String {
    switch operation {
    case "extractText": "Extract"
    case "merge": "Merge"
    case "split": "Split"
    case "extractPages": "Extract"
    case "deletePages": "Delete"
    case "reorderPages": "Reorder"
    case "rotatePages": "Rotate"
    case "appendPages": "Append"
    case "scrubMetadata": "Scrub"
    default: "Inspect"
    }
  }

  private var canRun: Bool {
    if selectedPDFURLs.isEmpty || isRunning { return false }
    if requiresMultiplePDFs { return selectedPDFURLs.count >= 2 }
    if operation == "split", splitMode == "selected" {
      return !selectedPages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    if ["deletePages", "reorderPages"].contains(operation) {
      return !selectedPages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    if operation == "scrubMetadata" {
      return scrubTitle || scrubAuthor || scrubSubject || scrubCreator || scrubProducer || scrubKeywords || scrubCreationDate || scrubModificationDate
    }
    if ["extractPages", "rotatePages"].contains(operation), splitMode == "selected" {
      return !selectedPages.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    return true
  }

  private var requiresMultiplePDFs: Bool {
    operation == "merge" || operation == "appendPages"
  }

  private var usesOutputFile: Bool {
    ["merge", "extractPages", "deletePages", "reorderPages", "rotatePages", "appendPages", "scrubMetadata"].contains(operation)
  }

  private var suggestedOutputURL: URL? {
    guard let firstURL = selectedPDFURLs.first else { return nil }
    let suffix: String
    switch operation {
    case "merge": suffix = "merged"
    case "extractPages": suffix = "extracted"
    case "deletePages": suffix = "deleted"
    case "reorderPages": suffix = "reordered"
    case "rotatePages": suffix = "rotated"
    case "appendPages": suffix = "appended"
    case "scrubMetadata": suffix = "metadata-scrubbed"
    default: suffix = "output"
    }
    return firstURL
      .deletingLastPathComponent()
      .appendingPathComponent("\(firstURL.deletingPathExtension().lastPathComponent)-\(suffix).pdf")
  }

  private func restoreSession() {
    let session = store.sessions[.pdfToolkit] ?? ToolSessionState(definition: ToolRegistry.definition(for: .pdfToolkit))
    selectedPDFURLs = session.input
      .split(whereSeparator: \.isNewline)
      .map { URL(fileURLWithPath: String($0)) }
      .filter { FileManager.default.fileExists(atPath: $0.path) }
    operation = session.options.operation.isEmpty ? "inspect" : session.options.operation
    selectedPages = session.options.textValues["pages"] ?? "1"
    splitMode = selectedPages.lowercased() == "all" ? "all" : "selected"
    rotationDegrees = session.options.textValues["rotation"] ?? "90"
    scrubTitle = session.options.boolValues["scrubTitle"] ?? true
    scrubAuthor = session.options.boolValues["scrubAuthor"] ?? true
    scrubSubject = session.options.boolValues["scrubSubject"] ?? true
    scrubCreator = session.options.boolValues["scrubCreator"] ?? true
    scrubProducer = session.options.boolValues["scrubProducer"] ?? true
    scrubKeywords = session.options.boolValues["scrubKeywords"] ?? true
    scrubCreationDate = session.options.boolValues["scrubCreationDate"] ?? true
    scrubModificationDate = session.options.boolValues["scrubModificationDate"] ?? true
    if let folder = session.options.textValues["outputDirectory"], !folder.isEmpty {
      outputDirectoryURL = URL(fileURLWithPath: NSString(string: folder).expandingTildeInPath)
    }
    if let file = session.options.textValues["outputPath"], !file.isEmpty {
      mergeOutputURL = URL(fileURLWithPath: NSString(string: file).expandingTildeInPath)
    }
    output = session.output
    errorMessage = session.errorMessage
    outputURLs = FileResultMetadata.existingGeneratedFileURLs(from: session.metadata, outputFallback: session.output)
  }

  private func choosePDFs() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.pdf]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    if panel.runModal() == .OK {
      selectedPDFURLs = panel.urls
      if let firstURL = panel.urls.first {
        outputDirectoryURL = firstURL.deletingLastPathComponent()
        mergeOutputURL = suggestedOutputURL
      }
      outputURLs.removeAll()
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

  private func chooseMergeOutput() {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.nameFieldStringValue = suggestedOutputURL?.lastPathComponent ?? "output.pdf"
    if panel.runModal() == .OK {
      mergeOutputURL = panel.url
    }
  }

  private func run() {
    guard canRun else { return }
    var options = ToolRegistry.definition(for: .pdfToolkit).defaultOptions
    options.operation = operation
    if ["split", "extractPages", "rotatePages"].contains(operation) {
      options.textValues["pages"] = splitMode == "selected" ? selectedPages : "all"
    } else {
      options.textValues["pages"] = selectedPages
    }
    options.textValues["rotation"] = rotationDegrees
    options.boolValues["scrubTitle"] = scrubTitle
    options.boolValues["scrubAuthor"] = scrubAuthor
    options.boolValues["scrubSubject"] = scrubSubject
    options.boolValues["scrubCreator"] = scrubCreator
    options.boolValues["scrubProducer"] = scrubProducer
    options.boolValues["scrubKeywords"] = scrubKeywords
    options.boolValues["scrubCreationDate"] = scrubCreationDate
    options.boolValues["scrubModificationDate"] = scrubModificationDate
    if let outputDirectoryURL {
      options.textValues["outputDirectory"] = outputDirectoryURL.path
    }
    if let outputURL = mergeOutputURL ?? suggestedOutputURL {
      options.textValues["outputPath"] = outputURL.path
    }

    let input = selectedPDFURLs.map(\.path).joined(separator: "\n")
    isRunning = true
    errorMessage = nil
    outputURLs.removeAll()

    Task {
      do {
        let result = try await runner.run(toolID: .pdfToolkit, input: input, options: options)
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
    var session = ToolSessionState(definition: ToolRegistry.definition(for: .pdfToolkit))
    session.input = input
    session.options = options
    session.output = result.output
    session.metadata = result.metadata
    session.diagnostics = result.diagnostics
    store.sessions[.pdfToolkit] = session
  }

  private func apply(error: Error, input: String, options: ToolOptions) {
    isRunning = false
    output = ""
    outputURLs.removeAll()
    errorMessage = error.localizedDescription
    var session = ToolSessionState(definition: ToolRegistry.definition(for: .pdfToolkit))
    session.input = input
    session.options = options
    session.errorMessage = error.localizedDescription
    store.sessions[.pdfToolkit] = session
  }

  private func copyOutput() {
    guard !output.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(output, forType: .string)
  }
}
