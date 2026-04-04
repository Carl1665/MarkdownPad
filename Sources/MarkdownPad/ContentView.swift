import SwiftUI
import AppKit
import os.log

private let logger = Logger(subsystem: "com.markdownpad", category: "ContentView")

struct ContentView: View {
    @State private var tabManager = TabManager()
    @State private var scrollSync = ScrollSyncCoordinator()
    @State private var cursorLine: Int = 1
    @State private var cursorColumn: Int = 1
    @State private var wordCount: Int = 0
    @State private var editorTextView: NSTextView?

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
                line: cursorLine,
                column: cursorColumn,
                wordCount: wordCount,
                encoding: tabManager.activeDocument?.encoding == .utf8 ? "UTF-8" : "ASCII"
            )
        }
        .focusedSceneValue(\.activeTabManager, tabManager)
        .onAppear {
            if tabManager.documents.isEmpty {
                tabManager.newDocument()
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url = url,
                          ["md", "markdown"].contains(url.pathExtension.lowercased()) else { return }
                    DispatchQueue.main.async {
                        if let doc = try? MarkdownDocument.open(url: url) {
                            tabManager.addDocument(doc)
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
    }

    private var emptyState: some View {
        VStack {
            Text("打开或新建一个 Markdown 文档")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            let result = FormatInserter.wrapSelection(selectedText, with: "**")
            insertText = result.text
            newCursorOffset = result.selectionOffset
            newSelectionLength = result.selectionLength
        case .italic:
            let result = FormatInserter.wrapSelection(selectedText, with: "*")
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
            insertText = "\n- "
        case .orderedList:
            insertText = "\n1. "
        case .taskList:
            insertText = "\n- [ ] "
        case .blockquote:
            insertText = "\n> "
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
        }

        textView.insertText(insertText, replacementRange: selectedRange)

        if newCursorOffset > 0 {
            let newStart = selectedRange.location + newCursorOffset
            textView.setSelectedRange(NSRange(location: newStart, length: newSelectionLength))
        }

        doc.text = textView.string
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
        HSplitView {
            EditorView(
                text: $doc.text,
                scrollToLine: scrollSync.lastScrollSource == .preview ? scrollSync.previewFirstLine : nil,
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
                    // Post notification - this bypasses struct capture issues
                    NotificationCenter.default.post(
                        name: .editorTextDidChange,
                        object: newText
                    )
                },
                onTextViewReady: onTextViewReady
            )
            .frame(minWidth: 300)

            PreviewView(
                html: parsedHTML,
                scrollToLine: scrollSync.lastScrollSource == .editor ? scrollSync.editorFirstLine : nil,
                onFirstVisibleLine: { line in
                    scrollSync.previewDidScroll(toLine: line)
                }
            )
            .frame(minWidth: 300)
        }
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
