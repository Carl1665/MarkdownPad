import SwiftUI
import AppKit
import os.log

private let logger = Logger(subsystem: "com.markdownpad", category: "EditorView")

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

        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
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

        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        // Apply theme
        let theme = ThemeManager.shared.editorTheme
        textView.backgroundColor = theme.background
        textView.insertionPointColor = theme.text
        textView.font = theme.font

        // Set up delegate
        textView.delegate = context.coordinator

        // Store reference for updates
        context.coordinator.textView = textView
        context.coordinator.highlighter = SyntaxHighlighter(theme: theme)

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

        // Make textView first responder when window becomes key
        DispatchQueue.main.async {
            if let window = scrollView.window {
                window.makeFirstResponder(textView)
            }
        }

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
            textView.string = text
            context.coordinator.highlighter?.highlightParagraph(
                in: textView.textStorage!,
                editedRange: NSRange(location: 0, length: (text as NSString).length)
            )
            context.coordinator.isUpdating = false
        }

        // Update theme if changed — rebuild highlighter and re-highlight
        let theme = ThemeManager.shared.editorTheme
        if textView.backgroundColor != theme.background {
            textView.backgroundColor = theme.background
            textView.insertionPointColor = theme.text
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
        var isUpdating = false
        var isScrollingFromCode = false

        init(_ parent: EditorView) {
            self.parent = parent
        }

        @MainActor @objc func scrollViewDidScroll(_ notification: Notification) {
            guard !isScrollingFromCode else { return }
            guard let clipView = notification.object as? NSClipView,
                  let textView = textView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            // Find the character index at the top of the visible rect
            let visibleY = clipView.bounds.origin.y
            let glyphIndex = layoutManager.glyphIndex(for: NSPoint(x: 0, y: visibleY), in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

            // Count newlines up to charIndex to determine line number (1-based)
            let head = (textView.string as NSString).substring(to: min(charIndex, (textView.string as NSString).length))
            let lineNumber = max(head.components(separatedBy: "\n").count, 1)
            parent.onFirstVisibleLine?(lineNumber)
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

                // Syntax highlighting (delayed to avoid interfering with input method)
                DispatchQueue.main.async { [weak self] in
                    guard let self, let textStorage = textView.textStorage else { return }
                    self.highlighter?.highlightParagraph(in: textStorage, editedRange: NSRange(location: 0, length: newText.count))
                }
            }
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
