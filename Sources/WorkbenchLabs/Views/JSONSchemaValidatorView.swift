import AppKit
import SwiftUI
import WorkbenchLabsCore

struct JSONSchemaValidatorView: View {
  @EnvironmentObject private var store: WorkbenchStore

  private let definition = ToolRegistry.definition(for: .jsonSchemaValidator)

  private var session: Binding<ToolSessionState> {
    Binding(
      get: { store.sessions[.jsonSchemaValidator] ?? ToolSessionState(definition: definition) },
      set: { store.sessions[.jsonSchemaValidator] = $0 }
    )
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      HSplitView {
        documentPane
          .frame(minWidth: 300, idealWidth: 440)
          .workbenchPaneBackground()
        schemaPane
          .frame(minWidth: 300, idealWidth: 440)
          .workbenchPaneBackground()
        resultPane
          .frame(minWidth: 340)
          .workbenchPaneBackground()
      }
    }
  }

  private var header: some View {
    ToolWorkspaceHeader(
      title: definition.title,
      subtitle: definition.subtitle,
      systemImage: definition.systemImage
    ) {
      Toggle("Strict", isOn: strictSchemaBinding)
        .toggleStyle(.checkbox)
      if store.isRunning {
        ProgressView()
          .controlSize(.small)
      }
      Button {
        store.runSelectedTool()
      } label: {
        Label("Validate", systemImage: "play.fill")
      }
      .keyboardShortcut(.return, modifiers: [.command])
      .buttonStyle(.borderedProminent)
    }
  }

  private var documentPane: some View {
    VStack(spacing: 0) {
      CodeEditorView(
        title: "JSON Document",
        placeholder: "Paste JSON to validate...",
        text: inputBinding
      )
      .padding()
      HStack {
        Button {
          openTextFile(target: "document")
        } label: {
          Label("Open", systemImage: "folder")
        }
        Button {
          loadSample()
        } label: {
          Label("Sample", systemImage: "text.badge.plus")
        }
        Button {
          if let text = NSPasteboard.general.string(forType: .string) {
            inputBinding.wrappedValue = text
          }
        } label: {
          Label("Clipboard", systemImage: "doc.on.clipboard")
        }
        Spacer()
      }
      .padding([.horizontal, .bottom])
    }
  }

  private var schemaPane: some View {
    VStack(spacing: 0) {
      CodeEditorView(
        title: "JSON Schema",
        placeholder: "Paste JSON Schema...",
        text: schemaBinding
      )
      .padding()
      HStack {
        Button {
          openTextFile(target: "schema")
        } label: {
          Label("Open Schema", systemImage: "folder.badge.gearshape")
        }
        Button {
          clear()
        } label: {
          Label("Clear", systemImage: "xmark.circle")
        }
        Spacer()
      }
      .padding([.horizontal, .bottom])
    }
  }

  private var resultPane: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Result")
          .font(.headline)
        if let error = session.wrappedValue.errorMessage {
          Label(error, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
            .lineLimit(1)
        } else if let valid = session.wrappedValue.metadata["valid"] {
          WorkbenchStatusPill(valid == "true" ? "Valid" : "Invalid", systemImage: valid == "true" ? "checkmark.circle" : "xmark.octagon")
        }
        Spacer()
        Button {
          copyOutput()
        } label: {
          Label("Copy", systemImage: "doc.on.doc")
        }
        .disabled(session.wrappedValue.output.isEmpty)
      }
      .padding(.horizontal)
      .padding(.vertical, 10)
      .background(.bar)

      CodeEditorView(
        title: "Validation Result",
        placeholder: "Run validation to see schema errors.",
        text: .constant(session.wrappedValue.output),
        isReadOnly: true,
        showsHeader: false
      )
      .padding()
    }
  }

  private var inputBinding: Binding<String> {
    Binding(
      get: { session.wrappedValue.input },
      set: {
        var next = session.wrappedValue
        next.input = $0
        session.wrappedValue = next
      }
    )
  }

  private var schemaBinding: Binding<String> {
    Binding(
      get: { session.wrappedValue.options.secondaryInput },
      set: {
        var next = session.wrappedValue
        next.options.secondaryInput = $0
        session.wrappedValue = next
      }
    )
  }

  private var strictSchemaBinding: Binding<Bool> {
    Binding(
      get: { session.wrappedValue.options.boolValues["strictSchema"] ?? false },
      set: {
        var next = session.wrappedValue
        next.options.boolValues["strictSchema"] = $0
        session.wrappedValue = next
      }
    )
  }

  private func loadSample() {
    var next = session.wrappedValue
    next.input = definition.sampleInput
    next.options.secondaryInput = definition.defaultOptions.secondaryInput
    next.output = ""
    next.errorMessage = nil
    next.metadata = [:]
    session.wrappedValue = next
  }

  private func clear() {
    var next = session.wrappedValue
    next.input = ""
    next.options.secondaryInput = ""
    next.output = ""
    next.errorMessage = nil
    next.metadata = [:]
    session.wrappedValue = next
  }

  private func openTextFile(target: String) {
    let panel = NSOpenPanel()
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    if panel.runModal() == .OK,
       let url = panel.url,
       let text = try? String(contentsOf: url, encoding: .utf8) {
      if target == "schema" {
        schemaBinding.wrappedValue = text
      } else {
        inputBinding.wrappedValue = text
      }
    }
  }

  private func copyOutput() {
    let output = session.wrappedValue.output
    guard !output.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(output, forType: .string)
  }
}
