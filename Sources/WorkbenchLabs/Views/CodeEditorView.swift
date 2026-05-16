import SwiftUI

struct CodeEditorView: View {
  let title: String
  let placeholder: String
  @Binding var text: String
  var isReadOnly = false
  var showsHeader = true

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if showsHeader {
        editorHeader
      }

      editorShell
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var editorHeader: some View {
    HStack(spacing: 6) {
      Image(systemName: isReadOnly ? "lock" : "terminal")
        .font(.caption2.weight(.semibold))
      Text(title)
        .font(.caption.weight(.semibold))
      Spacer()
    }
    .foregroundStyle(.secondary)
  }

  private var editorShell: some View {
    VStack(spacing: 0) {
      editorBody
      Divider()
      statusBar
    }
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(.primary.opacity(isReadOnly ? 0.12 : 0.08), lineWidth: 1)
    }
  }

  private var editorBody: some View {
    ZStack(alignment: .topLeading) {
      TextEditor(text: editorText)
        .font(.system(.body, design: .monospaced))
        .scrollContentBackground(.hidden)
        .textEditorStyle(.plain)
        .padding(8)
        .accessibilityLabel("\(title) editor")
        .accessibilityHint(isReadOnly ? "Read-only" : "Editable")
        .frame(maxWidth: .infinity, maxHeight: .infinity)

      if text.isEmpty {
        Text(placeholder)
          .font(.system(.body, design: .monospaced))
          .foregroundStyle(.tertiary)
          .padding(.horizontal, 14)
          .padding(.vertical, 16)
          .allowsHitTesting(false)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var statusBar: some View {
    HStack(spacing: 9) {
      HStack(spacing: 4) {
        Image(systemName: isReadOnly ? "lock.fill" : "pencil")
          .font(.caption2.weight(.semibold))
        Text(isReadOnly ? "Read-only" : "Editable")
      }

      Text(lineStatus)
      Text(characterStatus)
      Spacer()
    }
    .font(.caption2.monospacedDigit())
    .foregroundStyle(.secondary)
    .padding(.horizontal, 10)
    .padding(.vertical, 5)
    .background(.bar)
  }

  private var editorText: Binding<String> {
    isReadOnly ? .constant(text) : $text
  }

  private var lineStatus: String {
    "\(lineCount) \(lineCount == 1 ? "line" : "lines")"
  }

  private var characterStatus: String {
    "\(text.count) \(text.count == 1 ? "character" : "characters")"
  }

  private var lineCount: Int {
    guard !text.isEmpty else { return 0 }
    return text.split(separator: "\n", omittingEmptySubsequences: false).count
  }
}
