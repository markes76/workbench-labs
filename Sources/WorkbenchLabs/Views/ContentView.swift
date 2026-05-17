import SwiftUI
import WorkbenchLabsCore

struct ContentView: View {
  @EnvironmentObject private var store: WorkbenchStore

  var body: some View {
    NavigationSplitView {
      SidebarView()
        .navigationSplitViewColumnWidth(min: 240, ideal: 290, max: 360)
    } detail: {
      if store.selectedToolID == .unixTimestamp {
        UnixTimeConverterView()
          .id("\(store.selectedToolID.rawValue)-\(store.detailRefreshID)")
      } else if store.selectedToolID == .jsonFormatter {
        JSONFormatValidateView()
          .id("\(store.selectedToolID.rawValue)-\(store.detailRefreshID)")
      } else if store.selectedToolID == .jsonSchemaValidator {
        JSONSchemaValidatorView()
          .id("\(store.selectedToolID.rawValue)-\(store.detailRefreshID)")
      } else if store.selectedToolID == .base64Codec {
        Base64StringEncodeDecodeView()
          .id("\(store.selectedToolID.rawValue)-\(store.detailRefreshID)")
      } else if store.selectedToolID == .pdfToolkit {
        PDFToolkitView()
          .id("\(store.selectedToolID.rawValue)-\(store.detailRefreshID)")
      } else if store.selectedToolID == .imageConverter {
        ImageConverterView()
          .id("\(store.selectedToolID.rawValue)-\(store.detailRefreshID)")
      } else if store.selectedToolID == .batchImageResizer {
        BatchImageResizerView()
          .id("\(store.selectedToolID.rawValue)-\(store.detailRefreshID)")
      } else if store.selectedToolID == .imageMetadataInspector {
        ImageMetadataInspectorView()
          .id("\(store.selectedToolID.rawValue)-\(store.detailRefreshID)")
      } else if store.selectedToolID == .videoConverter {
        VideoConverterView()
          .id("\(store.selectedToolID.rawValue)-\(store.detailRefreshID)")
      } else {
        ToolDetailView(definition: store.selectedDefinition)
          .id("\(store.selectedToolID.rawValue)-\(store.detailRefreshID)")
      }
    }
    .toolbar {
      ToolbarItemGroup {
        Button {
          store.inspectClipboard()
        } label: {
          Label("Inspect Clipboard", systemImage: "doc.on.clipboard")
        }
        .help("Inspect Clipboard")
      }
    }
  }
}
