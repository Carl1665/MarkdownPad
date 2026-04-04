import AppKit

/// AppDelegate 处理窗口关闭行为
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // 不允许关闭最后一个窗口时自动退出
        return false
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 设置窗口关闭时的行为
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}
