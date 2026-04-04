import AppKit

final class SyntaxHighlighter {
    private let theme: EditorTheme

    // Regex patterns for markdown syntax
    private let patterns: [(NSRegularExpression, (EditorTheme) -> [NSAttributedString.Key: Any])]

    init(theme: EditorTheme) {
        self.theme = theme
        patterns = Self.buildPatterns()
    }

    private static func buildPatterns() -> [(NSRegularExpression, (EditorTheme) -> [NSAttributedString.Key: Any])] {
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

        // Bold: **text** or __text__
        add(#"(\*\*|__)(.*?)\1"#) { theme in
            [.foregroundColor: theme.bold, .font: NSFont.boldSystemFont(ofSize: theme.font.pointSize)]
        }

        // Italic: *text* or _text_ (not preceded by * or followed by *)
        add(#"(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)"#) { theme in
            [.foregroundColor: theme.italic,
             .font: NSFontManager.shared.convert(theme.font, toHaveTrait: .italicFontMask)]
        }

        // Inline code: `code`
        add(#"`([^`]+)`"#) { theme in
            [.foregroundColor: theme.code, .backgroundColor: theme.codeBackground, .font: theme.codeFont]
        }

        // Code block fences: ``` (the fence lines themselves)
        add(#"^```.*$"#) { theme in
            [.foregroundColor: theme.code, .font: theme.codeFont]
        }

        // Links: [text](url)
        add(#"\[([^\]]+)\]\([^\)]+\)"#) { theme in
            [.foregroundColor: theme.link]
        }

        // Images: ![alt](url)
        add(#"!\[([^\]]*)\]\([^\)]+\)"#) { theme in
            [.foregroundColor: theme.link]
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

        return result
    }

    /// Highlight the paragraph(s) around the edited range.
    func highlightParagraph(in textStorage: NSTextStorage, editedRange: NSRange) {
        let string = textStorage.string as NSString
        let length = string.length

        guard length > 0 else { return }

        // Simply highlight the entire document - safer and simpler
        applyHighlighting(in: textStorage, range: NSRange(location: 0, length: length))
    }

    private func applyHighlighting(in textStorage: NSTextStorage, range: NSRange) {
        let string = textStorage.string as NSString

        guard range.location + range.length <= string.length else { return }

        // Reset to default style
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.text,
            .font: theme.font,
        ]
        textStorage.setAttributes(defaultAttrs, range: range)

        // Apply each pattern
        for (regex, attrBuilder) in patterns {
            let attrs = attrBuilder(theme)
            regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range {
                    textStorage.addAttributes(attrs, range: matchRange)
                }
            }
        }
    }
}
