import SwiftUI
import AppKit
import UniformTypeIdentifiers
import os.log

private let logger = Logger(subsystem: "com.markdownpad", category: "ContentView")

private let welcomeContent = """
# 欢迎使用 MarkdownPad

这是一个 **Markdown** 编辑器，支持实时预览。

## 基本语法

### 文本格式

- **加粗**: 使用双星号 `**文字**`
- *斜体*: 使用单星号 `*文字*`
- `代码`: 使用反引号

### 标题

使用 `#` 号表示标题级别：

```
# H1 标题
## H2 标题
### H3 标题
```

### 列表

无序列表：
- 项目一
- 项目二
- 项目三

有序列表：
1. 第一步
2. 第二步
3. 第三步

### 代码块

```swift
func hello() {
    print("Hello, World!")
}
```

### 引用

> 这是一段引用文字
> 可以有多行

### 链接和图片

[链接文字](https://example.com)

![图片描述](image.png)

### 表格

| 列1 | 列2 | 列3 |
|-----|-----|-----|
| A   | B   | C   |
| D   | E   | F   |

---

开始编辑吧！
"""

struct ContentView: View {
    @State private var tabManager = TabManager()
    @State private var scrollSync = ScrollSyncCoordinator()
    @State private var cursorLine: Int = 1
    @State private var cursorColumn: Int = 1
    @State private var wordCount: Int = 0
    @State private var editorTextView: NSTextView?
    @State private var pendingCloseDoc: MarkdownDocument?  // 等待确认关闭的文档
    @State private var windowCloseDelegate: WindowCloseDelegate?  // 窗口关闭代理

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            TabBarView(tabManager: tabManager)

            // Toolbar
            ToolbarView(onAction: handleToolbarAction)

            // Editor + Preview
            if let doc = tabManager.activeDocument {
                EditorPreviewPair(
                    doc: doc,
                    scrollSync: scrollSync,
                    cursorLine: $cursorLine,
                    cursorColumn: $cursorColumn,
                    wordCount: $wordCount,
                    onTextViewReady: { textView in
                        DispatchQueue.main.async {
                            editorTextView = textView
                        }
                    }
                )
            } else {
                HSplitView {
                    emptyState
                    PreviewView(
                        html: "",
                        scrollToLine: nil,
                        onFirstVisibleLine: { _ in }
                    )
                    .frame(minWidth: 300)
                }
            }

