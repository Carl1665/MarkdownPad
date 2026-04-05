import SwiftUI
import AppKit
import UniformTypeIdentifiers

@main
struct MarkdownPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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

                Button("另存为...") {
                    saveActiveDocumentAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(tabManager?.activeDocument == nil)

                Divider()

                // 关闭标签页 - 替代系统的关闭窗口
                Button("关闭标签页") {
                    closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(tabManager?.activeDocument == nil)

                Divider()

                // Recent files menu
                Menu("最近文件") {
                    ForEach(RecentFilesManager.shared.recentFiles, id: \.self) { url in
                        Button(url.lastPathComponent) {
                            openRecentFile(url)
                        }
                    }

                    if !RecentFilesManager.shared.recentFiles.isEmpty {
                        Divider()
                        Button("清除最近文件") {
                            RecentFilesManager.shared.clearRecentFiles()
                        }
                    }
                }
                .disabled(RecentFilesManager.shared.recentFiles.isEmpty)
            }

            CommandGroup(replacing: .toolbar) {
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

            // 查找命令 - 使用 textEditing 位置
            CommandGroup(after: .textEditing) {
                Button("查找...") {
                    NSLog("DEBUG: Find menu item clicked")
                    performFindAction(.showFindPanel)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("查找下一个") {
                    performFindAction(.next)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("查找上一个") {
                    performFindAction(.previous)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
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

                Button("行内代码") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.inlineCode)
                }
                .keyboardShortcut("e", modifiers: .command)

                Divider()

                Button("标题 1") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.heading(1))
                }
                .keyboardShortcut("1", modifiers: [.command, .option])

                Button("标题 2") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.heading(2))
                }
                .keyboardShortcut("2", modifiers: [.command, .option])

                Button("标题 3") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.heading(3))
                }
                .keyboardShortcut("3", modifiers: [.command, .option])

                Button("标题 4") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.heading(4))
                }
                .keyboardShortcut("4", modifiers: [.command, .option])

                Divider()

                Button("无序列表") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.unorderedList)
                }
                .keyboardShortcut("8", modifiers: [.command, .shift])

                Button("有序列表") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.orderedList)
                }
                .keyboardShortcut("7", modifiers: [.command, .shift])

                Divider()

                Button("增加缩进") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.increaseIndent)
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("减少缩进") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.decreaseIndent)
                }
                .keyboardShortcut("[", modifiers: .command)

                Divider()

                Button("引用块") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.blockquote)
                }
                .keyboardShortcut(".", modifiers: [.command, .shift])

                Button("代码块") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.codeBlock)
                }
                .keyboardShortcut("c", modifiers: [.command, .option])

                Button("分隔线") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.horizontalRule)
                }

                Divider()

                Button("链接") {
                    NotificationCenter.default.post(name: .formatAction, object: ToolbarView.ToolbarAction.link)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = Constants.markdownContentTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            do {
                let doc = try MarkdownDocument.open(url: url)
                tabManager?.addDocument(doc)
                RecentFilesManager.shared.addFile(url)
            } catch {
                tabManager?.showError(ErrorMessage.cannotOpenFile(url.lastPathComponent, error: error))
            }
        }
    }

    private func openRecentFile(_ url: URL) {
        do {
            let doc = try MarkdownDocument.open(url: url)
            tabManager?.addDocument(doc)
            RecentFilesManager.shared.addFile(url)
        } catch {
            tabManager?.showError(ErrorMessage.cannotOpenFile(url.lastPathComponent, error: error))
        }
    }

    private func saveActiveDocument() {
        guard let doc = tabManager?.activeDocument else { return }
        if doc.fileURL != nil {
            do {
                try doc.save()
            } catch {
                tabManager?.showError(ErrorMessage.saveFailed(error))
            }
        } else {
            saveActiveDocumentAs()
        }
    }

    private func saveActiveDocumentAs() {
        guard let doc = tabManager?.activeDocument else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = Constants.markdownContentTypes
        panel.nameFieldStringValue = doc.fileURL?.lastPathComponent ?? "Untitled.md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try doc.save(to: url)
            RecentFilesManager.shared.addFile(url)
        } catch {
            tabManager?.showError(ErrorMessage.saveFailed(error))
        }
    }

    private func closeActiveTab() {
        guard let doc = tabManager?.activeDocument else { return }

        if doc.isDirty {
            showCloseConfirmation(for: doc)
        } else {
            tabManager?.closeDocument(doc)
        }
    }

    private func showCloseConfirmation(for doc: MarkdownDocument) {
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
                    tabManager?.closeDocument(doc)
                } catch {
                    tabManager?.showError("保存失败：\(error.localizedDescription)")
                }
            } else {
                let panel = NSSavePanel()
                panel.allowedContentTypes = Constants.markdownContentTypes
                panel.nameFieldStringValue = doc.displayName + ".md"
                if panel.runModal() == .OK, let url = panel.url {
                    do {
                        try doc.save(to: url)
                        tabManager?.closeDocument(doc)
                    } catch {
                        tabManager?.showError("保存失败：\(error.localizedDescription)")
                    }
                }
            }
        case .alertSecondButtonReturn:  // 不保存
            tabManager?.closeDocument(doc)
        default:  // 取消
            break
        }
    }

    private func performFindAction(_ action: NSFindPanelAction) {
        guard let textView = ActiveTextView.shared.textView else {
            return
        }

        // 确保 textView 是 firstResponder
        textView.window?.makeFirstResponder(textView)

        // 使用 NSApp.sendAction 通过响应链发送查找操作
        let sender = NSButton()
        sender.tag = Int(action.rawValue)
        NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: sender)
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
