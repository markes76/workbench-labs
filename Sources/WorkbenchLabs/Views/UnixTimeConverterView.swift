import AppKit
import SwiftUI
import WorkbenchLabsCore

struct UnixTimeConverterView: View {
  @EnvironmentObject private var store: WorkbenchStore
  @AppStorage("unixTime.additionalTimeZones") private var storedTimeZoneIDs = ""
  @State private var input = ""
  @State private var inputKind: UnixTimeInputKind = .unixSeconds
  @State private var result: UnixTimeResult?
  @State private var errorMessage: String?
  @State private var selectedTimeZoneID = TimeZone.knownTimeZoneIdentifiers.first ?? "UTC"
  @State private var addedTimeZoneIDs: [String] = []

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          inputSection
          Divider()
          if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.red)
          }
          outputGrid
          Divider()
          timeZoneSection
        }
        .padding(20)
      }
      .workbenchPaneBackground()
    }
    .onAppear {
      let session = store.sessions[.unixTimestamp] ?? store.selectedSession
      if input.isEmpty {
        input = session.input
      }
      if
        let storedInputKind = session.options.textValues["inputKind"],
        let restoredKind = UnixTimeInputKind(rawValue: storedInputKind)
      {
        inputKind = restoredKind
      }
      if addedTimeZoneIDs.isEmpty, !storedTimeZoneIDs.isEmpty {
        addedTimeZoneIDs = storedTimeZoneIDs.split(separator: "\n").map(String.init)
      }
      convert()
      if store.runRequest?.toolID == .unixTimestamp {
        convert()
      }
    }
    .onChange(of: input) { _, _ in convert() }
    .onChange(of: inputKind) { _, _ in convert() }
    .onChange(of: addedTimeZoneIDs) { _, value in
      storedTimeZoneIDs = value.joined(separator: "\n")
      convert()
    }
    .onChange(of: store.runRequest) { _, request in
      guard request?.toolID == .unixTimestamp else { return }
      convert()
    }
  }

  private var header: some View {
    ToolWorkspaceHeader(
      title: "Unix Time Converter",
      subtitle: "Convert Unix seconds, milliseconds, ISO 8601 dates, relative time, and timezone formats.",
      systemImage: "clock"
    )
  }

  private var inputSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Text("Input")
          .font(.title3.weight(.semibold))

        Button {
          let now = Date()
          switch inputKind {
          case .unixSeconds:
            input = String(Int64(now.timeIntervalSince1970))
          case .unixMilliseconds:
            input = String(Int64((now.timeIntervalSince1970 * 1000).rounded()))
          case .iso8601:
            input = ISO8601DateFormatter().string(from: now)
          }
        } label: {
          Label("Now", systemImage: "clock.badge.checkmark")
        }

        Button {
          if let text = NSPasteboard.general.string(forType: .string) {
            input = text
          }
        } label: {
          Label("Clipboard", systemImage: "doc.on.clipboard")
        }

        Button {
          input = ""
          result = nil
          errorMessage = nil
        } label: {
          Label("Clear", systemImage: "xmark.circle")
        }

        Button {
          NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } label: {
          Image(systemName: "gearshape.fill")
        }
        .help("Settings")
      }
      .controlSize(.small)

      HStack(spacing: 14) {
        TextField("", text: $input)
          .textFieldStyle(.plain)
          .font(.system(.title3, design: .monospaced))
          .padding(.horizontal, 8)
          .frame(height: 34)
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
          .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .strokeBorder(.primary.opacity(0.10), lineWidth: 1)
          }

        Picker("", selection: $inputKind) {
          ForEach(UnixTimeInputKind.allCases) { kind in
            Text(kind.title).tag(kind)
          }
        }
        .labelsHidden()
        .frame(width: 430)
      }

      Text("Tips: Mathematical operators + - * / are supported")
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  private var outputGrid: some View {
    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 28, verticalSpacing: 14) {
      GridRow {
        VStack(alignment: .leading, spacing: 16) {
          copyField("Local:", result?.local ?? "")
          copyField("UTC (ISO 8601):", result?.utcISO8601 ?? "")
          copyField("Relative:", result?.relative ?? "")
          copyField("Unix time:", result?.unixSeconds ?? "")
          copyField("Milliseconds:", result?.unixMilliseconds ?? "")
        }
        VStack(alignment: .leading, spacing: 16) {
          copyField("Day of year", result?.dayOfYear ?? "", width: 110)
          copyField("Week of year", result?.weekOfYear ?? "", width: 110)
          copyField("Is leap year?", result?.isLeapYear ?? "", width: 110)
        }
        VStack(alignment: .leading, spacing: 16) {
          Text("Other formats (local)")
            .font(.title3.weight(.semibold))
          ForEach(Array((result?.localFormats ?? Array(repeating: "", count: 6)).enumerated()), id: \.offset) { _, value in
            copyOnlyField(value, width: 330)
          }
        }
      }
    }
  }

  private var timeZoneSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Text("Other timezones")
          .font(.title3.weight(.semibold))

        TimeZoneComboBox(selection: $selectedTimeZoneID)
          .frame(width: 420)

        Button {
          guard TimeZone(identifier: selectedTimeZoneID) != nil, !addedTimeZoneIDs.contains(selectedTimeZoneID) else { return }
          addedTimeZoneIDs.append(selectedTimeZoneID)
        } label: {
          Label("Add", systemImage: "plus")
        }
      }

      if addedTimeZoneIDs.isEmpty {
        Text("(Pick a timezone to get started...)")
          .foregroundStyle(.secondary)
      } else {
        ForEach(result?.timeZones ?? [], id: \.identifier) { zone in
          HStack(spacing: 8) {
            Text("\(zone.identifier): \(zone.formatted)")
              .font(.title3)
            Button {
              addedTimeZoneIDs.removeAll { $0 == zone.identifier }
            } label: {
              Image(systemName: "minus.circle")
            }
            .controlSize(.small)
            .help("Remove timezone")
          }
        }
      }
    }
  }

  private func copyField(_ label: String, _ value: String, width: CGFloat = 470) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(label)
        .font(.title3.weight(.semibold))
      copyOnlyField(value, width: width)
    }
  }

  private func copyOnlyField(_ value: String, width: CGFloat) -> some View {
    HStack(spacing: 8) {
      TextField("", text: .constant(value))
        .textFieldStyle(.plain)
        .font(.system(.title3, design: .default))
        .padding(.horizontal, 8)
        .frame(width: width, height: 34)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(.primary.opacity(0.10), lineWidth: 1)
        }

      Button {
        copy(value)
      } label: {
        Image(systemName: "doc.on.doc")
      }
      .disabled(value.isEmpty)
      .help("Copy")
    }
  }

  private func convert() {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      result = nil
      errorMessage = nil
      return
    }

    do {
      let timeZones = addedTimeZoneIDs.compactMap(TimeZone.init(identifier:))
      result = try UnixTimeConverter.convert(input: trimmed, inputKind: inputKind, additionalTimeZones: timeZones)
      errorMessage = nil
      store.setInput(trimmed, for: .unixTimestamp)
      var session = store.sessions[.unixTimestamp] ?? ToolSessionState(definition: ToolRegistry.definition(for: .unixTimestamp))
      session.options.textValues["inputKind"] = inputKind.rawValue
      session.output = resultOutput
      session.errorMessage = nil
      store.sessions[.unixTimestamp] = session
    } catch {
      result = nil
      errorMessage = error.localizedDescription
    }
  }

  private var resultOutput: String {
    guard let result else { return "" }
    return """
    Local: \(result.local)
    UTC (ISO 8601): \(result.utcISO8601)
    Relative: \(result.relative)
    Unix time: \(result.unixSeconds)
    Unix milliseconds: \(result.unixMilliseconds)
    Day of year: \(result.dayOfYear)
    Week of year: \(result.weekOfYear)
    Is leap year?: \(result.isLeapYear)

    Other formats (local):
    \(result.localFormats.joined(separator: "\n"))
    """
  }

  private func copy(_ value: String) {
    guard !value.isEmpty else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
  }
}