            // Status bar
            StatusBarView(
                documentName: tabManager.activeDocument?.displayName,
                line: cursorLine,
                column: cursorColumn,
                wordCount: wordCount,
                encoding: tabManager.activeDocument?.encoding == .utf8 ? "UTF-8" : "ASCII"
            )
        }
        .focusedSceneValue(\.activeTabManager, tabManager)
        .frame(minWidth: Constants.Window.minWidth, minHeight: Constants.Window.minHeight)
        .onAppear {
            // 设置窗口关闭代理，拦截关闭时对未保存文档弹出确认
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                    let delegate = WindowCloseDelegate()
                    delegate.tabManager = tabManager
                    delegate.window = window
                    window.delegate = delegate
                    windowCloseDelegate = delegate
                }
            }

            if tabManager.documents.isEmpty {
                // Check if first run
                if !UserDefaults.standard.bool(forKey: Constants.UserDefaultsKeys.hasLaunchedBefore) {
                    UserDefaults.standard.set(true, forKey: Constants.UserDefaultsKeys.hasLaunchedBefore)
                    // Show welcome document with Markdown examples
                    let welcomeDoc = MarkdownDocument(text: welcomeContent)
                    tabManager.addDocument(welcomeDoc)
                } else {
                    tabManager.newDocument()
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url,
                          ["md", "markdown"].contains(url.pathExtension.lowercased()) else { return }
                    DispatchQueue.main.async {
                        do {
                            let doc = try MarkdownDocument.open(url: url)
                            tabManager.addDocument(doc)
                            RecentFilesManager.shared.addFile(url)
                        } catch {
                            tabManager.showError(ErrorMessage.cannotOpenFile(url.lastPathComponent, error: error))
                        }
                    }
                }
            }
            return true
        }
        .onReceive(NotificationCenter.default.publisher(for: .formatAction)) { notification in
            if let action = notification.object as? ToolbarView.ToolbarAction {
                handleToolbarAction(action)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .requestCloseDocument)) { notification in
            if let doc = notification.object as? MarkdownDocument {
                pendingCloseDoc = doc
                showSaveConfirmDialog(for: doc)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openFileFromDock)) { notification in
            if let url = notification.object as? URL {
                do {
                    let doc = try MarkdownDocument.open(url: url)
                    tabManager.addDocument(doc)
                    RecentFilesManager.shared.addFile(url)
                } catch {
                    tabManager.showError(ErrorMessage.cannotOpenFile(url.lastPathComponent, error: error))
                }
            }
        }
        .alert("错误", isPresented: Binding(
            get: { tabManager.errorMessage != nil },
            set: { if !$0 { tabManager.dismissError() } }
        )) {
            Button("确定", role: .cancel) {
                tabManager.dismissError()
            }
        } message: {
            Text(tabManager.errorMessage ?? "发生未知错误")
        }
    }

    private func showSaveConfirmDialog(for doc: MarkdownDocument) {
        let alert = NSAlert()
        alert.messageText = "是否保存更改？"
        alert.informativeText = "文档 \"\(doc.displayName)\" 有未保存的更改。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "不保存")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        pendingCloseDoc = nil

        switch response {
        case .alertFirstButtonReturn:  // 保存
            handleSaveAndClose(doc: doc)
        case .alertSecondButtonReturn:  // 不保存
            tabManager.closeDocument(doc)
        default:  // 取消
            break
        }
    }

    private func handleSaveAndClose(doc: MarkdownDocument) {
        if doc.fileURL != nil {
            do {
                try doc.save()
                tabManager.closeDocument(doc)
            } catch {
                tabManager.showError(ErrorMessage.saveFailed(error))
            }
        } else {
            // Show save panel for untitled document
            let panel = NSSavePanel()
            panel.allowedContentTypes = Constants.markdownContentTypes
            panel.nameFieldStringValue = doc.displayName + ".md"
            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try doc.save(to: url)
                    tabManager.closeDocument(doc)
                } catch {
                    tabManager.showError(ErrorMessage.saveFailed(error))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: Constants.EmptyState.iconSize))
                .foregroundStyle(.secondary)

            Text("MarkdownPad")
                .font(.title2)
                .fontWeight(.medium)

            Text("打开或新建一个 Markdown 文档开始编辑")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button("新建文档") {
                    tabManager.newDocument()
                }
                .buttonStyle(.borderedProminent)

                Button("打开文件...") {
                    openFile()
                }
                .buttonStyle(.bordered)
            }

            Text("或将 .md 文件拖拽到窗口中")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
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
                tabManager.addDocument(doc)
            } catch {
                tabManager.showError(ErrorMessage.cannotOpenFile(url.lastPathComponent, error: error))
            }
        }
    }

    // MARK: - Toolbar Actions (insert at cursor via NSTextView)

    private func handleToolbarAction(_ action: ToolbarView.ToolbarAction) {
        guard let textView = editorTextView,
              let doc = tabManager.activeDocument else {
            return
        }

        let selectedRange = textView.selectedRange()
        let selectedText = (textView.string as NSString).substring(with: selectedRange)

        var insertText: String
        var newCursorOffset: Int = 0
        var newSelectionLength: Int = 0

        switch action {
        case .bold:
            let result = FormatInserter.wrapSelection(
                selectedText, with: "**",
                fullText: textView.string, selectedRange: selectedRange
            )
            insertText = result.text
            newCursorOffset = result.selectionOffset
            newSelectionLength = result.selectionLength
        case .italic:
            let result = FormatInserter.wrapSelection(
                selectedText, with: "*",
                fullText: textView.string, selectedRange: selectedRange
            )
            insertText = result.text
            newCursorOffset = result.selectionOffset
            newSelectionLength = result.selectionLength
        case .heading(let level):
            let prefix = String(repeating: "#", count: level) + " "
            let lineRange = (textView.string as NSString).lineRange(for: selectedRange)
            let currentLine = (textView.string as NSString).substring(with: lineRange).trimmingCharacters(in: .newlines)
            let newLine = FormatInserter.insertPrefix(prefix, forLine: currentLine)
            textView.insertText(newLine, replacementRange: lineRange)
            doc.text = textView.string
            return
        case .unorderedList:
            let result = FormatInserter.toggleLinePrefix("- ", in: textView.string, range: selectedRange)
            applyLineEdit(result, textView: textView)
            doc.text = textView.string
            return
        case .orderedList:
            let result = FormatInserter.toggleOrderedList(in: textView.string, range: selectedRange)
            applyLineEdit(result, textView: textView)
            doc.text = textView.string
            return
        case .taskList:
            let result = FormatInserter.toggleLinePrefix("- [ ] ", in: textView.string, range: selectedRange)
            applyLineEdit(result, textView: textView)
            doc.text = textView.string
            return
        case .blockquote:
            let result = FormatInserter.toggleLinePrefix("> ", in: textView.string, range: selectedRange)
            applyLineEdit(result, textView: textView)
            doc.text = textView.string
            return
        case .codeBlock:
            insertText = FormatInserter.insertCodeBlock(language: "")
        case .horizontalRule:
            insertText = FormatInserter.insertHorizontalRule()
        case .link:
            let result = FormatInserter.insertLink(
                text: selectedText.isEmpty ? "链接文字" : selectedText,
                url: "url"
            )
            insertText = result
        case .image:
            insertText = FormatInserter.insertImage(alt: "描述", url: "image.png")
        case .table:
            insertText = "\n" + FormatInserter.insertTable(rows: 2, cols: 3)
        case .inlineCode:
            let result = FormatInserter.wrapSelection(
                selectedText.isEmpty ? "代码" : selectedText,
                with: "`",
                fullText: textView.string, selectedRange: selectedRange
            )
            insertText = result.text
            newCursorOffset = result.selectionOffset
            newSelectionLength = result.selectionLength
        case .increaseIndent:
            let lineRange = (textView.string as NSString).lineRange(for: selectedRange)
            let currentLine = (textView.string as NSString).substring(with: lineRange)
            // Indent all selected lines
            let lines = currentLine.components(separatedBy: "\n")
            let indented = lines.map { "    " + $0 }.joined(separator: "\n")
            textView.insertText(indented, replacementRange: lineRange)
            doc.text = textView.string
            return
        case .decreaseIndent:
            let lineRange = (textView.string as NSString).lineRange(for: selectedRange)
            let currentLine = (textView.string as NSString).substring(with: lineRange)
            let lines = currentLine.components(separatedBy: "\n")
            let dedented = lines.map { line in
                if line.hasPrefix("    ") {
                    return String(line.dropFirst(4))
                } else if line.hasPrefix("\t") {
                    return String(line.dropFirst())
                } else {
                    return line
                }
            }.joined(separator: "\n")
            textView.insertText(dedented, replacementRange: lineRange)
            doc.text = textView.string
            return
        }

        // For wrap/unwrap: if offset is negative, we're unwrapping — expand the replacement range
        var replacementRange = selectedRange
        if newCursorOffset < 0 {
            let wrapperLen = -newCursorOffset
            replacementRange = NSRange(
                location: selectedRange.location - wrapperLen,
                length: selectedRange.length + wrapperLen * 2
            )
            newCursorOffset = 0
        }

        textView.insertText(insertText, replacementRange: replacementRange)

        if newCursorOffset > 0 || newSelectionLength > 0 {
            let newStart = replacementRange.location + newCursorOffset
            textView.setSelectedRange(NSRange(location: newStart, length: newSelectionLength))
        }

        doc.text = textView.string
    }

    /// Apply a line-level edit by first selecting the full line range, then inserting replacement text.
    /// This ensures the replacement starts at the beginning of the line, regardless of where the
    /// user's original selection started.
    private func applyLineEdit(
        _ result: (newText: String, newRange: NSRange),
        textView: NSTextView
    ) {
        // Step 1: Select the full line range so insertText replaces the correct span
        textView.setSelectedRange(result.newRange)
        // Step 2: Insert replaces the current selection
        textView.insertText(result.newText)
    }
}

