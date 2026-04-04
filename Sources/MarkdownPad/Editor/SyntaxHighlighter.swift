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

    // MARK: - Main Highlighting Pipeline

    private func applyHighlighting(in textStorage: NSTextStorage, range: NSRange) {
        let string = textStorage.string as NSString

        guard range.location + range.length <= string.length else { return }

        // Step 1: Reset to default style
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.text,
            .font: theme.font,
        ]
        textStorage.setAttributes(defaultAttrs, range: range)

        // Step 2: Find code block ranges (fenced ``` blocks with nesting support)
        // These are "protected zones" — no other highlighting enters them
        let codeBlockRanges = findCodeBlockRanges(in: string, range: range)
        for codeRange in codeBlockRanges {
            textStorage.addAttributes([
                .foregroundColor: theme.code,
                .font: theme.codeFont,
                .backgroundColor: theme.codeBackground
            ], range: codeRange)
        }

        // Step 3: Find heading line ranges
        // Headings are also "protected zones" — inline rules won't recolor inside them
        let headingRanges = findHeadingRanges(in: string, range: range, excluding: codeBlockRanges)
        for headingRange in headingRanges {
            textStorage.addAttributes([
                .foregroundColor: theme.heading,
                .font: NSFont.boldSystemFont(ofSize: theme.font.pointSize)
            ], range: headingRange)
        }

        // Build the combined protected zones (code blocks + heading lines)
        let protectedRanges = codeBlockRanges + headingRanges

        // Step 4: Find inline code ranges FIRST (they need protection from all other patterns)
        // Inline code is also a protected zone
        let inlineCodeRanges = findInlineCodeRanges(in: string, range: range, excluding: protectedRanges)

        // Step 5: Apply line-level styles (blockquotes, lists, tables, hr)
        // Skip code blocks, headings, AND inline code
        applyLinePatterns(in: textStorage, range: range, excluding: protectedRanges + inlineCodeRanges)

        // Step 6: Apply inline styles (bold, italic, inline code, links)
        // Skip code blocks AND headings
        applyInlinePatterns(in: textStorage, range: range, excluding: protectedRanges, inlineCodeRanges: inlineCodeRanges)
    }

    // MARK: - Code Block Detection (with nesting support)

    private func findCodeBlockRanges(in string: NSString, range: NSRange) -> [NSRange] {
        var ranges: [NSRange] = []
        var fenceStack: [(count: Int, start: Int)] = []

        string.enumerateSubstrings(
            in: range,
            options: [.byLines, .substringNotRequired]
        ) { _, substringRange, _, _ in
            let lineStr = string.substring(with: substringRange)
            let trimmed = lineStr.trimmingCharacters(in: .whitespaces)

            // Count leading backticks
            var backtickCount = 0
            for char in trimmed {
                if char == "`" {
                    backtickCount += 1
                } else {
                    break
                }
            }

            // Only consider fence if 3+ backticks
            if backtickCount >= 3 {
                if fenceStack.isEmpty {
                    // Start new code block
                    fenceStack.append((count: backtickCount, start: substringRange.location))
                } else if backtickCount >= fenceStack.last!.count {
                    // Close the code block (same or more backticks)
                    let start = fenceStack.removeLast().start
                    let end = substringRange.location + substringRange.length
                    let nsRange = NSRange(
                        location: start,
                        length: min(end - start, string.length - start)
                    )
                    ranges.append(nsRange)
                }
                // If fewer backticks, it's content inside code block, ignore
            }
        }

        // Handle unclosed code blocks
        for fence in fenceStack {
            let nsRange = NSRange(location: fence.start, length: string.length - fence.start)
            ranges.append(nsRange)
        }

        return ranges
    }

    // MARK: - Inline Code Detection

    private func findInlineCodeRanges(in string: NSString, range: NSRange, excluding: [NSRange]) -> [NSRange] {
        var ranges: [NSRange] = []

        // Match inline code that doesn't span multiple lines
        // [^`\n]+ ensures we don't match across line boundaries
        guard let regex = try? NSRegularExpression(pattern: "`[^`\n]+`", options: []) else {
            return ranges
        }

        regex.enumerateMatches(in: string as String, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            if !self.isInsideAny(range: matchRange, of: excluding) {
                ranges.append(matchRange)
            }
        }

        return ranges
    }

    // MARK: - Heading Detection

    private func findHeadingRanges(in string: NSString, range: NSRange, excluding: [NSRange]) -> [NSRange] {
        var ranges: [NSRange] = []

        guard let regex = try? NSRegularExpression(pattern: #"^#{1,6}\s+.*$"#, options: [.anchorsMatchLines]) else {
            return ranges
        }

        regex.enumerateMatches(in: string as String, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            if !self.isInsideAny(range: matchRange, of: excluding) {
                ranges.append(matchRange)
            }
        }

        return ranges
    }

    // MARK: - Line-Level Patterns

    private func applyLinePatterns(in textStorage: NSTextStorage, range: NSRange, excluding protectedRanges: [NSRange]) {

        let linePatterns = buildLinePatterns()
        for (regex, attrBuilder) in linePatterns {
            let attrs = attrBuilder(theme)
            regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
                guard let matchRange = match?.range else { return }
                // Check if ANY part of the match touches a protected range
                // We need to be more careful here - skip if there's ANY overlap
                var isProtected = false
                for protectedRange in protectedRanges {
                    let intersection = NSIntersectionRange(matchRange, protectedRange)
                    if intersection.length > 0 {
                        isProtected = true
                        break
                    }
                }
                if !isProtected {
                    textStorage.addAttributes(attrs, range: matchRange)
                }
            }
        }
    }

    private func buildLinePatterns() -> [(NSRegularExpression, (EditorTheme) -> [NSAttributedString.Key: Any])] {
        var result: [(NSRegularExpression, (EditorTheme) -> [NSAttributedString.Key: Any])] = []

        func add(_ pattern: String, _ options: NSRegularExpression.Options = [.anchorsMatchLines],
                 _ attrs: @escaping (EditorTheme) -> [NSAttributedString.Key: Any]) {
            if let regex = try? NSRegularExpression(pattern: pattern, options: options) {
                result.append((regex, attrs))
            }
        }

        // NOTE: Headings are handled separately in Step 3, not here

        // List markers: - or * or + or 1.
        add(#"^(\s*)([-*+]|\d+\.)\s"#) { theme in
            [.foregroundColor: theme.listMarker]
        }

        // Task list: - [ ] or - [x]
        add(#"^(\s*)[-*+]\s\[([ xX])\]\s"#) { theme in
            [.foregroundColor: theme.listMarker]
        }

        // Blockquote: > text (whole line)
        add(#"^>\s.*$"#) { theme in
            [.foregroundColor: theme.blockquoteMarker]
        }

        // Horizontal rule: --- or *** or ___
        add(#"^([-*_]){3,}\s*$"#) { theme in
            [.foregroundColor: theme.horizontalRule]
        }

        // Table pipes: match only the | character, not the whole line
        add(#"\|"#, []) { theme in
            [.foregroundColor: theme.tablePipe]
        }

        // HTML comments: <!-- -->
        add(#"<!--.*?-->"#, []) { theme in
            [.foregroundColor: theme.comment]
        }

        return result
    }

    // MARK: - Inline Patterns

    private func applyInlinePatterns(in textStorage: NSTextStorage, range: NSRange, excluding protectedRanges: [NSRange], inlineCodeRanges: [NSRange]) {

        // Combine all ranges that inline patterns should skip
        let allExcludedRanges = protectedRanges + inlineCodeRanges

        let inlinePatterns = buildInlinePatterns()
        for (regex, attrBuilder, captureGroup) in inlinePatterns {
            let attrs = attrBuilder(theme)
            regex.enumerateMatches(in: textStorage.string, options: [], range: range) { match, _, _ in
                guard let match = match else { return }

                let targetRange: NSRange
                if captureGroup > 0, match.numberOfRanges > captureGroup {
                    targetRange = match.range(at: captureGroup)
                } else {
                    targetRange = match.range
                }

                guard targetRange.location != NSNotFound else { return }

                // Skip if overlapping with any protected range or inline code
                if self.isInsideAny(range: targetRange, of: allExcludedRanges) {
                    return
                }

                textStorage.addAttributes(attrs, range: targetRange)
            }
        }

        // Apply inline code highlighting separately (it was pre-detected)
        for codeRange in inlineCodeRanges {
            textStorage.addAttributes([
                .foregroundColor: theme.code,
                .backgroundColor: theme.codeBackground,
                .font: theme.codeFont
            ], range: codeRange)
        }
    }

    private func buildInlinePatterns() -> [(NSRegularExpression, (EditorTheme) -> [NSAttributedString.Key: Any], Int)] {
        var result: [(NSRegularExpression, (EditorTheme) -> [NSAttributedString.Key: Any], Int)] = []

        func add(_ pattern: String, captureGroup: Int = 0,
                 _ attrs: @escaping (EditorTheme) -> [NSAttributedString.Key: Any]) {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                result.append((regex, attrs, captureGroup))
            }
        }

        // NOTE: Inline code is handled separately via pre-detected ranges

        // Bold: **text** or __text__
        add(#"(\*\*|__)(.*?)\1"#) { theme in
            [.foregroundColor: theme.bold, .font: NSFont.boldSystemFont(ofSize: theme.font.pointSize)]
        }

        // Bold+Italic: ***text***
        add(#"\*\*\*(.*?)\*\*\*"#) { theme in
            let boldItalic = NSFontManager.shared.convert(
                NSFont.boldSystemFont(ofSize: theme.font.pointSize),
                toHaveTrait: .italicFontMask
            )
            return [.foregroundColor: theme.bold, .font: boldItalic]
        }

        // Italic: *text* or _text_ (negative lookbehind/ahead to avoid matching **)
        add(#"(?<!\*)\*(?!\*)(.*?)(?<!\*)\*(?!\*)"#) { theme in
            [.foregroundColor: theme.italic,
             .font: NSFontManager.shared.convert(theme.font, toHaveTrait: .italicFontMask)]
        }

        // Strikethrough: ~~text~~
        add(#"~~(.+?)~~"#) { theme in
            [.foregroundColor: NSColor(hex: "#808080") ?? theme.text,
             .strikethroughStyle: NSUnderlineStyle.single.rawValue]
        }

        // Links: [text](url) — style the whole match as link color
        add(#"\[([^\]]+)\]\(([^)]+)\)"#) { theme in
            [.foregroundColor: theme.link]
        }

        // Link URL portion: ](url)
        add(#"\]\(([^)]+)\)"#) { theme in
            [.foregroundColor: theme.linkUrl]
        }

        // Images: ![alt](url)
        add(#"!\[([^\]]*)\]\([^\)]+\)"#) { theme in
            [.foregroundColor: theme.link]
        }

        return result
    }

    // MARK: - Helpers

    private func isInsideAny(range: NSRange, of zones: [NSRange]) -> Bool {
        for zone in zones {
            if NSIntersectionRange(range, zone).length > 0 {
                return true
            }
        }
        return false
    }
}