struct TimeZoneComboBox: NSViewRepresentable {
  @Binding var selection: String

  func makeCoordinator() -> Coordinator {
    Coordinator(selection: $selection)
  }

  func makeNSView(context: Context) -> NSComboBox {
    let comboBox = NSComboBox()
    comboBox.usesDataSource = false
    comboBox.completes = true
    comboBox.numberOfVisibleItems = 12
    comboBox.addItems(withObjectValues: TimeZone.knownTimeZoneIdentifiers)
    comboBox.stringValue = selection
    comboBox.delegate = context.coordinator
    comboBox.font = .systemFont(ofSize: NSFont.systemFontSize + 3)
    return comboBox
  }

  func updateNSView(_ comboBox: NSComboBox, context: Context) {
    if comboBox.stringValue != selection {
      comboBox.stringValue = selection
    }
  }

  final class Coordinator: NSObject, NSComboBoxDelegate {
    @Binding var selection: String

    init(selection: Binding<String>) {
      _selection = selection
    }

    func comboBoxSelectionDidChange(_ notification: Notification) {
      guard let comboBox = notification.object as? NSComboBox else { return }
      selection = comboBox.stringValue
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let comboBox = notification.object as? NSComboBox else { return }
      selection = comboBox.stringValue
    }
  }
}
