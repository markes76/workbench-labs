import SwiftUI
import WorkbenchLabsCore

struct ToolOptionsView: View {
  let definition: ToolDefinition
  @Binding var session: ToolSessionState
  var onChange: (() -> Void)?

  var body: some View {
    if definition.options.isEmpty {
      EmptyView()
    } else {
      ScrollView(.horizontal) {
        HStack(spacing: 14) {
          ForEach(definition.options.filter { !hideOptionFromToolbar($0) }) { option in
            optionControl(option)
          }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
      }
      .background(.bar)
    }
  }

  private func hideOptionFromToolbar(_ option: ToolOption) -> Bool {
    option.key == "secondaryInput" && (definition.id == .textDiff || definition.id == .envInspector)
  }

  @ViewBuilder
  private func optionControl(_ option: ToolOption) -> some View {
    switch option.kind {
    case .operation:
      Picker(option.label, selection: operationBinding) {
        ForEach(option.choices, id: \.value) { choice in
          Text(choice.label).tag(choice.value)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: max(180, CGFloat(option.choices.count) * 92))
    case .picker:
      Picker(option.label, selection: textBinding(option.key)) {
        ForEach(option.choices, id: \.value) { choice in
          Text(choice.label).tag(choice.value)
        }
      }
      .frame(width: 150)
    case .boolean:
      Toggle(option.label, isOn: boolBinding(option.key))
        .toggleStyle(.checkbox)
    case .integer:
      HStack(spacing: 6) {
        Text(option.label)
          .foregroundStyle(.secondary)
        Stepper(value: intBinding(option.key), in: integerRange(for: option)) {
          Text("\(session.options.intValues[option.key] ?? 0)")
            .monospacedDigit()
            .frame(width: 44, alignment: .trailing)
        }
      }
    case .secureText:
      SecureField(option.label, text: textBinding(option.key))
        .textFieldStyle(.roundedBorder)
        .frame(width: 220)
    case .text:
      TextField(option.label, text: option.key == "secondaryInput" ? secondaryBinding : textBinding(option.key))
        .textFieldStyle(.roundedBorder)
        .frame(width: option.key == "secondaryInput" ? 320 : 240)
    }
  }

  private var operationBinding: Binding<String> {
    Binding(
      get: { session.options.operation },
      set: {
        session.options.operation = $0
        onChange?()
      }
    )
  }

  private var secondaryBinding: Binding<String> {
    Binding(
      get: { session.options.secondaryInput },
      set: {
        session.options.secondaryInput = $0
        onChange?()
      }
    )
  }

  private func textBinding(_ key: String) -> Binding<String> {
    Binding(
      get: { session.options.textValues[key] ?? "" },
      set: {
        session.options.textValues[key] = $0
        onChange?()
      }
    )
  }

  private func boolBinding(_ key: String) -> Binding<Bool> {
    Binding(
      get: { session.options.boolValues[key] ?? false },
      set: {
        session.options.boolValues[key] = $0
        onChange?()
      }
    )
  }

  private func intBinding(_ key: String) -> Binding<Int> {
    Binding(
      get: { session.options.intValues[key] ?? 0 },
      set: {
        session.options.intValues[key] = $0
        onChange?()
      }
    )
  }

  private func integerRange(for option: ToolOption) -> ClosedRange<Int> {
    (option.minimumValue ?? 0)...(option.maximumValue ?? 1_000_000)
  }
}