// MARK: - EditorPreviewPair

struct EditorPreviewPair: View {
    @Bindable var doc: MarkdownDocument
    var scrollSync: ScrollSyncCoordinator
    @Binding var cursorLine: Int
    @Binding var cursorColumn: Int
    @Binding var wordCount: Int
    var onTextViewReady: ((NSTextView) -> Void)?

    @State private var parsedHTML: String = ""

    var body: some View {
        PersistentSplitView(
            leftContent: {
                EditorView(
                    text: $doc.text,
                    scrollToLine: scrollSync.shouldSyncToEditor() ? scrollSync.previewFirstLine : nil,
                    onCursorMove: { line, column in
                        cursorLine = line
                        cursorColumn = column
                        scrollSync.editorCursorMoved(toLine: line)
                    },
                    onFirstVisibleLine: { line in
                        scrollSync.editorDidScroll(toLine: line)
                    },
                    onTextChange: { newText in
                        logger.debug("onTextChange callback, posting notification")
                        NotificationCenter.default.post(
                            name: .editorTextDidChange,
                            object: newText
                        )
                    },
                    onTextViewReady: onTextViewReady
                )
            },
            rightContent: {
                PreviewView(
                    html: parsedHTML,
                    scrollToLine: scrollSync.shouldSyncToPreview() ? scrollSync.editorFirstLine : nil,
                    onFirstVisibleLine: { line in
                        scrollSync.previewDidScroll(toLine: line)
                    }
                )
            },
            leftMinWidth: 300,
            rightMinWidth: 300
        )
        .onAppear {
            updatePreview(text: doc.text)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorTextDidChange)) { notification in
            if let newText = notification.object as? String {
                logger.debug("received notification, length=\(newText.count)")
                doc.isDirty = true
                updatePreview(text: newText)
                logger.debug("updatePreview done, htmlLength=\(parsedHTML.count)")
            }
        }
    }

    private func updatePreview(text: String) {
        let parser = MarkdownParser()
        parsedHTML = parser.parse(text)
        wordCount = countWords(text)
    }

    private func countWords(_ text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..., options: .byWords) { _, _, _, _ in
            count += 1
        }
        return count
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let editorTextDidChange = Notification.Name("editorTextDidChange")
    static let requestCloseDocument = Notification.Name("requestCloseDocument")
    static let findAction = Notification.Name("findAction")
    static let openFileFromDock = Notification.Name("openFileFromDock")
}

// MARK: - FocusedValues

struct ActiveTabManagerKey: FocusedValueKey {
    typealias Value = TabManager
}

extension FocusedValues {
    var activeTabManager: TabManager? {
        get { self[ActiveTabManagerKey.self] }
        set { self[ActiveTabManagerKey.self] = newValue }
    }
}
