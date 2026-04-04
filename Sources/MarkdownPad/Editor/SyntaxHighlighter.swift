import AppKit

final class SyntaxHighlighter {
    private let theme: EditorTheme

    init(theme: EditorTheme) {
        self.theme = theme
    }

    /// Highlight the entire document
    func highlightParagraph(in textStorage: NSTextStorage, editedRange: NSRange) {
        let string = textStorage.string as NSString
        let length = string.length

        guard length > 0 else { return }

        applyHighlighting(in: textStorage, range: NSRange(location: 0, length: length))
    }

    private func applyHighlighting(in textStorage: NSTextStorage, range: NSRange) {
        let string = textStorage.string as NSString

        guard range.location + range.length <= string.length else { return }

        // Step 1: Reset to default style
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.text,
            .font: theme.font,
        ]
        textStorage.setAttributes(defaultAttrs, range: range)

        // Step 2: Find and highlight code blocks FIRST (they take precedence)
        let codeBlockRanges = findCodeBlockRanges(in: string, range: range)
        for codeRange in codeBlockRanges {
            textStorage.addAttributes([
                .foregroundColor: theme.code,
                .font: theme.codeFont,
                .backgroundColor: theme.codeBackground
            ], range: codeRange)
        }

        // Step 3: Apply line-level styles (headings, blockquotes, lists, tables, hr)
        // These affect the whole line and should be applied before inline styles
        let linePatterns = buildLinePatterns()
        for (regex, attrBuilder) in linePatterns {
            let attrs = attrBuilder(theme)
            regex.enumerateMatches(in: textStorage.string as String, options: [], range: range) { match, _, _ in
                guard let matchRange = match?.range else { return }
                // Skip if this range overlaps with any code block
                for codeRange in codeBlockRanges {
                    if NSIntersectionRange(matchRange, codeRange).length > 0 {
                        return
                    }
                }
                textStorage.addAttributes(attrs, range: matchRange)
            }
        }

        // Step 4: Find inline code ranges first (they should be protected)
        var inlineCodeRanges: [NSRange] = []
        let inlineCodeRegex = try! NSRegularExpression(pattern: "`([^`]+)`", options: [])
        inlineCodeRegex.enumerateMatches(in: textStorage.string as String, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            // Skip if inside code block
            for codeRange in codeBlockRanges {
                if NSIntersectionRange(matchRange, codeRange).length > 0 {
                    return
                }
            }
            inlineCodeRanges.append(matchRange)
        }

