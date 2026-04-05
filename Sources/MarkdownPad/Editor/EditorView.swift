import SwiftUI
import AppKit
import os.log

private let logger = Logger(subsystem: "com.markdownpad", category: "EditorView")

// 全局保存当前活动的 textView 引用
@MainActor
final class ActiveTextView {
    static let shared = ActiveTextView()
    private(set) var textView: NSTextView?

    private init() {}

    func setTextView(_ textView: NSTextView?) {
        self.textView = textView
    }
}

struct EditorView: NSViewRepresentable {
    @Binding var text: String
    var scrollToLine: Int?
    var onCursorMove: ((Int, Int) -> Void)?  // Reports (line, column)
    var onFirstVisibleLine: ((Int) -> Void)? // Reports first visible source line
    var onTextChange: ((String) -> Void)?    // Called on every text change, bypasses SwiftUI observation
    var onTextViewReady: ((NSTextView) -> Void)?  // Called when NSTextView is created

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        // Apply theme
        let theme = ThemeManager.shared.editorTheme

        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.horizontalScrollElasticity = .none
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        scrollView.documentView = textView

        // Configure text view
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.usesFontPanel = false

        // 设置查找相关配置
        textView.isAutomaticTextCompletionEnabled = true
        textView.allowsDocumentBackgroundColorChange = false

        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        textView.backgroundColor = theme.background
        textView.insertionPointColor = theme.text
        textView.textColor = theme.text
        textView.font = theme.font

        // Set up line numbers ruler view
        let lineNumbersRuler = LineNumbersRulerView(
            scrollView: scrollView,
            orientation: .verticalRuler,
            textView: textView,
            theme: theme
        )
        scrollView.verticalRulerView = lineNumbersRuler
        context.coordinator.lineNumbersView = lineNumbersRuler

        // Disable scrollView's default ruler background to use custom theme color
        scrollView.borderType = .noBorder

        // Set up delegate
        textView.delegate = context.coordinator

        // Store reference for updates
        context.coordinator.textView = textView
        context.coordinator.highlighter = SyntaxHighlighter(theme: theme)

        // 保存到全局引用
        ActiveTextView.shared.setTextView(textView)

        // Notify parent that textView is ready
        onTextViewReady?(textView)

        // Set initial text
        textView.string = text
        context.coordinator.highlighter?.highlightParagraph(
            in: textView.textStorage!,
            editedRange: NSRange(location: 0, length: (text as NSString).length)
        )

