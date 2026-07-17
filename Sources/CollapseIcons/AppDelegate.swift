import AppKit
import Carbon
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var bar: StatusBarController?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.registerDefaults()
        Constant.isLTR = NSApp.userInterfaceLayoutDirection == .leftToRight
        bar = StatusBarController()
        installHotkey()
        applyLoginItem()

        NotificationCenter.default.addObserver(self, selector: #selector(onSettings),
                                               name: .settingsDidChange, object: nil)

        if AppSettings.showPrefsOnLaunch {
            SettingsWindowController.shared.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) { uninstallHotkey() }

    @objc private func onSettings() {
        installHotkey()
        applyLoginItem()
        bar?.reloadFromSettings()
    }

    private func applyLoginItem() {
        guard #available(macOS 13.0, *) else { return }
        try? AppSettings.launchAtLogin
            ? SMAppService.mainApp.register()
            : SMAppService.mainApp.unregister()
    }

    private func installHotkey() {
        uninstallHotkey()
        guard AppSettings.hotkeyEnabled else { return }

        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let del = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { del.bar?.expandCollapse() }
            return noErr
        }, 1, &type, userData, &hotKeyHandler)

        let id = EventHotKeyID(signature: OSType(0x4349434F), id: 1)
        RegisterEventHotKey(UInt32(AppSettings.hotkeyKeyCode), AppSettings.hotkeyModifiers,
                            id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    private func uninstallHotkey() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef); self.hotKeyRef = nil }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler); self.hotKeyHandler = nil }
    }
}
