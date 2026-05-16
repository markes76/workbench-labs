import AppKit
import Carbon
import WorkbenchLabsCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let servicesProvider = ServicesProvider()
  private var hotKeyManager: HotKeyManager?
  weak var store: WorkbenchStore?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    NSApp.servicesProvider = servicesProvider
    NSUpdateDynamicServices()
  }

  func connect(store: WorkbenchStore) {
    self.store = store
    servicesProvider.store = store
    if hotKeyManager == nil {
      let manager = HotKeyManager()
      manager.registerOptionSpace { [weak self] in
        Task { @MainActor in
          self?.store?.inspectClipboard()
          NSApp.activate(ignoringOtherApps: true)
        }
      }
      hotKeyManager = manager
    }
  }
}

@MainActor
final class ServicesProvider: NSObject {
  weak var store: WorkbenchStore?

  @objc func inspectInWorkbenchLabs(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
      error.pointee = "No text was available to inspect."
      return
    }
    store?.inspect(text: text)
    NSApp.activate(ignoringOtherApps: true)
  }
}

final class HotKeyManager {
  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private var action: (() -> Void)?

  deinit {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
    }
    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
    }
  }

  func registerOptionSpace(action: @escaping () -> Void) {
    self.action = action

    var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let selfPointer = Unmanaged.passUnretained(self).toOpaque()
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, userData in
        guard let userData else { return noErr }
        let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        manager.action?()
        return noErr
      },
      1,
      &eventSpec,
      selfPointer,
      &eventHandlerRef
    )

    let hotKeyID = EventHotKeyID(signature: fourCharCode("DVUT"), id: 1)
    RegisterEventHotKey(
      UInt32(kVK_Space),
      UInt32(optionKey),
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
  }
}

private func fourCharCode(_ string: String) -> OSType {
  string.utf8.reduce(0) { result, byte in
    (result << 8) + OSType(byte)
  }
}
