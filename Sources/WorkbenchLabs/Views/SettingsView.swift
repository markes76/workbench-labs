import SwiftUI

struct SettingsView: View {
  @AppStorage("preview.allowJavaScript") private var allowJavaScript = false
  @AppStorage("preview.allowNavigation") private var allowNavigation = false
  @AppStorage("preview.allowExternalRequests") private var allowExternalRequests = false
  @AppStorage("editor.runOnInputChange") private var runOnInputChange = false

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        WorkbenchLabsWordmark(compact: true)
        Spacer()
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 14)
      .background(.bar)

      TabView {
        Form {
          Toggle("Run tools when input changes", isOn: $runOnInputChange)
          LabeledContent("Global hotkey", value: "Option-Space")
        }
        .padding()
        .tabItem { Label("General", systemImage: "gearshape") }

        Form {
          Toggle("Allow JavaScript in HTML previews", isOn: $allowJavaScript)
          Toggle("Allow navigation from HTML previews", isOn: $allowNavigation)
          Toggle("Allow external requests from HTML previews", isOn: $allowExternalRequests)
          Text("External requests are blocked by default with a local content security policy.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .tabItem { Label("Preview", systemImage: "safari") }
      }
    }
    .frame(width: 540, height: 320)
  }
}
