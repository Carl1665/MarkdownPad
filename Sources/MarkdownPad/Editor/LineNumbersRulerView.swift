import AppKit

/// A ruler view that displays line numbers for an NSTextView
final class LineNumbersRulerView: NSRulerView {
    weak var textView: NSTextView?
    var theme: EditorTheme

    private let lineNumberColor: NSColor = NSColor.white
    private let padding: CGFloat = 8
    private var lastLineCount: Int = 0

    init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation, textView: NSTextView, theme: EditorTheme) {
        self.textView = textView
        self.theme = theme
        super.init(scrollView: scrollView, orientation: orientation)
        updateThickness(for: 1)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    /// Update ruler width based on number of digits needed
    private func updateThickness(for lineCount: Int) {
        let digits = max(2, String(lineCount).count)
        // Measure width of "0" character as representative digit width
        let zeroAttrs: [NSAttributedString.Key: Any] = [.font: theme.font]
        let charWidth = ("0" as NSString).size(withAttributes: zeroAttrs).width
        let newThickness = CGFloat(digits) * charWidth + padding * 2
        ruleThickness = newThickness
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        // Fill background with theme color
        theme.background.setFill()
        bounds.fill()

        guard let textView = textView,
              let scrollView = self.scrollView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let string = textView.string as NSString

        // Count total lines and update thickness if needed
        let totalLines: Int
        if string.length == 0 {
            totalLines = 1
        } else {
            var count = 1
            for i in 0..<string.length {
                if string.character(at: i) == 10 { count += 1 }
            }
            totalLines = count
        }

        if totalLines != lastLineCount {
            lastLineCount = totalLines
            updateThickness(for: totalLines)
        }

        // Get scroll offset from the scroll view
        let scrollOffset = scrollView.contentView.bounds.origin.y
        let rulerHeight = bounds.height
        let insetY = textView.textContainerInset.height

        // Set up text attributes
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .right

        let attrs: [NSAttributedString.Key: Any] = [
            .font: theme.font,
            .foregroundColor: lineNumberColor,
            .paragraphStyle: paragraphStyle
        ]

        guard string.length > 0 else {
            // Draw line 1 for empty document
            let y = insetY - scrollOffset
            if y >= -theme.font.boundingRectForFont.height && y <= rulerHeight {
                let drawRect = NSRect(x: padding, y: y, width: bounds.width - padding * 2, height: theme.font.boundingRectForFont.height)
                let lineNumStr = "1"
                lineNumStr.draw(in: drawRect, withAttributes: attrs)
            }
            return
        }

        // Find the starting character index from scroll offset
        let visibleTopY = scrollOffset
        let glyphIndex = layoutManager.glyphIndex(for: NSPoint(x: 0, y: visibleTopY), in: textContainer)
        let startCharIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

        // Count newlines to get starting line number
        var lineNumber = 1
        for i in 0..<startCharIndex {
            if string.character(at: i) == 10 { // newline
                lineNumber += 1
            }
        }

        // Draw line numbers for visible lines
        var charIndex = startCharIndex

        while charIndex < string.length {
            let lineRange = string.lineRange(for: NSRange(location: charIndex, length: 0))
            let lineGlyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: lineGlyphIndex, effectiveRange: nil)

            // Calculate Y position relative to ruler (accounting for scroll offset)
            let textY = lineRect.origin.y + insetY
            let y = textY - scrollOffset

            // Stop if past visible area
            if y > rulerHeight { break }

            // Draw line number if within visible bounds
            // Vertically center the line number text within the line fragment rect
            if y >= -lineRect.height {
                // Calculate the actual text height and center it within the line rect
                let textHeight = theme.font.boundingRectForFont.height
                let verticalOffset = (lineRect.height - textHeight) / 2
                let drawRect = NSRect(x: padding, y: y + verticalOffset, width: bounds.width - padding * 2, height: textHeight)
                let lineNumStr = "\(lineNumber)"
                lineNumStr.draw(in: drawRect, withAttributes: attrs)
            }

            charIndex = NSMaxRange(lineRange)
            lineNumber += 1
        }
    }

    func updateTheme(_ newTheme: EditorTheme) {
        self.theme = newTheme
        needsDisplay = true
    }
}
