import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct MarkdownPadApp: App {
    @FocusedValue(\.activeTabManager) var tabManager

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建") {
                    tabManager?.newDocument()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(tabManager == nil)

                Button("打开...") {
                    openFile()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("保存") {
                    saveActiveDocument()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(tabManager?.activeDocument == nil)
            }

            CommandGroup(replacing: .toolbar) {
                Button("关闭标签页") {
                    closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(tabManager?.activeDocument == nil)

                Divider()

                Button("上一个标签页") {
                    switchTab(offset: -1)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(tabManager == nil || (tabManager?.documents.count ?? 0) < 2)

                Button("下一个标签页") {
                    switchTab(offset: 1)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(tabManager == nil || (tabManager?.documents.count ?? 0) < 2)
            }

            CommandMenu("格式") {
                Button("加粗") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.bold)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("斜体") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.italic)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("链接") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.link)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md"), UTType(filenameExtension: "markdown")].compactMap { $0 }
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let doc = try? MarkdownDocument.open(url: url) {
                tabManager?.addDocument(doc)
            }
        }
    }

    private func saveActiveDocument() {
        guard let doc = tabManager?.activeDocument else { return }
        if doc.fileURL != nil {
            try? doc.save()
        } else {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [UTType(filenameExtension: "md")].compactMap { $0 }
            panel.nameFieldStringValue = "Untitled.md"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try? doc.save(to: url)
        }
    }

    private func closeActiveTab() {
        guard let doc = tabManager?.activeDocument else { return }
        if doc.isDirty {
            let alert = NSAlert()
            alert.messageText = "是否保存更改？"
            alert.addButton(withTitle: "保存")
            alert.addButton(withTitle: "不保存")
            alert.addButton(withTitle: "取消")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                saveActiveDocument()
                tabManager?.closeDocument(doc)
            } else if response == .alertSecondButtonReturn {
                tabManager?.closeDocument(doc)
            }
        } else {
            tabManager?.closeDocument(doc)
        }
    }

    private func switchTab(offset: Int) {
        guard let tm = tabManager,
              let active = tm.activeDocument,
              let index = tm.documents.firstIndex(where: { $0.id == active.id }) else { return }
        let newIndex = (index + offset + tm.documents.count) % tm.documents.count
        tm.activeDocument = tm.documents[newIndex]
    }
}

extension Notification.Name {
    static let formatAction = Notification.Name("formatAction")
}
