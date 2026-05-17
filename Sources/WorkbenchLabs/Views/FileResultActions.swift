import AppKit
import Foundation

enum FileResultActions {
  static func copyPaths(_ urls: [URL]) {
    guard !urls.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(urls.map(\.path).joined(separator: "\n"), forType: .string)
  }

  static func reveal(_ urls: [URL]) {
    guard !urls.isEmpty else { return }
    NSWorkspace.shared.activateFileViewerSelecting(urls)
  }
}