        // Step 5: Apply inline styles (bold, italic, inline code, links)
        // These should respect already-applied line styles and skip inline code interiors
        let inlinePatterns = buildInlinePatterns()
        for (regex, attrBuilder) in inlinePatterns {
            let attrs = attrBuilder(theme)
            regex.enumerateMatches(in: textStorage.string as String, options: [], range: range) { match, _, _ in
                guard let matchRange = match?.range else { return }

                // Skip if this range overlaps with any code block
                for codeRange in codeBlockRanges {
                    if NSIntersectionRange(matchRange, codeRange).length > 0 {
                        return
                    }
                }

                // Skip if this is an inline code pattern - apply directly
                let pattern = regex.pattern
                if pattern == "`([^`]+)`" {
                    textStorage.addAttributes(attrs, range: matchRange)
                    return
                }

                // For other patterns, skip if inside inline code
                for codeRange in inlineCodeRanges {
                    if NSIntersectionRange(matchRange, codeRange).length > 0 {
                        return
                    }
                }

                textStorage.addAttributes(attrs, range: matchRange)
            }
        }
    }

    /// Find all code block ranges (including the fence lines)
    private func findCodeBlockRanges(in string: NSString, range: NSRange) -> [NSRange] {
        var ranges: [NSRange] = []
        var inCodeBlock = false
        var codeBlockStart: Int = 0

        let text = string as String
        let lines = text.components(separatedBy: "\n")
        var charIndex = 0

        for (lineNumber, line) in lines.enumerated() {
            let lineLength = line.count
            let _ = NSRange(location: charIndex, length: lineNumber < lines.count - 1 ? lineLength + 1 : lineLength)

            // Check for code fence
            if line.hasPrefix("```") {
                if !inCodeBlock {
                    // Start of code block
                    inCodeBlock = true
                    codeBlockStart = charIndex
                } else {
                    // End of code block
                    inCodeBlock = false
                    let codeBlockEnd = charIndex + lineLength + 1 // +1 for newline
                    let nsRange = NSRange(location: codeBlockStart, length: min(codeBlockEnd - codeBlockStart, string.length - codeBlockStart))
                    if NSIntersectionRange(nsRange, range).length > 0 {
                        ranges.append(nsRange)
                    }
                }
            }

            charIndex += lineLength + 1 // +1 for newline
        }

        // Handle unclosed code block
        if inCodeBlock {
            let nsRange = NSRange(location: codeBlockStart, length: string.length - codeBlockStart)
            if NSIntersectionRange(nsRange, range).length > 0 {
                ranges.append(nsRange)
            }
        }

        return ranges
    }

    /// Line-level patterns (headings, blockquotes, lists, tables, hr)
    /// These are applied first and affect whole lines
    private func buildLinePatterns() -> [(NSRegularExpression, (EditorTheme) -> [NSAttributedString.Key: Any])] {
        var result: [(NSRegularExpression, (EditorTheme) -> [NSAttributedString.Key: Any])] = []

        func add(_ pattern: String, _ attrs: @escaping (EditorTheme) -> [NSAttributedString.Key: Any]) {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                result.append((regex, attrs))
            }
        }

        // Headings: # ... (whole line)
        add(#"^#{1,6}\s+.*$"#) { theme in
            [.foregroundColor: theme.heading, .font: NSFont.boldSystemFont(ofSize: theme.font.pointSize)]
        }

        // List markers: - or * or + or 1.
        add(#"^(\s*)([-*+]|\d+\.)\s"#) { theme in
            [.foregroundColor: theme.listMarker]
        }

        // Task list: - [ ] or - [x]
        add(#"^(\s*)[-*+]\s\[([ xX])\]\s"#) { theme in
            [.foregroundColor: theme.listMarker]
        }

        // Blockquote: > text
        add(#"^>\s.*$"#) { theme in
            [.foregroundColor: theme.blockquoteMarker]
        }

        // Horizontal rule: --- or *** or ___
        add(#"^([-*_]){3,}\s*$"#) { theme in
            [.foregroundColor: theme.horizontalRule]
        }

        // Table pipes: | (match individual pipe characters)
        add(#"\|"#) { theme in
            [.foregroundColor: theme.tablePipe]
        }

        // HTML comments: <!-- -->
        add(#"<!--.*?-->"#) { theme in
            [.foregroundColor: theme.comment]
        }

        return result
    }

    /// Inline patterns (bold, italic, inline code, links)
    /// These are applied after line-level patterns
    private func buildInlinePatterns() -> [(NSRegularExpression, (EditorTheme) -> [NSAttributedString.Key: Any])] {
        var result: [(NSRegularExpression, (EditorTheme) -> [NSAttributedString.Key: Any])] = []

        func add(_ pattern: String, _ attrs: @escaping (EditorTheme) -> [NSAttributedString.Key: Any]) {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                result.append((regex, attrs))
            }
        }

        // Bold: **text** or __text__
        add(#"(\*\*|__)(.*?)\1"#) { theme in
            [.foregroundColor: theme.bold, .font: NSFont.boldSystemFont(ofSize: theme.font.pointSize)]
        }

        // Italic: *text* or _text_
        add(#"(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)"#) { theme in
            [.foregroundColor: theme.italic,
             .font: NSFontManager.shared.convert(theme.font, toHaveTrait: .italicFontMask)]
        }

        // Strikethrough: ~~text~~
        add(#"~~(.+?)~~"#) { theme in
            [.foregroundColor: NSColor(hex: "#808080")!,
             .strikethroughStyle: NSUnderlineStyle.single.rawValue]
        }

        // Inline code: `code` (only if not inside code blocks - checked at runtime)
        add(#"`([^`]+)`"#) { theme in
            [.foregroundColor: theme.code, .backgroundColor: theme.codeBackground, .font: theme.codeFont]
        }

        // Links: [text](url)
        add(#"\[([^\]]+)\]\(([^)]+)\)"#) { theme in
            [.foregroundColor: theme.link]
        }

        // URL part in links: (url)
        add(#"\]\(([^)]+)\)"#) { theme in
            [.foregroundColor: theme.linkUrl]
        }

        // Images: ![alt](url)
        add(#"!\[([^\]]*)\]\([^\)]+\)"#) { theme in
            [.foregroundColor: theme.link]
        }

        return result
    }
}
