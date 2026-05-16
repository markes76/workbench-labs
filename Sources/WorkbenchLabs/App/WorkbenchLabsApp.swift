import SwiftUI
import WorkbenchLabsCore

@main
struct WorkbenchLabsApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var store = WorkbenchStore()

  var body: some Scene {
    WindowGroup("Workbench Labs", id: "main") {
      ContentView()
        .environmentObject(store)
        .onAppear {
          appDelegate.connect(store: store)
        }
        .frame(minWidth: 1080, minHeight: 700)
    }
    .commands {
      CommandMenu("Workbench Labs") {
        Button("Inspect Clipboard") {
          store.inspectClipboard()
        }
        .keyboardShortcut("i", modifiers: [.command, .shift])

        Button("Run Tool") {
          store.runSelectedToolFromCommand()
        }
        .keyboardShortcut(.return, modifiers: [.command])

        Divider()

        Button("Use Output as Input") {
          store.useOutputAsInput()
        }
        .keyboardShortcut("u", modifiers: [.command, .shift])

        Button("Copy Output") {
          store.copyOutput()
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])
      }
    }

    MenuBarExtra("Workbench Labs", systemImage: "wrench.and.screwdriver") {
      StatusMenuView()
        .environmentObject(store)
    }

    Settings {
      SettingsView()
    }
  }
}