        // Observe scroll events on the clip view
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        // 监听查找命令
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handleFindAction(_:)),
            name: .findAction,
            object: nil
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        // Keep coordinator's parent reference fresh so closures (Binding, onCursorMove) stay current
        context.coordinator.parent = self

        // Only update if text changed externally (not from user typing)
        // Also skip if input method is composing to avoid interrupting
        let hasMarkedText = textView.hasMarkedText()
        if textView.string != text && !context.coordinator.isUpdating && !hasMarkedText {
            context.coordinator.isUpdating = true
            let capturedText = text
            // Defer to next runloop to avoid modifying textStorage during a draw cycle
            DispatchQueue.main.async {
                // Use textStorage to update content safely, avoiding crashes during draw cycles
                if let textStorage = textView.textStorage {
                    let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
                    textStorage.beginEditing()
                    textStorage.replaceCharacters(in: fullRange, with: capturedText)
                    textStorage.endEditing()
                }
                context.coordinator.highlighter?.highlightParagraph(
                    in: textView.textStorage!,
                    editedRange: NSRange(location: 0, length: (capturedText as NSString).length)
                )
                context.coordinator.isUpdating = false
                // Trigger line numbers redraw when text changes externally (e.g. document switch)
                context.coordinator.lineNumbersView?.needsDisplay = true
            }
        }

        // Apply theme colors (these don't affect text attributes)
        let theme = ThemeManager.shared.editorTheme
        textView.backgroundColor = theme.background
        textView.insertionPointColor = theme.text
        // Note: Don't set textView.font here - it resets all text attributes
        // Font is handled by the syntax highlighter

        // Only re-highlight if theme actually changed
        if context.coordinator.lastTheme?.background != theme.background ||
           context.coordinator.lastTheme?.code != theme.code ||
           context.coordinator.lastTheme?.heading != theme.heading {
            context.coordinator.lastTheme = theme
            context.coordinator.highlighter = SyntaxHighlighter(theme: theme)
            context.coordinator.highlighter?.highlightParagraph(
                in: textView.textStorage!,
                editedRange: NSRange(location: 0, length: (textView.string as NSString).length)
            )
        }

        // Scroll to line (reverse sync: preview → editor)
        if let targetLine = scrollToLine, !context.coordinator.isScrollingFromCode {
            guard let textView = context.coordinator.textView,
                  let layoutManager = textView.layoutManager,
                  textView.textContainer != nil else { return }

            let string = textView.string as NSString
            // Find the character index at the start of targetLine (1-based)
            var charIndex = 0
            var currentLine = 1
            while currentLine < targetLine && charIndex < string.length {
                let lineRange = string.lineRange(for: NSRange(location: charIndex, length: 0))
                charIndex = NSMaxRange(lineRange)
                currentLine += 1
            }
            charIndex = min(charIndex, string.length)

            // Get the glyph rect for this character position
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            context.coordinator.isScrollingFromCode = true
            let targetY = lineRect.origin.y
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            // reflectScrolledClipView triggers tile() which may set bounds.origin.x != 0
            // when a vertical ruler is present. Force x back to 0.
            scrollView.contentView.bounds.origin.x = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                context.coordinator.isScrollingFromCode = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorView
        var textView: NSTextView?
        var highlighter: SyntaxHighlighter?
        var lineNumbersView: LineNumbersRulerView?
        var isUpdating = false
        var isScrollingFromCode = false
        var lastTheme: EditorTheme?  // Cache for theme change detection

        init(_ parent: EditorView) {
            self.parent = parent
        }

        @MainActor @objc func handleFindAction(_ notification: Notification) {
            guard let textView = textView,
                  let action = notification.object as? Int else { return }

            // 确保 textView 是 firstResponder
            if let window = textView.window, window.firstResponder !== textView {
                window.makeFirstResponder(textView)
            }

            textView.performFindPanelAction(NSFindPanelAction(rawValue: UInt(action)) ?? .showFindPanel)
        }

        @MainActor @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let clipView = notification.object as? NSClipView,
                  let textView = textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            // Don't report scroll position during programmatic scrolling
            guard !isScrollingFromCode else { return }

            // Find the character index at the top of the visible rect
            let visibleY = clipView.bounds.origin.y
            let glyphIndex = layoutManager.glyphIndex(for: NSPoint(x: 0, y: visibleY), in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            // Count newlines up to charIndex to determine line number (1-based)
            let string = textView.string as NSString
            let safeIndex = min(charIndex, string.length)
            var lineCount = 1
            for i in 0..<safeIndex {
                if string.character(at: i) == 10 { // newline
                    lineCount += 1
                }
            }
            parent.onFirstVisibleLine?(lineCount)

            // Redraw line numbers on scroll
            lineNumbersView?.needsDisplay = true
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView,
                  !isUpdating else { return }

            let newText = textView.string
            let hasMarkedText = textView.hasMarkedText()

            // Always update binding to keep it in sync
            isUpdating = true
            parent.text = newText
            isUpdating = false

            // Only update preview and highlighting when input method is not composing
            if !hasMarkedText {
                // Direct callback for preview update
                parent.onTextChange?(newText)

                // Syntax highlighting — re-highlight full document to ensure consistency.
                if let textStorage = textView.textStorage {
                    let fullRange = NSRange(location: 0, length: (newText as NSString).length)
                    highlighter?.highlightParagraph(in: textStorage, editedRange: fullRange)
                }
            }

            // Redraw line numbers on text change
            lineNumbersView?.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let selectedRange = textView.selectedRange()
            let string = textView.string as NSString
            let head = string.substring(to: min(selectedRange.location, string.length))
            let lines = head.components(separatedBy: "\n")
            let lineNumber = lines.count
            let column = (lines.last?.count ?? 0) + 1
            parent.onCursorMove?(lineNumber, column)
        }
    }
}
