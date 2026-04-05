import AppKit
import SwiftUI

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

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        openMarkdownFile(url)
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            openMarkdownFile(url)
        }
    }

    private func openMarkdownFile(_ url: URL) {
        guard ["md", "markdown", "txt"].contains(url.pathExtension.lowercased()) else { return }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("openFileFromDock"), object: url)
        }
    }
}

// MARK: - Window Close Delegate

/// 拦截窗口关闭，对未保存文档弹出确认对话框
class WindowCloseDelegate: NSObject, NSWindowDelegate {
    var tabManager: TabManager?
    weak var window: NSWindow?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let tabManager, !tabManager.documents.isEmpty else {
            return true
        }

        // 检查是否有未保存的文档
        let dirtyDocs = tabManager.documents.filter { $0.isDirty }
        if dirtyDocs.isEmpty {
            // 全部关闭
            for doc in tabManager.documents {
                tabManager.closeDocument(doc)
            }
            return true
        }

        // 有未保存文档，逐个确认
        for doc in dirtyDocs {
            let alert = NSAlert()
            alert.messageText = "是否保存更改？"
            alert.informativeText = "文档 \"\(doc.displayName)\" 有未保存的更改。"
            alert.addButton(withTitle: "保存")
            alert.addButton(withTitle: "不保存")
            alert.addButton(withTitle: "取消")

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:  // 保存
                if doc.fileURL != nil {
                    do {
                        try doc.save()
                    } catch {
                        tabManager.showError("保存失败：\(error.localizedDescription)")
                        return false
                    }
                } else {
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = Constants.markdownContentTypes
                    panel.nameFieldStringValue = doc.displayName + ".md"
                    if panel.runModal() == .OK, let url = panel.url {
                        do {
                            try doc.save(to: url)
                        } catch {
                            tabManager.showError("保存失败：\(error.localizedDescription)")
                            return false
                        }
                    } else {
                        return false  // 用户取消了保存面板
                    }
                }
            case .alertSecondButtonReturn:  // 不保存
                break
            default:  // 取消
                return false
            }
        }

        // 关闭所有文档
        for doc in tabManager.documents {
            tabManager.closeDocument(doc)
        }
        return true
    }
}
