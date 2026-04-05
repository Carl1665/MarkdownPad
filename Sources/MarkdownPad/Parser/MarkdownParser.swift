import Foundation
import Markdown

struct MarkdownParser {
    func parse(_ markdown: String) -> String {
        // Convert tabs to 4 spaces for consistent indentation parsing
        let normalized = markdown.replacingOccurrences(of: "\t", with: "    ")
        let preprocessed = normalizeListIndentation(normalized)
        let document = Document(parsing: preprocessed)
        var visitor = HTMLVisitor()
        return visitor.visit(document)
    }

    /// Exposed for testing the normalization step independently
    func normalizeListIndentationForTest(_ markdown: String) -> String {
        normalizeListIndentation(markdown)
    }

    /// Normalize indentation of list items so swift-markdown recognizes nested lists.
    ///
    /// CommonMark requires sub-list markers to start at exactly the parent's content column.
    /// For "1. item" (marker width 3), sub-items need 3 spaces of indentation.
    /// For "- item" (marker width 2), sub-items need 2 spaces.
    ///
    /// Users often indent with 4 spaces (Tab key), which swift-markdown treats as
    /// continuation text rather than a nested list. This function adjusts indentation
    /// so list items at any nesting level are recognized correctly.
    private func normalizeListIndentation(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        // Match any line starting with optional spaces + list marker + space
        // Group 1: leading spaces, Group 2: marker (-, *, +, or digits + . or ))
        let listMarkerRegex = try! NSRegularExpression(
            pattern: "^(\\s*)([-*+]|\\d+[.)])\\s",
            options: []
        )
        // Match an ordered list marker (digits + . or ))
        let orderedMarkerRegex = try! NSRegularExpression(
            pattern: "^\\d+[.)]$",
            options: []
        )

        // Marker widths at each nesting level (e.g., "- " → 2, "1. " → 3)
        var levelMarkerWidths: [Int] = []
        var result: [String] = []

        for line in lines {
            let nsLine = line as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)

            if let match = listMarkerRegex.firstMatch(in: line, options: [], range: fullRange) {
                let leadingSpaces = nsLine.substring(with: match.range(at: 1))
                let indent = leadingSpaces.count
                let markerRange = match.range(at: 2)
                let matchEnd = match.range.location + match.range.length
                let markerWidth = matchEnd - markerRange.location  // marker + trailing space

                if indent == 0 {
                    // Top-level list item: reset stack
                    levelMarkerWidths = [markerWidth]
                    result.append(line)
                } else {
                    let marker = nsLine.substring(with: markerRange)
                    let restAfterMarker = nsLine.substring(from: matchEnd)

                    // swift-markdown requires ordered sub-lists to start with "1"
                    let normalizedMarker: String
                    if orderedMarkerRegex.firstMatch(in: marker, options: [], range: NSRange(location: 0, length: marker.count)) != nil {
                        let delimiter = marker.last!  // "." or ")"
                        normalizedMarker = "1\(delimiter)"
                    } else {
                        normalizedMarker = marker
                    }

                    // Determine nesting level from original indent.
                    // Walk through accumulated marker widths to find which level this item belongs to.
                    var cumIndent = 0
                    var targetLevel = 0
                    for (level, width) in levelMarkerWidths.enumerated() {
                        let nextCum = cumIndent + width
                        if indent >= nextCum {
                            targetLevel = level + 1
                            cumIndent = nextCum
                        } else {
                            break
                        }
                    }

                    // Truncate stack to target level (pop back for sibling items)
                    levelMarkerWidths = Array(levelMarkerWidths.prefix(targetLevel))

                    let newLine = String(repeating: " ", count: cumIndent)
                        + normalizedMarker + " "
                        + restAfterMarker

                    // Push this level's marker width
                    levelMarkerWidths.append(normalizedMarker.count + 1)

                    result.append(newLine)
                }
            } else {
                // Non-list line: blank lines reset the indent context
                if line.trimmingCharacters(in: .whitespaces).isEmpty {
                    levelMarkerWidths = []
                }
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }
}

private struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    // MARK: - Block Elements

    mutating func defaultVisit(_ markup: any Markup) -> String {
        markup.children.map { visit($0) }.joined()
    }

    mutating func visitDocument(_ document: Document) -> String {
        document.children.map { visit($0) }.joined(separator: "\n")
    }

