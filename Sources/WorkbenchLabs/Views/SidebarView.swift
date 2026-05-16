import SwiftUI
import WorkbenchLabsCore

struct SidebarView: View {
  @EnvironmentObject private var store: WorkbenchStore

  var body: some View {
    VStack(spacing: 0) {
      SidebarBrandHeader()
      Divider()

      List(selection: $store.selectedToolID) {
        if !store.suggestions.isEmpty {
          Section("Detected") {
            ForEach(store.suggestions.prefix(4), id: \.self) { suggestion in
              let definition = ToolRegistry.definition(for: suggestion.toolID)
              HStack(spacing: 10) {
                Image(systemName: definition.systemImage)
                  .foregroundStyle(.secondary)
                  .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                  Text(definition.title)
                    .lineLimit(1)
                  Text(suggestion.reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
              }
              .tag(definition.id)
              .help(suggestion.reason)
            }
          }
        }

        ForEach(ToolCategory.allCases) { category in
          let tools = store.filteredTools(in: category)
          if !tools.isEmpty {
            Section(category.rawValue) {
              ForEach(tools) { tool in
                HStack(spacing: 10) {
                  Image(systemName: tool.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(tool.title)
                      .lineLimit(1)
                    Text(tool.subtitle)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                }
                .tag(tool.id)
              }
            }
          }
        }
      }
      .listStyle(.sidebar)
      .searchable(text: $store.searchText, placement: .sidebar)
    }
  }
}
