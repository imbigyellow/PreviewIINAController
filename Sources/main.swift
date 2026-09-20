import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = Controller()
    private var settingsWindow: SettingsWindow?
    private var ready = false
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard ready else { return false }
        if settingsWindow == nil {
            let panel = SettingsWindow(settings: controller.settings) { [weak self] value in
                self?.controller.apply(value)
            }
            panel.onClose = { [weak self] in
                // Release after AppKit finishes dispatching the close notification.
                DispatchQueue.main.async { self?.settingsWindow = nil }
            }
            settingsWindow = panel
        }
        settingsWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        return false
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            showFailure("需要辅助功能权限", "请在系统设置 → 隐私与安全性 → 辅助功能中允许 PreviewIINAController，然后重新启动此应用。此应用将退出，不会轮询权限。")
            return
        }
        guard controller.start() else {
            showFailure("无法建立键盘 EventTap", "请检查 PreviewIINAController 的辅助功能权限后重新启动。应用已安全停止，不会拦截键盘。")
            return
        }
        ready = true
    }
    private func showFailure(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "退出")
        alert.runModal()
        NSApp.terminate(nil)
    }
    func applicationWillTerminate(_ notification: Notification) { controller.stop() }
}
let app = NSApplication.shared
let delegate = AppDelegate() // Strong lifetime covers every unmanaged EventTap callback.
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