    mutating func visitHeading(_ heading: Heading) -> String {
        let tag = "h\(heading.level)"
        let line = sourceLine(heading)
        let content = heading.children.map { visit($0) }.joined()
        return "<\(tag) data-source-line=\"\(line)\">\(content)</\(tag)>"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        let line = sourceLine(paragraph)
        let content = paragraph.children.map { visit($0) }.joined()
        // Check if this paragraph is inside a list item — if so, don't wrap in <p>
        if paragraph.parent is ListItem {
            return content
        }
        return "<p data-source-line=\"\(line)\">\(content)</p>"
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> String {
        let line = sourceLine(list)
        let items = list.children.map { visit($0) }.joined(separator: "\n")
        return "<ul data-source-line=\"\(line)\">\n\(items)\n</ul>"
    }

    mutating func visitOrderedList(_ list: OrderedList) -> String {
        let line = sourceLine(list)
        let items = list.children.map { visit($0) }.joined(separator: "\n")
        return "<ol data-source-line=\"\(line)\">\n\(items)\n</ol>"
    }

    mutating func visitListItem(_ item: ListItem) -> String {
        let line = sourceLine(item)
        let checkbox: String
        if let cb = item.checkbox {
            let checked = cb == .checked ? " checked disabled" : " disabled"
            checkbox = "<input type=\"checkbox\"\(checked)> "
        } else {
            checkbox = ""
        }
        let content = item.children.map { visit($0) }.joined()
        return "<li data-source-line=\"\(line)\">\(checkbox)\(content)</li>"
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> String {
        let startLine = sourceLine(codeBlock)
        let lang = codeBlock.language ?? ""
        let langAttr = lang.isEmpty ? "" : " class=\"language-\(lang)\""
        let code = escapeHTML(codeBlock.code)

        // 为每行生成带行号的 span，实现行级滚动同步
        let lines = code.components(separatedBy: "\n")
        var lineSpans: [String] = []

        for (index, lineContent) in lines.enumerated() {
            // 跳过最后一个空行（代码块末尾换行产生的空元素）
            if index == lines.count - 1 && lineContent.isEmpty { break }
            let lineNumber = startLine + index
            lineSpans.append("<span data-source-line=\"\(lineNumber)\">\(lineContent)</span>")
        }

        let wrappedCode = lineSpans.joined(separator: "\n")
        return "<pre data-source-line=\"\(startLine)\"><code\(langAttr)>\(wrappedCode)</code></pre>"
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> String {
        let line = sourceLine(blockQuote)
        let content = blockQuote.children.map { visit($0) }.joined(separator: "\n")
        return "<blockquote data-source-line=\"\(line)\">\n\(content)\n</blockquote>"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        let line = sourceLine(thematicBreak)
        return "<hr data-source-line=\"\(line)\">"
    }

    mutating func visitTable(_ table: Table) -> String {
        let line = sourceLine(table)
        var html = "<table data-source-line=\"\(line)\">\n<thead>\n<tr>\n"
        // Header row
        for cell in table.head.cells {
            let content = cell.children.map { visit($0) }.joined()
            html += "<th>\(content)</th>\n"
        }
        html += "</tr>\n</thead>\n<tbody>\n"
        // Body rows
        for row in table.body.rows {
            html += "<tr>\n"
            for cell in row.cells {
                let content = cell.children.map { visit($0) }.joined()
                html += "<td>\(content)</td>\n"
            }
            html += "</tr>\n"
        }
        html += "</tbody>\n</table>"
        return html
    }

    // MARK: - Inline Elements

    mutating func visitText(_ text: Markdown.Text) -> String {
        escapeHTML(text.string)
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        let content = strong.children.map { visit($0) }.joined()
        return "<strong>\(content)</strong>"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        let content = emphasis.children.map { visit($0) }.joined()
        return "<em>\(content)</em>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escapeHTML(inlineCode.code))</code>"
    }

    mutating func visitLink(_ link: Markdown.Link) -> String {
        let content = link.children.map { visit($0) }.joined()
        let href = link.destination ?? ""
        return "<a href=\"\(href)\">\(content)</a>"
    }

    mutating func visitImage(_ image: Markdown.Image) -> String {
        let src = image.source ?? ""
        let alt = image.children.map { visit($0) }.joined()
        return "<img src=\"\(src)\" alt=\"\(alt)\">"
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>"
    }

    // MARK: - Helpers

    private func sourceLine(_ markup: any Markup) -> Int {
        markup.range?.lowerBound.line ?? 0
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
