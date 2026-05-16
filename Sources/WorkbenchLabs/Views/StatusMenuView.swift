import SwiftUI
import WorkbenchLabsCore

struct StatusMenuView: View {
  @Environment(\.openWindow) private var openWindow
  @EnvironmentObject private var store: WorkbenchStore

  var body: some View {
    Button("Open Workbench Labs") {
      openWindow(id: "main")
      NSApp.activate(ignoringOtherApps: true)
    }

    Button("Inspect Clipboard") {
      openWindow(id: "main")
      store.inspectClipboard()
      NSApp.activate(ignoringOtherApps: true)
    }

    Divider()

    ForEach(store.suggestions.prefix(5), id: \.self) { suggestion in
      let definition = ToolRegistry.definition(for: suggestion.toolID)
      Button(definition.title) {
        openWindow(id: "main")
        store.selectedToolID = suggestion.toolID
        store.runSelectedToolFromCommand()
        NSApp.activate(ignoringOtherApps: true)
      }
    }

    Divider()

    SettingsLink()

    Button("Quit") {
      NSApp.terminate(nil)
    }
  }
}
